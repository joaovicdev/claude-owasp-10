# A08:2025 — Software or Data Integrity Failures

**ID:** `A08:2025` · **2021:** A08:2021, renamed ("or" replaces "and") · **Applies to:** any

## Rule

1. Never deserialize a caller-controlled payload into arbitrary types. Parse into
   a declared shape; type information must come from your code, not the data.
2. Anything arriving from outside that drives a decision is verified before use:
   signature checked against the **raw** bytes, in constant time, with the
   timestamp bounded and the id replayed only once.
3. Code that the application loads at runtime — plugins, templates, migrations,
   updates — is fixed by the deployment, never selected by request data.
4. A cache key includes every input that changes the response, and nothing the
   caller can set arbitrarily. Anything else is a poisoning primitive.

## How it shows up in a backend API

- A deserializer configured with polymorphic or default typing lets the payload
  name the class to instantiate. Construction alone is enough — a gadget in any
  dependency turns that into execution. This is the shape behind a long line of
  real chains, and it is a configuration flag, not a code path someone wrote.
- A webhook receiver that parses the body first and verifies the signature
  against the re-serialized result. The bytes that were signed are gone by then,
  and the check silently passes on payloads it should reject.
- Signature comparison with a plain equality operator, leaking the correct value
  a byte at a time; or a missing timestamp check, so any captured request is
  replayable forever.
- Object or query state accepted from a hidden field, a cookie, or a signed blob
  the client can edit — prices, quantities, roles, and totals recomputed from
  data the client controls.
- Import/export, template, and "run this migration" features that take a path or
  a name from a request, letting a caller pick which code executes.
- CDN or application cache keyed on the path but not on the tenant, the
  authorization context, or a `Vary` header — so one caller's response is served
  to another.

## Anti-pattern

```
obj = deserialize(request.body, allow_polymorphic: true)   # payload names the class

handler POST /webhooks/provider:
    event = parse_json(request.body)                       # parsed before verifying
    if hmac(secret, serialize(event)) == request.header("X-Signature"):
        apply(event)                                       # non-constant-time, re-serialized

price = request.body.unit_price * request.body.qty         # client-supplied price
```

## Correct

```
event = WebhookEvent.parse(request.raw_body)               # declared shape only

handler POST /webhooks/provider:
    raw = request.raw_body                                 # exact bytes as received
    require constant_time_equals(hmac(secret, raw), request.header("X-Signature"))
    require abs(now - event.timestamp) < 5 minutes         # replay window
    require seen.add_if_absent(event.id)                   # replay id, once
    apply(WebhookEvent.parse(raw))

price = db.price_of(product_id) * validated.qty            # server is the authority
cache_key = [route, tenant_id, auth_context, normalized_params]
```

Capturing the raw body usually needs a framework opt-in, and body-parsing
middleware will consume it first — wire that before writing the check.

## Idiom by stack

| Stack | Notes |
|---|---|
| NestJS | `rawBody: true` for webhook routes; avoid reviving arbitrary classes; `timingSafeEqual` |
| Laravel | signed URLs with expiry; `hash_equals`; never `unserialize()` on input |
| Spring Boot | never enable Jackson default typing / `enableDefaultTyping`; avoid Java native deserialization of input entirely |
| Any | verify before parse; bound the timestamp; store the event id |

→ `stacks/nestjs.md (NEST.16)` · `stacks/laravel.md (LAR.6)` · `stacks/spring-boot.md (SPR.7)`

## Review questions

- **A08.Q1** — Does any deserializer allow the payload to determine the type
  instantiated (polymorphic/default typing, native deserialization)?
- **A08.Q2** — Is every inbound webhook signature verified against the raw bytes,
  before parsing, using a constant-time comparison?
- **A08.Q3** — Is the signed payload's timestamp bounded and its id recorded to
  prevent replay?
- **A08.Q4** — Does any value that determines an outcome (price, quantity, role,
  totals, state) come from the request rather than from the server?
- **A08.Q5** — Can request data select which code, template, migration, or plugin
  is loaded?
- **A08.Q6** — Does the cache key include tenant and authorization context, and
  exclude anything the caller can set freely?
- **A08.Q7** — Are artifacts consumed by the build or runtime verified
  (checksum, signature, digest pin)? (see A03)

## Grep signals

```bash
rg -ni 'unserialize|pickle\.loads|readObject|enableDefaultTyping|activateDefaultTyping|yaml\.load\('
rg -ni 'webhook|signature|x-hub|x-signature|hmac'
rg -n '\bhmac\b.*==|==.*\bhmac\b|signature\s*==' 
rg -ni 'timingSafeEqual|hash_equals|MessageDigest\.isEqual|compare_digest'
rg -ni 'rawBody|raw_body|bodyParser|getReader|request\.body\b'
rg -ni 'cacheKey|cache_key|revalidate|Vary|s-maxage'
```
