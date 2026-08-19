# A10:2025 — Mishandling of Exceptional Conditions

**ID:** `A10:2025` · **2021:** new category · **Applies to:** any

## Rule

1. Failure is denial. When a check cannot complete — the authorization service is
   down, the token cannot be parsed, the quota lookup times out — the answer is
   "no", never "continue".
2. Responses to callers carry a generic message and a correlation id. Exception
   text, stack traces, driver errors, and query fragments go to the logger only.
3. Handle exceptions where the decision can actually be made. A `catch` that
   swallows, logs-and-continues, or returns a default in place of a failed
   security check is a vulnerability, not resilience.
4. Partial failure has a defined outcome. If a multi-step operation fails halfway,
   state that the operation is atomic, compensated, or idempotent — one of the
   three, deliberately.

## How it shows up in a backend API

- A global exception handler that returns the raw exception message for anything
  that is not a known HTTP error. Ordinary database failures then hand the caller
  table names, column names, and constraint names.
- Per-handler `try/catch` blocks that reflect `error.message` back with a 400.
  Every one of them is an independent information leak, and they mask the real
  status code.
- `catch (e) { }` or `catch (e) { return default }` around a permission check, a
  signature verification, or a rate-limit lookup — turning an outage into an
  open door. This is the highest-severity shape in this category.
- Timeouts treated as absence rather than failure: "the entitlement service did
  not answer, so assume the user has no restrictions."
- Retries without idempotency, so a partially applied write is applied again;
  or without a cap, so one failure becomes a self-inflicted outage.
- The error path skipping the audit trail, so exactly the events worth
  investigating are the ones not recorded (see A09).
- Different failure shapes for different causes, letting a caller distinguish
  "no such account" from "wrong password" through the error (see A07).

## Anti-pattern

```
global handler(exception):
    return 500 { message: exception.message }     # driver text to the caller

handler ...:
    try:
        allowed = authz.check(caller, resource)
    catch:
        allowed = true                            # fail-open
    ...

try: audit(event)
catch: pass                                       # the record that mattered
```

## Correct

```
global handler(exception):
    id = correlation_id()
    if exception is KnownHttpError:
        return exception.status { message: exception.public_message, id }
    log.error("unhandled", id: id, error: exception)      # detail stays here
    return 500 { message: "Internal server error", id: id }

handler ...:
    allowed = authz.check(caller, resource)        # exception propagates -> 500, denied
    if not allowed: return 404

with_timeout(2s, retries: 2, idempotency_key: k):  # bounded, replay-safe
    call_downstream()
```

Let the security check throw. Reaching the global handler and denying the request
is the correct outcome; catching it locally is how fail-open gets written.

## Idiom by stack

| Stack | Notes |
|---|---|
| NestJS | one `ExceptionFilter`; generic body for non-`HttpException`; no per-controller `try/catch` echoing `error.message` |
| Laravel | `Handler::render`; `APP_DEBUG=false` in production; do not return `$e->getMessage()` |
| Spring Boot | `@ControllerAdvice`; `server.error.include-stacktrace=never`, `include-message=never` |
| Any | health/readiness must not leak dependency errors or versions |

→ `stacks/nestjs.md (NEST.10)` · `stacks/laravel.md (LAR.7)` · `stacks/spring-boot.md (SPR.6)`

## Review questions

- **A10.Q1** — When a security check (authz, signature, token parse, rate limit)
  throws or times out, is the request denied?
- **A10.Q2** — Does any `catch` swallow an error, log-and-continue, or substitute
  a default where a security decision was being made?
- **A10.Q3** — Can any exception message, stack trace, driver error, or query
  fragment reach the caller?
- **A10.Q4** — Is there one global handler, rather than per-handler `try/catch`
  blocks reflecting `error.message`?
- **A10.Q5** — Does the response carry a correlation id so the detail can be
  found in the logs?
- **A10.Q6** — For a multi-step operation, is the failure outcome atomic,
  compensated, or idempotent — and is that choice explicit?
- **A10.Q7** — Are retries bounded and replay-safe, and do timeouts exist on
  every outbound call?
- **A10.Q8** — Does the error path still emit the audit event?

## Grep signals

```bash
rg -n 'catch[^\n]*\{\s*\}|catch[^\n]*\{\s*(return|pass|continue)'
rg -n '\b(err|e|ex|exception|error)\b\.(message|getMessage\(\)|stack|toString\(\))'
rg -ni 'include-stacktrace|include-message|printStackTrace|traceback'
rg -ni 'timeout|retry|retries|backoff|idempot'
```
