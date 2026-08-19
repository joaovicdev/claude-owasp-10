# NestJS — stack idiom

**ID prefix:** `NEST` · **Status:** grounded in production NestJS code (TypeORM,
passport-jwt, CASL, global `APP_GUARD`). Ordered by observed frequency — the
earlier the item, the more often it was actually wrong. Findings are stated as
patterns; no project is identified, per `CONTRIBUTING.md`.

Vocabulary assumed here: **use-case** for the application-service unit, `@core/`
(domain/application/infra) and `modules/` as the two layouts, `@User()` /
`@CurrentTenant()` param decorators, CASL `@CheckAbilities`, global `APP_GUARD`
with a `@Public()` opt-out. Rename freely — the items are about shape, not names.

### NEST.1 — `ValidationPipe` is never bare → A05, A01

`new ValidationPipe()` with no options accepts every extra property in the body,
which is mass assignment waiting for a model that binds it.

```ts
app.useGlobalPipes(new ValidationPipe({
  whitelist: true, forbidNonWhitelisted: true, transform: true,
}));
```

Global pipes are **appended**, not replaced — a second bare pipe registered later
in the bootstrap chain hides the real configuration and is one deletion away from
silently dropping `whitelist`. Register once, in one place.

### NEST.2 — Never return a persistence entity → A01, A04

The common shape is no `ClassSerializerInterceptor` anywhere and no `@Exclude()`
on any entity. The consequence is direct — `return this.repo.save(user)`
from a controller path returns the password hash. Pick one and apply it
consistently: an explicit response DTO built in the use-case, or
`ClassSerializerInterceptor` plus `@Exclude()` on every secret column. A handler
typed `Promise<any>` is the smell that precedes this.

### NEST.3 — A use-case taking an id also takes the caller → A01

The most frequent real bug. `execute(ticketId)` with no caller context, sitting
next to a sibling route that does pass `@User() user`.

```ts
// wrong                                   // right
execute(id)                                execute(id, caller)
repo.findOne({ where: { id } })            repo.findOne({ where: { id, tenantId: caller.tenantId } })
```

Scope in the `where`, never in an `if` after the fetch. Put it in the repository
so route #12 cannot forget it. `findOne({ where: { id, tenantId } })` is the house
pattern worth copying.

### NEST.4 — `@Public()` needs a compensating control → A01

The recurring shape is `@Public()` on a state-changing endpoint, annotated as a
temporary measure until API key authentication is wired up — a permanent hole
with a temporary comment. Every `@Public()` carries a compensating control in the same
decorator stack (signature check, API key guard, captcha) and a one-line reason.
Add a test enumerating all public routes so the list is reviewable, not discovered.

### NEST.5 — API keys are header-only and constant-time → A07

The shape to look for: a key accepted from `req.query.api_key` — which lands in
access logs, proxy logs, and referrers — and compared with `Array.indexOf`. Read it from a
header, hash it at rest, compare with `crypto.timingSafeEqual` on equal-length
buffers. It is a credential, not a routing parameter.

### NEST.6 — No `||` default for a secret → A07, A04, A02

`process.env.JWT_SECRET || 'dev-secret'` tends to appear more than once in the
same codebase, alongside a database password and an encryption key with the same
shape. Validate configuration once, at boot, and fail hard. Note that
`new JwtService({ secret: process.env.X })` as a `useValue` evaluates at module
construction — an absent variable produces a service that signs with `undefined`
and boots cleanly. Add an `assertSafeProductionEnv()` called from `main.ts`:
refuse to start when throttling is off, a secret is missing, or the origin list
is empty in production.

### NEST.7 — Bind values; allowlist identifiers → A05

The two shapes that recur: `terms.map(s => \`col LIKE '%${s}%'\`).join(' OR ')`
fed into `andWhere`, and `orderBy(\`entity.${field}\`)` kept safe only by a
validator callers were expected to remember.

```ts
qb.andWhere('col LIKE :term', { term: `%${term}%` });          // value: bound
if (!ORDERABLE.has(field)) throw new BadRequestException();     // identifier: at the sink
```

Type the DTO field with `@IsIn([...])` **and** keep the allowlist check at the
query site. A defense that lives away from the sink rots.

### NEST.8 — Rate limit auth routes → A07

Two shapes: a login endpoint with no throttling at all, and an entire
`ThrottlerModule` block commented out. **A commented-out throttler is a finding,
not a TODO.**

Register `ThrottlerGuard` via `APP_GUARD` and add a strict `@Throttle` to login,
refresh, reset, and signup.

### NEST.9 — `helmet()` in every bootstrap → A02

Routinely absent. One line, no reason to skip it.

### NEST.10 — One exception filter, generic body → A10

The pair to look for: a global filter returning `(exception as Error).message` for
non-`HttpException` errors, handing raw driver text (tables, columns, constraints)
to the caller — and separately, per-controller
`catch (e) { res.status(400).json({ message: e.message }) }` blocks, each an
independent leak that also masks the real status code. One `ExceptionFilter`:
`HttpException` passes its public message through, everything else returns a
generic body plus a correlation id, with detail sent to the logger.

### NEST.11 — Log by allowlist → A09

The costly shape: an interceptor logging merged `req.body` + `req.query` on every
request **and** decoding the bearer token to log the whole claim set. A fixed
`SENSITIVE_KEYS` denylist cannot help — the claims arrive as one object and the
PII was never on the list. Pick named fields (`requestId`, `route`, `method`,
`status`, `durationMs`, `actorId`, `tenantId`); never bodies or decoded claims.

### NEST.12 — CORS and Swagger → A02

The near-universal shape: `origin: [process.env.CORS_ORIGIN, /\.example.com$/]`
with `credentials: true`. Two defects in one line — the array holds `undefined`
when the variable is unset, and the regex dot is unescaped, so `exampleXcom`
matches. Prefer an exact-host list; if a pattern is unavoidable, escape it and
anchor both ends. Alongside it: Swagger mounted unconditionally with only the
console hint gated by environment. Gate it on the deployment environment, or put
it behind basic auth.

### NEST.13 — Never disable database TLS verification → A02, A04

`trustServerCertificate: true` (mssql) and `ssl: { rejectUnauthorized: false }`
(pg) are the two forms, and both are common. Fix the trust store instead.

### NEST.14 — Impersonation names the identity → A01, A07, A09

Acting on behalf of another user tends to be a first-class feature here (a proxy
auth route, an on-behalf-of claim). Every authorization check must state whether
it evaluates the **acting** identity or the **effective** one, and every
impersonated action must be audited with both.

### NEST.15 — Supply chain → A03

`npm ci` from a committed `package-lock.json`; exact versions for anything
security-relevant; consider `--ignore-scripts` in CI. A new dependency's
`postinstall` runs with your credentials.

### NEST.16 — Webhooks and deserialization → A08

Verify the HMAC against the **raw** body before parsing — enable `rawBody: true`
and wire it ahead of the body parser, or the bytes that were signed are gone.
Compare with `crypto.timingSafeEqual`, bound the timestamp, and record the event
id for replay. Never revive arbitrary classes from request JSON.

### NEST.17 — Outbound requests take an allowlist → A01

`HttpService`/axios follows redirects by default and will happily resolve to a
private address, so a URL that arrives in a DTO reaches the metadata endpoint or
an internal port. `class-validator`'s `@IsUrl()` proves the string is a URL, not
that the destination is allowed.

```ts
const { address } = await dns.promises.lookup(new URL(url).hostname);
if (!isPublicUnicast(address) || !ALLOWED_HOSTS.has(host)) throw new BadRequestException();
await this.http.axiosRef.get(url, { maxRedirects: 0, timeout: 5000 });
```

Decide on the resolved address, not the hostname, and set `maxRedirects: 0` — a
`302` otherwise walks the client out of whatever the check established.

## Grep signals

```bash
rg -n 'new ValidationPipe\(\s*\)' src/
rg -n 'ClassSerializerInterceptor|@Exclude\(' src/            # expect hits; none is the finding
rg -n 'return .*(repo|repository)\.(save|create|findOne)\(' src/
rg -n '@Public\(\)' src/
rg -n 'process\.env\.[A-Z_]+\s*(\|\||\?\?)' src/
rg -n 'andWhere\(`|orderBy\(`|\.query\(`' src/
rg -n 'Throttler|@Throttle' src/ ; rg -n '^\s*//.*Throttler' src/
rg -n 'helmet|enableCors|SwaggerModule\.setup' src/
rg -n 'trustServerCertificate|rejectUnauthorized' src/
rg -n 'httpService|axiosRef|axios\.|fetch\(' src/          # then check each for an allowlist
```
