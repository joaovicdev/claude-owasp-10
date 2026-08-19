<!--
A real /api-secure-report run, not a mock-up. Target: examples/vulnerable-app/
in this repository, a NestJS app that is wrong on purpose. Reproduce it with:

    cp -R examples/vulnerable-app /tmp/run && git -C /tmp/run init -q
    ./install.sh --project /tmp/run
    cd /tmp/run && claude -p "/api-secure-report en"

Findings and wording will differ run to run — the route inventory and the ids
should not.
-->

# API security report — vulnerable-app

**Stack:** NestJS (`nest-cli.json` detected → `stacks/nestjs.md`)
**Scope:** repository root (`src/`)
**Date:** 2026-08-17
**Routes scanned:** 8 · **With findings:** 7 · **Clean:** 1

Rules are the `secure-coding` skill's; each `ref` (`A01.Q2`, `NEST.3`) resolves
against `owasp/*.md` and `stacks/nestjs.md`.

## Summary

| Severity | Count |
|---|---|
| Critical | 6 |
| High | 18 |
| Medium | 11 |
| Low | 0 |

| OWASP category | Findings |
|---|---|
| A01:2025 — Broken Access Control | 6 |
| A02:2025 — Security Misconfiguration | 5 |
| A03:2025 — Software Supply Chain Failures | 4 |
| A04:2025 — Cryptographic Failures | 2 |
| A05:2025 — Injection | 4 |
| A06:2025 — Insecure Design | 1 |
| A07:2025 — Authentication Failures | 3 |
| A09:2025 — Logging & Alerting Failures | 2 |
| A10:2025 — Mishandling of Exceptional Conditions | 2 |
| NEST (stack) | 6 |

## Route inventory

Every route in the project, with or without a finding. The class-level
`@UseGuards(JwtGuard)` is joined onto each orders/users method.

| Method | Route | File | Guard | Status |
|---|---|---|---|---|
| POST | /auth/login | src/auth/auth.controller.ts:10 | none (public) | ⚠ A05.Q1, A04.Q1, A07.Q2, A09.Q3 |
| POST | /auth/reset | src/auth/auth.controller.ts:20 | none (public) | ⚠ A05.Q1, A01.Q1, A04.Q3, A06.Q5 |
| GET | /orders/:id | src/orders/orders.controller.ts:12 | JwtGuard | ⚠ A01.Q2, NEST.2 |
| GET | /orders/:id/timeline | src/orders/orders.controller.ts:17 | JwtGuard | OK — scoped by `tenantId` |
| GET | /orders | src/orders/orders.controller.ts:22 | JwtGuard | ⚠ A05.Q2, A05.Q1 |
| POST | /orders/import | src/orders/orders.controller.ts:29 | JwtGuard | ⚠ A01.Q9, A01.Q10 |
| GET | /users/:id | src/users/users.controller.ts:10 | JwtGuard | ⚠ A01.Q2, NEST.2 |
| PATCH | /users/:id | src/users/users.controller.ts:15 | JwtGuard | ⚠ A01.Q2, NEST.1, NEST.2, A10.Q2 |

The one clean route, `GET /orders/:id/timeline`, is the tell: it scopes its query
by `user.tenantId` (`src/orders/orders.controller.ts:19`), which is exactly what
its sibling `GET /orders/:id` fails to do.

## Findings

Route-scoped defects — those that live inside a single handler. Ordered by
severity, then module.

### 1. POST /auth/login — Critical — `A05.Q1`

- **Vulnerable route:** `POST /auth/login` (`src/auth/auth.controller.ts:13`)
- **The vulnerability:** The query is built by interpolating the caller-supplied
  `body.email` (and the MD5 hash) straight into the SQL string via
  `db.query(\`... WHERE email = '${body.email}' ...\`)`. Nothing is bound — a raw,
  unauthenticated SQL injection sink on the login path.
- **How an attacker exploits it:** Send `POST /auth/login` with
  `{"email":"' OR '1'='1' -- ","password":"x"}`. The query resolves to
  `SELECT * FROM users WHERE email = '' OR '1'='1' -- ...`, returning the first
  row. The handler then signs a JWT with that row's `sub` and `role` (line 17),
  minting a valid token for an arbitrary account (e.g. an admin) with no
  credential. UNION payloads extract any column the DB user can reach.
- **Mitigation:** Parameterize —
  `db.query('SELECT id, role FROM users WHERE email = $1 AND password = $2', [body.email, hash])`.
  Bind every caller value, select named columns (not `*`), and validate `body`
  through a DTO behind `ValidationPipe({ whitelist: true, forbidNonWhitelisted: true })`.

### 2. POST /auth/reset — Critical — `A05.Q1`

- **Vulnerable route:** `POST /auth/reset` (`src/auth/auth.controller.ts:24`)
- **The vulnerability:** `body.email` is interpolated into an
  `UPDATE users SET reset_token = '...' WHERE email = '${body.email}'` string —
  an unauthenticated SQL injection on a **write** path.
- **How an attacker exploits it:** `POST /auth/reset` with
  `{"email":"' OR '1'='1' -- "}` makes the query
  `UPDATE users SET reset_token = '<t>' WHERE email = '' OR '1'='1' -- '`,
  overwriting the reset token of every row. Combined with the token being echoed
  in the response (finding 5), this is mass account takeover.
- **Mitigation:** `db.query('UPDATE users SET reset_token = $1 WHERE email = $2', [token, body.email])`.
  Validate `body.email` with `@IsEmail()` behind a strict `ValidationPipe`.

### 3. GET /orders — Critical — `A05.Q2`

- **Vulnerable route:** `GET /orders` (`src/orders/orders.controller.ts:25`)
- **The vulnerability:** The `sort` query parameter is interpolated directly into
  the `ORDER BY` clause of a raw query with no allowlist. An identifier position
  cannot be bound — only an allowlist protects it, and there is none.
- **How an attacker exploits it:** An authenticated caller requests
  `GET /orders?sort=(CASE WHEN (SELECT ...) THEN id ELSE 1 END)` — a blind
  boolean/time-based subquery in the `ORDER BY` position — to exfiltrate arbitrary
  data, or a stacked payload to damage the database.
- **Mitigation:** Enforce an allowlist at the query site:
  `const ORDERABLE = new Set(['created_at','total','status']); if (!ORDERABLE.has(sort)) throw new BadRequestException();`
  and constrain the DTO field with `@IsIn([...])` (NEST.7). Prefer the query
  builder with named columns over raw SQL.

### 4. POST /orders/import — Critical — `A01.Q9`

- **Vulnerable route:** `POST /orders/import` (`src/orders/orders.controller.ts:31`)
- **The vulnerability:** The handler fetches a caller-supplied URL server-side
  (`axios.get(body.url)`) and returns the body. No destination allowlist, no
  resolved-address check — server-side request forgery. (Also `A06.Q4`: the same
  endpoint is an unbounded outbound-request / denial-of-wallet sink.)
- **How an attacker exploits it:** `POST /orders/import` with
  `{"url":"http://169.254.169.254/latest/meta-data/iam/security-credentials/"}`
  returns the cloud IAM credentials; `{"url":"http://localhost:9200/_search"}`
  reads internal-only services. The fetched `data` is handed straight back.
- **Mitigation:** Resolve the hostname, reject non-public / non-allowlisted
  addresses at the call site, and pin the connection to the resolved address
  (NEST.17). Do not relay the raw fetched body to the caller.

### 5. POST /auth/reset — Critical — `A01.Q1` (also `A04.Q6`, `A06.Q1`)

- **Vulnerable route:** `POST /auth/reset` (`src/auth/auth.controller.ts:26`)
- **The vulnerability:** The reset token is returned in the HTTP response
  (`return { sent: true, token }`) to whoever supplied the email, and stored in
  plaintext in `users.reset_token`. Proof of mailbox control is never required.
- **How an attacker exploits it:** `POST /auth/reset` with
  `{"email":"victim@corp.com"}` returns `{"sent":true,"token":"<reset_token>"}`.
  The attacker holds the victim's live token and completes the reset flow —
  full account takeover without touching the victim's inbox.
- **Mitigation:** Never return the token. Deliver it out-of-band (email) and store
  only its hash. Return a constant `{ sent: true }` regardless of whether the
  email exists (also closes the enumeration oracle).

### 6. GET /orders — High — `A05.Q1`

- **Vulnerable route:** `GET /orders` (`src/orders/orders.controller.ts:25`)
- **The vulnerability:** `user.tenantId` is concatenated into the SQL string
  (`WHERE tenant_id = '${user.tenantId}'`) instead of being bound. The value comes
  from the JWT payload; a quote in that claim breaks out of the literal, and the
  raw-string form is a broken injection defense regardless.
- **How an attacker exploits it:** A token carrying `tenantId` = `' OR '1'='1`
  resolves to `WHERE tenant_id = '' OR '1'='1'`, returning every tenant's orders.
- **Mitigation:** Bind the value —
  `db.query('SELECT id, ... FROM orders WHERE tenant_id = $1 ORDER BY ...', [user.tenantId])`
  or the query builder with `where('tenant_id = :t', { t: user.tenantId })`.
  Replace `SELECT *` with named columns.

### 7. GET /orders/:id — High — `A01.Q2`

- **Vulnerable route:** `GET /orders/:id` (`src/orders/orders.controller.ts:14`)
- **The vulnerability:** The Order is looked up by the caller-supplied `:id` with
  no tenant scope (`findOne({ where: { id } })`). `JwtGuard` proves *who* the
  caller is, not *what* they may reach. The sibling `/:id/timeline` scopes by
  `user.tenantId`, confirming this one is the mistake (`A01.Q4`).
- **How an attacker exploits it:** Any authenticated user requests
  `GET /orders/<uuid>` for another tenant's order; the row resolves and the full
  order is returned. Enumerate ids to read every order in the system.
- **Mitigation:** Scope the lookup in the predicate —
  `findOne({ where: { id, tenantId: user.tenantId } })` — and return 404 on a
  miss. Push the tenant scope into a repository/scope so no route can forget it
  (NEST.3).

### 8. POST /orders/import — High — `A01.Q10`

- **Vulnerable route:** `POST /orders/import` (`src/orders/orders.controller.ts:31`)
- **The vulnerability:** The outbound `axios.get` uses defaults: it follows
  redirects (up to 5) and has no timeout. A `302` walks the client past any
  address check made before the call; the missing timeout allows resource
  exhaustion.
- **How an attacker exploits it:** Point `url` at an allowlisted host they control
  that responds `302 Location: http://169.254.169.254/...`; axios follows it to
  the internal target after the pre-check passed. Or a slow/hanging target ties up
  connections indefinitely.
- **Mitigation:** Pass `{ maxRedirects: 0, timeout: 5000 }` and re-validate the
  resolved address on the connection, not the hostname (NEST.17).

### 9. GET /users/:id — High — `A01.Q2`

- **Vulnerable route:** `GET /users/:id` (`src/users/users.controller.ts:12`)
- **The vulnerability:** The User is looked up purely by the caller-supplied `:id`
  (`findOne({ where: { id } })`) with no owner scope. The guard sets
  `req.user = { sub, role }`, but the query ignores it — broken object-level
  authorization (IDOR).
- **How an attacker exploits it:** With any valid JWT, request
  `GET /users/<victimId>`, iterating `:id`. Each returns the full victim record —
  and because the entity is returned verbatim (finding 10), that includes the
  password hash and role.
- **Mitigation:** Scope by the caller in the predicate (e.g.
  `{ where: { id: caller.sub } }` for a self-profile, or `{ id, tenantId }` for an
  authorized cross-user read), return 404 on a miss, and never scope with a
  post-fetch `if` (NEST.3).

### 10. GET /users/:id — High — `NEST.2`

- **Vulnerable route:** `GET /users/:id` (`src/users/users.controller.ts:12`)
- **The vulnerability:** The handler returns the persistence entity directly. No
  response DTO, no `ClassSerializerInterceptor`, no `@Exclude()`. The User table
  holds `password` (an MD5 hash) and `role` (confirmed at
  `src/auth/auth.controller.ts:14-17`), so the full row — credentials material
  included — is serialized to the caller.
- **How an attacker exploits it:** `GET /users/<id>` returns JSON containing the
  `password` column and `role`.
- **Mitigation:** Return an explicit shape (`{ id, email, name }` — secrets
  opt-in), or register `ClassSerializerInterceptor` and annotate secret columns
  with `@Exclude()`. Do not return the entity from the controller.

### 11. PATCH /users/:id — High — `A01.Q2`

- **Vulnerable route:** `PATCH /users/:id` (`src/users/users.controller.ts:18`)
- **The vulnerability:** The update fetches the User by caller-supplied `:id` with
  no owner scope and then writes to it — the same IDOR as finding 9, but on a
  write, so the impact is tampering / takeover, not just disclosure.
- **How an attacker exploits it:** `PATCH /users/<victimId>` with any body loads
  the victim's row and saves the mutated version. Chained with finding 12, an
  attacker rewrites another user's fields entirely.
- **Mitigation:** Scope the lookup by the caller in the `where` predicate, return
  404 on a miss, and enforce the scope in the query — never a post-fetch `if`
  (NEST.3, A01.Q2).

### 12. PATCH /users/:id — High — `NEST.1`

- **Vulnerable route:** `PATCH /users/:id` (`src/users/users.controller.ts:19`)
- **The vulnerability:** Mass assignment. `@Body() body: any` is bound with no
  DTO and no allowlist, then copied wholesale onto the entity via
  `Object.assign(user, body)` and saved. The caller controls every column,
  including `role` and `password`.
- **How an attacker exploits it:** `PATCH /users/<id>` with `{"role":"admin"}`
  escalates the account; `{"password":"<attacker-hash>"}` overwrites credentials.
  Chained with finding 11, this is full takeover of an arbitrary user.
- **Mitigation:** Introduce an `UpdateUserDto` listing only mutable fields,
  register a global `ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true })`
  (see finding 22), and update via an explicit allowlisted set
  (`repo.update({ id, ...scope }, { name, email })`) instead of `Object.assign`
  (NEST.1).

### 13. PATCH /users/:id — High — `NEST.2`

- **Vulnerable route:** `PATCH /users/:id` (`src/users/users.controller.ts:20`)
- **The vulnerability:** The handler returns the persisted entity directly
  (`return repo.save(user)`), so the saved row — `password` hash and `role`
  included — is serialized back, the same leak as finding 10 on the write path.
- **How an attacker exploits it:** `PATCH /users/<id>` with any body returns the
  full saved row, disclosing the `password` column and `role`.
- **Mitigation:** Return an explicit response shape, or apply
  `ClassSerializerInterceptor` + `@Exclude()`. Do not return the entity from
  `save()`.

### 14. GET /orders/:id — Medium — `NEST.2`

- **Vulnerable route:** `GET /orders/:id` (`src/orders/orders.controller.ts:14`)
- **The vulnerability:** The handler returns the raw TypeORM Order entity, opting
  the entire persistence shape into the response instead of an explicit DTO. Any
  sensitive column (costs, internal notes, customer PII) is exposed opt-out.
- **How an attacker exploits it:** `GET /orders/<id>` returns every column the
  Order entity carries, including fields never meant for the API surface.
- **Mitigation:** Build an explicit `OrderResponse` DTO, or apply
  `ClassSerializerInterceptor` with `@Exclude()` on sensitive columns.

### 15. PATCH /users/:id — Medium — `A10.Q2`

- **Vulnerable route:** `PATCH /users/:id` (`src/users/users.controller.ts:18`)
- **The vulnerability:** `findOne` returns `null` for a missing id, after which
  `Object.assign(null, body)` throws — "not found" is never treated as a defined
  outcome, so an unauthorized/nonexistent id yields a 500 rather than a 404. With
  no exception filter registered, the raw error surfaces.
- **How an attacker exploits it:** `PATCH /users/<nonexistent-id>` produces a
  TypeError → 500; the distinct error shape also helps distinguish existing from
  non-existing ids.
- **Mitigation:** After the scoped `findOne`, return `NotFoundException` (404) when
  the row is absent, and register a global exception filter (finding 34) mapping
  non-`HttpException` errors to a generic body with a correlation id.

### 16. POST /auth/login — Medium — `A07.Q2` (also `A10.Q3`)

- **Vulnerable route:** `POST /auth/login` (`src/auth/auth.controller.ts:16`)
- **The vulnerability:** Login distinguishes "unknown account" from "wrong
  password" — the message is `'No user with that email'`, and the differing code
  paths differ in timing. Login becomes a user enumerator.
- **How an attacker exploits it:** Submit candidate emails with a junk password;
  a `401 "No user with that email"` (and the faster response) means the account
  does not exist. Iterating a list enumerates valid accounts for credential
  stuffing and the reset-token abuse.
- **Mitigation:** Return one generic message/shape for all auth failures
  (`UnauthorizedException('Invalid credentials')`). Always run a password
  verification against a constant dummy hash when no user is found, so timing is
  equal either way.

## Global findings

Not tied to one route — project-wide properties. **Component** replaces
**Vulnerable route**. Ordered by severity.

### 17. JWT guard — Critical — `A07.Q3`

- **Component:** `src/auth/jwt.guard.ts:13`
- **The vulnerability:** The verification secret falls back to a hardcoded default,
  `process.env.JWT_SECRET || 'dev-secret-change-me'`. When the env var is unset the
  guard verifies tokens against a constant that is public to anyone with the
  source.
- **How an attacker exploits it:** Forge a token with the known secret —
  `jwt.sign({ sub: 1, role: 'admin' }, 'dev-secret-change-me')` — and call any
  guarded endpoint with `Authorization: Bearer <forged>`. The guard accepts it and
  sets `req.user = { sub: 1, role: 'admin' }`: full impersonation and privilege
  escalation with no credential.
- **Mitigation:** Read the secret from validated config with **no default**, so a
  missing value fails at boot. Register `JwtModule` centrally with that secret and
  pin `algorithms: ['HS256']`. Never embed a literal fallback secret.

### 18. JWT guard — High — `A07.Q4`

- **Component:** `src/auth/jwt.guard.ts:12`
- **The vulnerability:** `jwt.verify` pins no `algorithms` allowlist (nor
  issuer/audience). The token, not the server, chooses how it is validated — the
  classic algorithm-confusion surface.
- **How an attacker exploits it:** Craft a token whose header selects an algorithm
  the server did not intend to honor; verification is driven by attacker-controlled
  header fields, widening forgery options.
- **Mitigation:** `jwt.verify(token, { secret, algorithms: ['HS256'] })`, and pin
  `issuer`/`audience` from validated config. Configure the same in
  `JwtModule.register({ verifyOptions: { algorithms: [...] } })`.

### 19. Password hashing (login) — High — `A04.Q1`

- **Component:** `src/auth/auth.controller.ts:12`
- **The vulnerability:** Passwords are compared as an unsalted MD5 digest
  (`createHash('md5')`). MD5 is a fast, broken hash — not memory-hard — and there
  is no per-user salt. A dump of `users.password` is trivially reversed.
- **How an attacker exploits it:** With the users table (via finding 1, a backup,
  or a replica), MD5 values fall to rainbow tables / GPU cracking at billions of
  guesses/second, recovering every plaintext password for reuse here and elsewhere.
- **Mitigation:** Use `argon2id` or `bcrypt` with tuned, recorded parameters;
  verify with the library's constant-time `verify`/`compare`. Rehash existing MD5
  hashes on next successful login.

### 20. Password-reset token PRNG — High — `A04.Q3`

- **Component:** `src/auth/auth.controller.ts:22`
- **The vulnerability:** The reset token is `Math.random().toString(36).slice(2)`.
  `Math.random()` is not a CSPRNG — predictable given a few observations of the V8
  PRNG state — and the base-36 slice is low entropy.
- **How an attacker exploits it:** Request a reset, observe/derive `Math.random()`
  outputs, reconstruct the PRNG state, and predict the victim's token — or
  brute-force the short space — then complete the reset.
- **Mitigation:** `crypto.randomBytes(32).toString('hex')`. Store only its hash
  with an expiry and single-use flag; compare with `crypto.timingSafeEqual`.

### 21. Bootstrap — CORS — High — `A02.Q3`

- **Component:** `src/main.ts:8`
- **The vulnerability:** `enableCors({ origin: true, credentials: true })`.
  `origin: true` reflects the caller's Origin, so every origin is allowed while
  cookies/Authorization are permitted. No env gating, no host allowlist.
- **How an attacker exploits it:** A logged-in victim visits `https://evil.example`,
  which runs `fetch('https://<api>/orders', { credentials: 'include' })`. The API
  replies with `Access-Control-Allow-Origin: https://evil.example` +
  `Access-Control-Allow-Credentials: true`, so the attacker's script reads the
  authenticated response.
- **Mitigation:** Use an exact-host allowlist from validated config —
  `enableCors({ origin: config.corsOrigins, credentials: true })`. Never pair
  `origin: true` with `credentials: true` (NEST.12).

### 22. Bootstrap — no global ValidationPipe — High — `NEST.1`

- **Component:** `src/main.ts:5` (and `src/app.module.ts` — no `APP_PIPE`)
- **The vulnerability:** No global `ValidationPipe` is registered anywhere.
  Application-wide, DTO validation, whitelisting, and transform do not run, so
  request bodies are accepted with arbitrary extra properties unless every handler
  opts in — which enables the mass assignment in finding 12.
- **How an attacker exploits it:** Send a body with unexpected fields
  (`{"role":"admin", ...}`) to any body-binding endpoint; the extras are neither
  stripped nor rejected and reach the persistence layer.
- **Mitigation:** Register one global pipe:
  `app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }))`
  (or an `APP_PIPE` provider) — configured once (NEST.1).

### 23. Request logger — High — `A09.Q1`

- **Component:** `src/common/request-logger.middleware.ts:8`
- **The vulnerability:** The middleware logs the entire header map and body on
  every request via `JSON.stringify(req.headers)` / `JSON.stringify(req.body)` —
  capturing `Authorization: Bearer <jwt>` and every credential (e.g. the login
  `password`, the reset `email`). No allowlist, no redaction. **Currently latent:**
  `AppModule` does not implement `NestModule`/`configure()`, so the middleware is
  registered as a provider but never applied — severity downgraded from critical to
  high; the leak activates the moment anyone wires it.
- **How an attacker exploits it:** Once attached (a one-line `configure()` change),
  `POST /auth/login {"password":"hunter2"}` and every bearer token land verbatim in
  logs, which usually have weaker access control than the database.
- **Mitigation:** Log by allowlist only — build the line from named fields
  (`method`, `url`, a request id, status, duration). Never stringify `headers` or
  `body`. Prefer a pino/winston interceptor picking safe fields over a redact
  denylist.

### 24. Global exception filter — High — `A10.Q3`

- **Component:** `src/common/all-exceptions.filter.ts:7`
- **The vulnerability:** `catch` returns `exception.message`, `exception.stack`,
  and `exception.query` to the caller. Any DB/driver error hands back table/column
  names, source paths, and the failing SQL; it also collapses everything to 500 and
  logs nothing. **Currently latent:** the filter is not registered
  (`main.ts` has no `useGlobalFilters`, `app.module.ts` has no `APP_FILTER`) —
  severity downgraded from critical to high.
- **How an attacker exploits it:** Once registered, trigger a DB error (e.g. the
  SQLi at `auth.controller.ts:14` via `POST /auth/login {"email":"'"}`); the 500
  body contains `query` (the exact SQL) and `stack` (internal paths) — a free map
  of the schema and codebase.
- **Mitigation:** Return a generic body for non-`HttpException` errors
  (`{ message: "Internal server error", id: correlationId }`), pass through only the
  public message/status for `HttpException`, and send `message`/`stack`/`query`
  to the logger keyed by the correlation id. Never put `stack` or `query` in the
  response.

### 25. Dependencies — axios — High — `A03.Q7`

- **Component:** `package.json:12` (`"axios": "^0.21.1"`)
- **The vulnerability:** axios is pinned to a version affected by known CVEs
  (CVE-2021-3749 ReDoS; SSRF / URL-parsing / redirect issues fixed only in 0.27+).
  The caret floats within 0.21.x, which never receives those fixes.
- **How an attacker exploits it:** A URL/header value passed to axios (the SSRF
  endpoint in finding 4) reaches the vulnerable client; the outdated parser widens
  the SSRF/redirect surface, and the ReDoS path is reachable. The vulnerable
  version resolves at every install.
- **Mitigation:** Upgrade to a current 1.x (e.g. exact `1.7.x`) and commit a
  lockfile so the patched artifact is installed.

### 26. Dependencies — postinstall hook — High — `A03.Q3`

- **Component:** `package.json:6` (`"postinstall": "node scripts/setup.js"`)
- **The vulnerability:** A `postinstall` hook runs `node scripts/setup.js` on every
  install, but no `scripts/` directory exists. Install hooks execute arbitrary code
  with developer/CI privileges; a missing script that is later added (or a
  transitive package's own hook) runs unreviewed code at install time.
- **How an attacker exploits it:** Anyone who lands a `scripts/setup.js` (a PR, a
  compromised branch, a dependency that creates it) gets code execution on every
  `npm install` on dev machines and CI, with whatever tokens those hold.
- **Mitigation:** Remove the hook if unneeded, or commit the exact reviewed
  `scripts/setup.js`; install with `--ignore-scripts` in CI where feasible. Treat
  all install hooks as code that will run.

### 27. Dependencies — no lockfile — High — `A03.Q2`

- **Component:** `package.json:1` (no `package-lock.json` / `yarn.lock` / `pnpm-lock.yaml`)
- **The vulnerability:** No lockfile is committed. Combined with caret ranges on
  every dependency, each install can resolve different transitive artifacts — the
  deployed code is not guaranteed to be the tested code.
- **How an attacker exploits it:** A hijacked-maintainer patch bump within any
  allowed caret range (e.g. `@nestjs/*` or a transitive dep) is pulled on the next
  install with no manifest change, giving code execution in build/CI. There is no
  `npm ci` reproducibility barrier.
- **Mitigation:** Commit a lockfile and install from it via `npm ci`; update the
  lockfile in the same change as any dependency change.

### 28. Password-reset token lifetime — Medium — `A06.Q5`

- **Component:** `src/auth/auth.controller.ts:22`
- **The vulnerability:** The reset token has no expiry and no use count — once
  issued it is valid indefinitely and reusable.
- **How an attacker exploits it:** A token captured once (finding 5, or a leaked
  log line) stays valid forever and can be redeemed at any later time.
- **Mitigation:** Store `reset_token_expires_at` (e.g. now + 15 min) and a
  single-use marker; reject expired/consumed tokens and clear the token on
  successful reset.

### 29. Login — no auth audit event — Medium — `A09.Q3`

- **Component:** `src/auth/auth.controller.ts:16` (and `src/auth/jwt.guard.ts:17`)
- **The vulnerability:** No structured event is recorded on login success or
  failure, nor on guard denial. Credential stuffing and password spraying against
  `POST /auth/login` are invisible — nothing accumulates for alerting.
- **How an attacker exploits it:** Run a high-volume credential-stuffing campaign;
  with no failed-login event emitted, the attack proceeds undetected until an
  account is compromised.
- **Mitigation:** Emit `auth.login.succeeded` (with `actor`) and
  `auth.login.failed` (hashed identifier, `outcome: "denied"`), plus `authz.denied`
  when the guard rejects a token. Ensure the events can drive an alert.

### 30. Bootstrap — Swagger exposed — Medium — `A02.Q5`

- **Component:** `src/main.ts:11`
- **The vulnerability:** Swagger/OpenAPI is mounted unconditionally at `/docs` with
  no env gate and no auth; the full API surface is publicly discoverable in
  production.
- **How an attacker exploits it:** `GET /docs` (and `/docs-json`) returns the
  complete endpoint catalogue, parameters, and schemas — a probing map, no
  credential required.
- **Mitigation:** Gate the mount on environment
  (`if (config.env !== 'production') SwaggerModule.setup(...)`) or place it behind
  auth (NEST.12).

### 31. Bootstrap — debug logger in production — Medium — `A02.Q5`

- **Component:** `src/main.ts:6`
- **The vulnerability:** The logger is hard-wired to `['debug', 'verbose']` with no
  env gating, so debug/verbose output (SQL, routing, internals) ships in production.
- **How an attacker exploits it:** In production the process emits debug/verbose
  lines for every request; anyone with log access reads internal query/routing
  detail that should be suppressed.
- **Mitigation:** Set levels from validated config gated on `config.env` —
  `logger: config.env === 'production' ? ['error','warn','log'] : ['debug','verbose']`.

### 32. Bootstrap — no security headers — Medium — `A02.Q6`

- **Component:** `src/main.ts:5`
- **The vulnerability:** No `helmet()` is applied, so `X-Content-Type-Options:
  nosniff`, framing restrictions/CSP, referrer policy and HSTS are all absent.
- **How an attacker exploits it:** Responses ship without `nosniff` and framing
  restrictions, enabling MIME sniffing and clickjacking of any HTML-bearing
  response; the missing HSTS leaves TLS open to SSL-strip on first contact.
- **Mitigation:** `app.use(helmet())` before `app.listen` (NEST.9).

### 33. Bootstrap — no config validation — Medium — `A02.Q1`

- **Component:** `src/main.ts:5` (`process.env.PORT` at line 13; no boot-time asserts)
- **The vulnerability:** Config is read ad hoc from `process.env` with no schema and
  no `assertSafeProductionEnv()` gate. The app boots regardless of missing/unsafe
  settings (empty CORS allowlist, missing secret, debug logging on).
- **How an attacker exploits it:** Deploy to production with no CORS allowlist and a
  missing secret; the app starts cleanly (origin reflection on, secret silently
  defaulting) and serves traffic in an insecure configuration with nothing halting
  boot.
- **Mitigation:** Parse config once through a schema that rejects missing/malformed
  values, and call `assertSafeProductionEnv()` from `main.ts` that refuses to start
  in production when the origin list is empty, a secret is missing, or debug logging
  is on (A02.Q1/Q2, NEST.6).

### 34. App module — no global exception filter — Medium — `NEST.10`

- **Component:** `src/app.module.ts:7` (no `APP_FILTER`; `main.ts` has no `useGlobalFilters`)
- **The vulnerability:** No global exception filter is registered, so error
  responses are not normalized to a generic body with a correlation id, and
  non-`HttpException` errors fall through to framework defaults / ad-hoc handling.
- **How an attacker exploits it:** A request triggering an unhandled error (e.g. a
  driver exception) is handled by the default path rather than a controlled filter,
  so handling is inconsistent and cannot guarantee a generic body across routes.
- **Mitigation:** Register one `APP_FILTER` provider that passes `HttpException`
  public messages through and returns a generic body + correlation id for
  everything else, with detail to the logger only (NEST.10). (This is the same
  filter finding 24 and finding 15 depend on — once written, register it.)

### 35. Dependencies — floating caret ranges — Medium — `A03.Q1`

- **Component:** `package.json:8` (all deps use `^`)
- **The vulnerability:** Every dependency uses a floating caret range with no
  lockfile, so the transitive footprint and exact versions were never pinned or
  reviewed.
- **How an attacker exploits it:** Any of these packages or a transitive dep can
  ship a new in-range version between test and deploy; a supply-chain payload in a
  floating range reaches production with no code or manifest change.
- **Mitigation:** Pin direct dependencies to exact (or reviewed) versions and commit
  a lockfile so the resolved tree is fixed and auditable; review new versions before
  adopting them.

## Limits of this scan

- **Coverage:** 8 of 8 HTTP routes were enumerated and read (all three controllers
  opened and confirmed). No non-HTTP entry points exist — no `@MessagePattern`,
  `@EventPattern`, `@SubscribeMessage`, `@Cron`, or dynamically registered routes
  were found. The Swagger UI at `/docs` is a framework-mounted endpoint, covered as
  a config finding (30), not a project route.
- **Latent components:** `RequestLogger` (finding 23) and `AllExceptionsFilter`
  (finding 24) are defined but **not wired** — `AppModule` implements no
  `configure()` and there is no `useGlobalFilters`/`APP_FILTER`. Reported at
  downgraded severity; they become live the moment either is registered.
- **Not scanned:** there are no migrations, entity definitions, `Dockerfile`, CI
  workflows, or tests in the repository, so the `Order`/`User`/`OrderEvent` schemas
  were inferred from usage (`password`, `role`, `tenant_id`, `reset_token` columns)
  rather than read from a definition. No runtime, database, or network testing was
  performed — this is static review only.
- **No `SECURITY-NOTES.md`** exists at the scan root, so there are no accepted risks
  or previously-open findings to reconcile; every item above is reported fresh.
- Absence of a finding is not proof of absence of a vulnerability. The rules are the
  `secure-coding` skill's; a finding citing `A01.Q2` is resolvable against
  `owasp/A01-broken-access-control.md`, and `NEST.*` against `stacks/nestjs.md`.
