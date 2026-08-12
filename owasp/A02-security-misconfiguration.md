# A02:2025 — Security Misconfiguration

**ID:** `A02:2025` · **2021:** A05:2021 (#5 → #2) · **Applies to:** any

## Rule

1. The application **fails to boot** when a security-relevant setting is missing
   or unsafe in production. Silent fallback to a permissive default is the bug.
2. Every allowlist names exact values. A wildcard origin, host, or permission is
   a finding unless the resource is genuinely public and credential-free.
3. Debug output, API docs, admin consoles, and management endpoints are off — or
   authenticated — in production, gated on the deployment environment rather than
   on a flag someone can flip.
4. Transport verification is never disabled. Turning off certificate validation
   to make an environment work is a permanent hole traded for a temporary fix.

## How it shows up in a backend API

- The classic pair: an origin allowlist assembled from an environment variable
  plus a regex. When the variable is unset the list silently contains an empty
  entry, and a hand-written regex leaves `.` unescaped so `corpXexample.com`
  matches. Both ship with `credentials: true`.
- "Reflect the request origin" written as a convenience for local development,
  then reached in a deployed environment because the guard was `!= production`
  and the environment is named `staging`.
- API documentation mounted unconditionally, with only the console log message
  gated by environment — so the docs are public and nobody notices.
- TLS verification disabled against the database or an internal service, usually
  with a comment explaining it was temporary.
- Security headers simply absent, because nothing fails without them.
- Defaults inherited from a framework or an image: sample credentials, a default
  admin path, directory listing, verbose server banners, a management port bound
  to `0.0.0.0`.
- Configuration read directly from the environment in dozens of places rather
  than through one validated schema, so no single place can assert correctness.

## Anti-pattern

```
cors(origin: [env("CORS_ORIGIN"), /\.example.com$/], credentials: true)
     # unset env -> [null, ...]; unescaped dot -> exampleXcom matches

if env("NODE_ENV") != "production": log("docs at /docs")
mount_docs("/docs")                       # mounted regardless of environment

db.connect(..., verify_tls: false)        # "temporary"
```

## Correct

```
config = ConfigSchema.parse(env)          # one schema; unknown/missing -> throw

assert_safe_for_production():             # runs at boot, before serving
    if config.env == "production":
        require config.cors_origins is non-empty
        require config.rate_limit_enabled
        require not config.debug
        require config.tls_verify

cors(origin: config.cors_origins, credentials: true)   # exact hosts, no regex
if config.env != "production": mount_docs("/docs")     # or mount behind auth
set_security_headers()                                 # deny framing, nosniff, HSTS, referrer
```

Prefer an exact-host list over a regex. If a pattern is unavoidable, escape the
dots and anchor both ends — and put a test on it.

## Idiom by stack

| Stack | Where it goes wrong |
|---|---|
| NestJS | `enableCors` from env, Swagger mounted unconditionally, no `helmet()`, `trustServerCertificate` / `rejectUnauthorized: false` |
| Laravel | `APP_DEBUG=true` in production, `.env` reachable, `APP_KEY` unset, permissive `config/cors.php` |
| Spring Boot | Actuator exposed, `@CrossOrigin("*")`, `server.error.include-stacktrace`, `spring.jpa.show-sql` |
| Any container | management port bound to `0.0.0.0`, base-image defaults, secrets baked into layers |

→ `stacks/nestjs.md (NEST.9, NEST.12, NEST.13)` · `stacks/laravel.md (LAR.7)` · `stacks/spring-boot.md (SPR.6)`

## Review questions

- **A02.Q1** — Is configuration parsed once through a schema that rejects missing
  or malformed values, rather than read ad hoc from the environment?
- **A02.Q2** — Does the app refuse to boot in production when a security setting
  is missing, disabled, or empty?
- **A02.Q3** — Can the origin allowlist end up empty, containing a null entry, or
  reflecting the request origin? Is it combined with credentialed requests?
- **A02.Q4** — If a host pattern is used, are its dots escaped and both ends
  anchored?
- **A02.Q5** — Are API docs, debug endpoints, and management/admin consoles
  gated on the deployment environment (not a flag) or behind authentication?
- **A02.Q6** — Are the standard response headers set (framing denied, nosniff,
  referrer policy, HSTS where applicable)?
- **A02.Q7** — Does any change disable certificate or hostname verification?
- **A02.Q8** — Does this change introduce a new default that is permissive when
  the corresponding variable is absent?

## Grep signals

```bash
rg -n '(origin|Origin).*(\*|true|reflect|req\.headers)'
rg -ni 'rejectUnauthorized|trustServerCertificate|verify\s*=\s*False|InsecureSkipVerify|ALLOW_ALL'
rg -ni 'app_debug|debug\s*[:=]\s*true|show-sql|include-stacktrace|DEBUG\s*=\s*True'
rg -ni 'swagger|openapi|/docs|actuator|graphiql|adminer'
rg -n 'CrossOrigin|Access-Control-Allow-Origin'
```
