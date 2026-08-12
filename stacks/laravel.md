# Laravel — stack idiom

**ID prefix:** `LAR` · **Status: unverified against a real codebase.** Written
from framework documentation and the core rules, not from production Laravel code
— unlike `nestjs.md`. Treat the specifics as a starting point and tighten them on
first contact with a real project. `LAR.4` is the exception: it is grounded in a
published advisory, CVE-2025-27515.

### LAR.1 — Mass assignment → A01

`$guarded = []` (or a model with neither `$fillable` nor `$guarded` reviewed)
plus `Model::create($request->all())` lets the request set any column —
`role`, `tenant_id`, `is_admin`, `user_id`.

```php
// wrong                                    // right
User::create($request->all());              User::create($request->validated());
protected $guarded = [];                    protected $fillable = ['name', 'email'];
```

Use `$fillable` as an allowlist. `$guarded` is a denylist and fails the same way
every denylist does — it misses the column added next sprint.

### LAR.2 — Validate with a FormRequest, consume `validated()` → A05, A01

`$request->all()` and `$request->input()` return unvalidated data even when a
validator ran. Only `validated()` returns the allowlisted set. A FormRequest also
gives one place for `authorize()`, which is where `LAR.3` belongs.

### LAR.3 — Policies plus a tenant scope → A01

Two distinct failures: no `authorize()`/`Gate` check at all, and a check that
proves the caller may act on the *type* but not on the *instance*.

```php
public function show(Order $order) {
    $this->authorize('view', $order);        // policy receives the instance
    return new OrderResource($order);        // Resource, never the model
}
```

Route-model binding resolves `{order}` before the policy runs, so the record is
already loaded — the policy must compare ownership/tenant. For multi-tenant
apps add a global scope on the model so an unscoped `findOrFail` cannot resolve
another tenant's row.

### LAR.4 — File upload validation → A05, A08

CVE-2025-27515 (CWE-155, fixed in **11.44.1** and **12.1.1**): a crafted request
could bypass the rules on a file or image field validated through a **wildcard**
(`files.*`). The upload then lands with an extension the rule was meant to reject
— a polyglot file that is a valid image and a valid script.

Read the version floor first. Below it, `files.*` is the vulnerable pattern, not
the mitigation, and no amount of rule-writing closes it. Above it, wildcard
validation is still not a defense on its own: check the MIME type server-side
rather than trusting the client, store outside the web root under a generated
name, and never let the uploaded extension decide how the file is served.

### LAR.5 — Raw query APIs → A05

The escape hatches: `DB::raw`, `whereRaw`, `orderByRaw`, `selectRaw`,
`havingRaw`, and `DB::statement`. Bind values as the second argument; allowlist
identifiers before they reach `orderByRaw`.

```php
DB::table('orders')->whereRaw('total > ?', [$request->min]);   // bound
if (!in_array($sort, ['created_at','total'], true)) abort(400); // identifier
```

### LAR.6 — Signed payloads and `unserialize()` → A08

Never call `unserialize()` on caller input — PHP object injection turns it into a
gadget chain. Use `json_decode` into a declared shape.

For webhooks, compute the HMAC over the raw body (`$request->getContent()`)
before parsing, compare with `hash_equals`, bound the timestamp, and record the
event id. Laravel's signed URLs (`URL::temporarySignedRoute`) are the right tool
for self-issued links — they still need an expiry.

### LAR.7 — Debug, environment and error output → A02, A10

`APP_DEBUG=true` in production turns every exception into a stack trace with
environment variables rendered in the page — the single highest-impact Laravel
misconfiguration. Also: `APP_KEY` must be set (encryption and signed cookies
depend on it), `.env` must not be served, and `Handler::render` must not return
`$e->getMessage()` for non-HTTP exceptions.

Run `config:cache` in production, and make sure no `config()` default silently
substitutes for a missing secret.

### LAR.8 — Authentication → A07

Apply `throttle` to login, registration, password reset, and any route accepting
a credential. Use `Hash::make`/`Hash::check` (never a plain digest), invalidate
the session on logout and password change, and keep responses identical for
unknown-account and wrong-password. Sanctum/Passport tokens need explicit
abilities and an expiry.

### LAR.9 — Logging → A09

`Log::info($request->all())` is the shape to avoid. Log named fields. Watch
`APP_DEBUG` and query logging (`DB::listen`) leaking bound parameters, and
configure the scrubber on any error-reporting SDK.

### LAR.10 — Supply chain → A03

`composer install` from a committed `composer.lock` in CI, never `composer update`.
Run `composer audit`. Packages can register service providers automatically —
installing one is granting it a boot hook.

### LAR.11 — CSRF and Blade escaping → A01, A05

Laravel is the stack in this set most likely to be serving cookie sessions and
server-rendered HTML, so both browser-facing defenses apply.

`VerifyCsrfToken` is on by default; the finding is its `$except` array, which
grows one webhook at a time until a state-changing route is in it. Treat every
entry as an allowlist item needing a reason — a webhook belongs there only
because it verifies an HMAC instead (`LAR.6`).

Blade escapes with `{{ }}`. `{!! !!}` is the sink: it is correct only over output
of a vetted HTML sanitizer, never over `$request` data or a database column that
merely happens to hold markup today.

### LAR.12 — Outbound requests take an allowlist → A01

`Http::get($request->url)` follows redirects and resolves private addresses. Check
the resolved address against an allowlist, and disable redirect following:

```php
Http::withOptions(['allow_redirects' => false])->timeout(5)->get($url);
```

## Grep signals

```bash
rg -n '\$guarded\s*=\s*\[\s*\]|\$request->all\(\)|->input\(' app/
rg -n 'DB::raw|whereRaw|orderByRaw|selectRaw|havingRaw|DB::statement' app/
rg -n 'unserialize\(|eval\(|extract\(' app/
rg -n 'authorize\(|Gate::|can\(' app/          # expect hits; absence in a controller is the finding
rg -n 'APP_DEBUG|APP_KEY|APP_ENV' .env.example config/
rg -n 'throttle' routes/
rg -n '\{!!|Blade::withoutDoubleEncoding' resources/
rg -n '\$except' app/Http/Middleware/          # CSRF exemptions; each needs a reason
rg -n 'Http::(get|post|put|withOptions)' app/
```
