# A09:2025 — Security Logging & Alerting Failures

**ID:** `A09:2025` · **2021:** A09:2021, renamed from "…and Monitoring Failures" · **Applies to:** any

## Rule

1. Log by **allowlist**. Name the fields worth recording; never log a request
   body, a query object, a decoded token, or a header map wholesale.
2. Security-relevant events are logged as structured events with the actor, the
   subject, the action, and the outcome: authentication, authorization denials,
   privilege changes, and access to sensitive records.
3. A denylist of sensitive key names is not redaction. It misses every field it
   was not told about, and misses nothing at all inside nested or encoded values.
4. Logs are evidence: an event nobody can be alerted on, or that is dropped under
   load, does not count as logged.

## How it shows up in a backend API

- A logging interceptor added for debugging merges body and query into one object
  and logs it on every request. It ships. Months later it is the largest
  collection of personal data in the system, in a place with weaker access
  control than the database.
- The same interceptor decodes the bearer token "for context" and logs the entire
  claim set — identifiers, roles, tenant, sometimes the token itself. Redaction
  by key name never sees it, because the claims arrived as one `user` object.
- Redaction is a fixed set of key names (`password`, `authorization`). Everything
  else — national ids, emails, free-text answers, file names, addresses — is
  recorded verbatim, and a field renamed in a refactor silently leaves the list.
- Authentication succeeds and fails with no event recorded, so credential
  stuffing is invisible; authorization denials are returned to the caller but
  never logged, so probing is invisible too.
- Errors go to an aggregator with full request context attached, which quietly
  re-introduces every field the logger was careful to strip.
- Log values containing newlines let a caller forge log entries — the same defect
  as injection, aimed at whoever reads the logs (see A05).

## Anti-pattern

```
interceptor on every request:
    log.info("request", { body: merge(req.body, req.query),
                          user: decode(req.headers.authorization) })
    # denylist ["password", "authorization"] never sees the claims or the PII

handler POST /auth/login:
    ...                                  # success and failure logged identically: not at all
```

## Correct

```
SAFE = ["request_id", "route", "method", "status", "duration_ms",
        "actor_id", "tenant_id"]                       # allowlist, no payloads

interceptor on every request:
    log.info("request", pick(context, SAFE))

handler POST /auth/login:
    on failure: audit("auth.login.failed", actor: hash(identifier), outcome: "denied")
    on success: audit("auth.login.succeeded", actor: user.id)

on authorization denial:
    audit("authz.denied", actor: caller.id, subject: resource_id, action: action)

sanitize(value) = strip_newlines(value)                # before it reaches a log line
```

The identifier in a failed login is itself sensitive — record a hash or a
truncated form when the account may not exist.

## Idiom by stack

| Stack | Notes |
|---|---|
| NestJS | interceptor + pino/winston; `redact` paths are a denylist — prefer picking fields |
| Laravel | log channels + a processor; never `Log::info($request->all())` |
| Spring Boot | logback with a filter; avoid `@Slf4j` logging of full DTOs; watch `spring.jpa.show-sql` |
| Any | error aggregator SDKs attach request context by default — configure the scrubber explicitly |

→ `stacks/nestjs.md (NEST.11)` · `stacks/laravel.md (LAR.9)` · `stacks/spring-boot.md (SPR.9)`

## Review questions

- **A09.Q1** — Does any new logging statement record a request body, query
  object, header map, or decoded token, in whole?
- **A09.Q2** — Is the logged shape an allowlist of named fields rather than a
  denylist of sensitive names?
- **A09.Q3** — Are authentication successes and failures, authorization denials,
  and privilege changes recorded as structured events with actor and outcome?
- **A09.Q4** — Does a failed-login event avoid recording a raw identifier for an
  account that may not exist?
- **A09.Q5** — Is caller-controlled text sanitized of newlines and control
  characters before entering a log line?
- **A09.Q6** — Does the error aggregator or APM attach request bodies/headers,
  and is its scrubber configured?
- **A09.Q7** — Is there an event a human or an alert could act on, and does it
  survive load (sampling, buffering, dropped logs)?

## Grep signals

```bash
rg -n '\b(log|logger|console|Log)\.(info|debug|warn|error|log)\b.*\b(body|payload|params|query|headers|user|token|claims)\b'
rg -n '\b(decode|jwtDecode|verify)\b.*\blog|log.*\bdecode\b'
rg -ni 'redact|scrub|sanitize|maskFields|SENSITIVE_KEYS'
rg -ni 'Sentry|Datadog|Bugsnag|newrelic|captureException'
```
