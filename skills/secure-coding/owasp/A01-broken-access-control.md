# A01:2025 — Broken Access Control

**ID:** `A01:2025` · **2021:** A01:2021 (held #1) · **Applies to:** any

OWASP names `CWE-918` (SSRF), `CWE-352` (CSRF), `CWE-200` and `CWE-201` among the
notable CWEs in this category. SSRF is therefore covered here rather than in an
entry of its own — A10:2021 no longer exists — and so is CSRF.

## Rule

1. Every handler that accepts a caller-supplied identifier resolves the object
   **scoped by the caller**, in the query predicate. Never fetch by id and check
   ownership afterwards, and never check it in the caller of the service.
2. Authorization is deny-by-default: the guard is global, and each exemption is
   explicit, individually justified, and enumerable by a test.
3. Being authenticated is not being authorized. "Any logged-in user can reach it"
   is a finding unless the resource is genuinely public.
4. When a request can act on behalf of another identity (impersonation, service
   account, admin proxy), every check states **which** identity it evaluates.
5. A request the **server** makes on the caller's behalf is access control too.
   The destination goes through an allowlist at the call site, and the client does
   not follow redirects out of it.
6. If the session travels in a cookie, every state-changing route carries a CSRF
   defense. A credential the browser attaches by itself is a credential the
   attacker's page can spend.

## How it shows up in a backend API

- The classic shape is a read handler on `/<resource>/{id}` that passes the id
  straight to the data layer. It looks harmless because a guard already runs —
  but that guard proved *who* the caller is, not *what* they may reach.
- The tell is inconsistency between sibling routes: `/{id}/answers` takes the
  caller, `/{id}/timeline` does not. One of them is wrong, and it is rarely the
  stricter one.
- Scoping done manually inside handlers rots. Whoever adds route #12 will forget.
  Push it into a repository/scope/specification that cannot be bypassed.
- Multi-tenant systems fail the same way one level up: the row is scoped to the
  user but not to the tenant, so a valid id from another tenant resolves.
- Sort/filter/`include` parameters are access control too — they can pull related
  rows the caller may not read, or order by a column that leaks ordering.
- Mass assignment is access control: a request that sets `role`, `tenantId`, or
  `isAdmin` escalates privilege through a write path, not a read path.
- SSRF is the same defect aimed outward: a handler takes a URL — an avatar to
  import, a webhook to register, a callback to verify — and fetches it. The
  request now originates *inside* the perimeter, so it reaches the cloud metadata
  endpoint (`169.254.169.254`), an internal admin port, or `localhost`.
- Validating that URL once and fetching it later does not hold. The name can
  resolve to a different address the second time (DNS rebinding), and a `302` can
  walk the client out of the allowlist after the check passed. Pin the resolved
  address the connection actually uses, and re-check on every hop.
- CSRF matters only where the browser attaches the credential unprompted — cookie
  sessions. There, a state-changing route reachable by a plain form post, or one
  that answers to `GET`, is exploitable from any page the victim visits. An API
  authenticated purely by an `Authorization` header is not exposed this way.

## Anti-pattern

```
handler GET /orders/{id}:
    order = db.findById(id)                   # authenticated, but unscoped
    return order                              # and it is the entity, see A02/A04

handler PATCH /users/{id}:
    user = db.findById(id)
    user.assign(request.body)                 # body may carry role / tenantId
    return db.save(user)

handler POST /import:
    return http.get(request.body.url)         # any host; redirects followed
```

## Correct

```
handler GET /orders/{id}:
    order = db.findOne(id: id, tenantId: caller.tenantId)
    if not order: return 404                  # 404, not 403 — do not confirm existence
    return OrderResponse(order)

handler PATCH /users/{id}:
    require caller.may(UPDATE, user_id: id)   # explicit, before any write
    fields = UpdateUserInput.parse(request.body)   # allowlist; unknown fields rejected
    return UserResponse(db.update(id: id, tenantId: caller.tenantId, set: fields))

handler POST /import:
    addr = resolve(request.body.url)          # resolve first, decide on the address
    require addr is public and allowed_host(addr)   # allowlist, at the call site
    return http.get(request.body.url, connect_to: addr,
                    follow_redirects: false, timeout: 5s)
```

Return `404` rather than `403` for objects the caller may not see — a `403`
confirms the id exists and turns the endpoint into an enumeration oracle. Use
`403` only when the caller is allowed to know the resource exists.

## Idiom by stack

| Stack | Where the scope belongs |
|---|---|
| NestJS | `where: { id, tenantId }` in the repository; caller injected via a param decorator |
| Laravel | Policy + a global tenant scope on the model; `authorize()` in the handler |
| Spring Boot | `@PreAuthorize` + a Specification carrying the tenant predicate |
| Django | a filtered `get_queryset()`, never `Model.objects.get(pk=...)` |
| Rails | association-scoped lookup (`current_user.orders.find(id)`), never `Order.find(id)` |

For the outward-facing half: every HTTP client has its own way of disabling
redirect-following and of pinning the address it connects to, and most follow
redirects by default. CSRF protection ships with the session middleware in every
server framework — the finding is almost always an exemption list that grew.

→ `stacks/nestjs.md (NEST.3, NEST.17)` · `stacks/laravel.md (LAR.3, LAR.11, LAR.12)` ·
`stacks/spring-boot.md (SPR.3, SPR.11, SPR.12)`

## Review questions

- **A01.Q1** — Does every new handler taking a caller-supplied id pass the caller
  identity into the data layer, with the scope in the query predicate?
- **A01.Q2** — Is ownership/tenant enforced in the query rather than by an `if`
  after the fetch?
- **A01.Q3** — If this route is exempt from the global guard, what compensating
  control replaces it, and is the exemption listed in a test that enumerates all
  public routes?
- **A01.Q4** — Do sibling routes on the same resource disagree about taking the
  caller? If so, which one is wrong?
- **A01.Q5** — Can the request body set a field that grants privilege (`role`,
  `tenantId`, `isAdmin`, `ownerId`)? Is the write path an allowlist?
- **A01.Q6** — Are sort/filter/include/expand parameters restricted to an
  allowlist, and do they respect the same scope as the base query?
- **A01.Q7** — For a not-permitted object, does the response distinguish
  "missing" from "forbidden" in a way that enables enumeration?
- **A01.Q8** — Under impersonation, does the check evaluate the acting identity
  or the effective one, and is that the intended choice?
- **A01.Q9** — Does any caller-supplied URL, host, or port reach an outbound
  request, and is the destination allowlisted at the call site?
- **A01.Q10** — For that request: are redirects refused or re-validated, is the
  resolved address checked rather than the hostname, and is there a timeout?
- **A01.Q11** — If sessions are cookie-based, is every state-changing route CSRF
  protected, and is each entry in the exemption list justified?

## Grep signals

```bash
# handlers taking an id — then read each for a caller-scoped lookup
rg -n '[:{<]id[}>]?["'"'"']?\s*[,)]|@PathVariable|PathParam|params\[.id.\]'
# unscoped single-object lookups
rg -n '\b(findById|findOne|getById|find_by_id|findOrFail|objects\.get)\s*\('
# authorization exemptions
rg -ni 'public|permitAll|AllowAnonymous|skipAuth|@Public'
# mass assignment into a model
rg -n '\b(request|req)\.(body|all\(\)|params)\b.*\b(save|create|update|assign|merge)\b'
# outbound requests — then read each for a destination allowlist
rg -n '\b(fetch|axios|got|request|httpx|requests\.(get|post)|HttpClient|RestTemplate|WebClient|curl_exec|file_get_contents)\b'
# CSRF exemptions
rg -ni 'csrf|VerifyCsrfToken|\$except|csrf\(\)\.disable|SameSite'
```
