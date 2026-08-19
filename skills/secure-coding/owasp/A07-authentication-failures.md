# A07:2025 — Authentication Failures

**ID:** `A07:2025` · **2021:** A07:2021, renamed from "Identification and Authentication Failures" · **Applies to:** any

## Rule

1. Every credential-accepting endpoint is rate limited per identifier **and** per
   source, and responds identically whether or not the account exists.
2. Signing and encryption keys come from validated configuration with no default.
   The verifier pins the algorithm; it never trusts the token to name it.
3. Secrets at rest are hashed with a memory-hard password hash, and compared in
   constant time. This includes API keys and reset tokens, not just passwords.
4. Logout, password change, and privilege change invalidate existing sessions and
   refresh tokens. A token that outlives the reason it was issued is a finding.

## How it shows up in a backend API

- The login route is the one endpoint with no rate limit, because throttling was
  configured globally and login was added later — or because the throttler is
  installed and its configuration is commented out.
- The signing secret is read at module construction time, so an absent variable
  produces a service that signs with `undefined` and boots cleanly.
- Distinct responses for "unknown user" and "wrong password" — in the message,
  the status code, or the response time — turn login into a user enumerator.
  Password reset and registration leak the same way.
- Refresh tokens issued without rotation or reuse detection, so a stolen token
  stays valid for its whole lifetime; and a long-lived refresh token that no
  logout revokes.
- API keys treated as a lesser credential: accepted from the query string, stored
  in plaintext, compared with an equality operator that returns early.
- Impersonation implemented as a first-class feature without a matching audit
  trail, so "who actually did this" is unanswerable afterwards.
- Reset tokens that are guessable, unexpiring, reusable, or valid after the
  password already changed.

## Anti-pattern

```
handler POST /auth/login:                       # no rate limit
    user = db.findByEmail(body.email)
    if not user: return 404 "user not found"    # enumeration
    if user.password != body.password: return 401
    return sign(user, secret: env("JWT_SECRET") or "dev-secret")

verify(token, algorithms: token.header.alg)     # attacker picks the algorithm
```

## Correct

```
handler POST /auth/login:
    rate_limit(key: [body.email, request.source], max: 5, per: minute)
    user = db.findByEmail(body.email)
    hash = user?.password_hash or DUMMY_HASH        # a real hash of a throwaway password
    ok   = verify_password_hash(hash, body.password)  # same work either way
    if not user or not ok: return 401 "invalid credentials"           # one response, one shape
    audit("login.success", subject: user.id)
    return issue_tokens(user)

verify(token, algorithms: ["EdDSA"], issuer: cfg.iss, audience: cfg.aud)
```

Verify against a **constant dummy hash** when the account does not exist. Passing
a null hash short-circuits in nearly every library, which leaves exactly the
timing signal this is meant to close. Generate `DUMMY_HASH` once with the same
algorithm and parameters as the real ones, or it costs a different amount of time
and the tell comes back. Enumeration through timing is the leak that survives
fixing the message.

## Idiom by stack

| Stack | Notes |
|---|---|
| NestJS | `ThrottlerGuard` global + `@Throttle` on auth routes; strategy secret from validated config, never `\|\| 'secret'` |
| Laravel | `RateLimiter`/`throttle` middleware on auth routes; `Hash::make`, `Hash::check`; `APP_KEY` required |
| Spring Boot | `SecurityFilterChain` ordering; `DelegatingPasswordEncoder`; decoder pins algorithm and issuer |
| Any | argon2id or bcrypt for passwords; SHA-256 + constant-time compare for high-entropy API keys |

→ `stacks/nestjs.md (NEST.5)` · `stacks/laravel.md (LAR.8)` · `stacks/spring-boot.md (SPR.8)`

## Review questions

- **A07.Q1** — Are login, refresh, registration, and password reset rate limited
  per identifier and per source?
- **A07.Q2** — Do "unknown account" and "wrong credential" produce identical
  responses, status codes, and roughly identical timing?
- **A07.Q3** — Can any signing/encryption key fall back to a default, or be
  read before configuration is validated?
- **A07.Q4** — Does verification pin the algorithm, issuer, and audience rather
  than accepting what the token declares?
- **A07.Q5** — Are stored credentials (including API keys and reset tokens)
  hashed and compared in constant time?
- **A07.Q6** — Do logout, password change, and role change invalidate existing
  sessions and refresh tokens?
- **A07.Q7** — Are refresh tokens rotated on use, with reuse detection?
- **A07.Q8** — Are token lifetimes explicit and short, and is every long-lived
  credential revocable?
- **A07.Q9** — If impersonation exists, is every impersonated action audited with
  both the acting and effective identity? (see `A01.Q8`)

## Grep signals

```bash
rg -n '(JWT_SECRET|SECRET|PRIVATE_KEY|API_KEY)[^\n]{0,40}(\|\||\?\?|:\s*["'"'"']|getOrDefault|,\s*["'"'"'])'
rg -ni 'expiresIn|expires_in|setExpiration|ttl|maxAge'
rg -ni 'algorithms?\s*[:=]|decode\(|verify\(|none.*alg'
rg -ni 'throttle|rate.?limit|bucket' 
rg -ni 'compare|equals|==.*\b(token|apikey|api_key|secret|hash)\b'
```
