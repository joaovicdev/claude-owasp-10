<!-- secure-coding trigger v1.0.0 — github.com/joaovicdev/claude-owasp-10 -->

## Security baseline

These rules apply in every project, in every language. They are the minimum;
the full material is the `secure-coding` skill.

1. **Never** put a secret behind a default (`||`, `?:`, `getOrDefault`,
   `.env.example` value). Missing secret = fail at boot.
2. A handler that takes an id/slug from the caller scopes the lookup **by the
   caller** in the query itself — never fetch first and check after.
3. Never return a persistence entity from a handler. Return an explicit response
   shape; secrets and PII are opt-in, not opt-out.
4. Validate input against an allowlist and reject unknown fields. Never bind a raw
   request body straight into a model.
5. Never build a query, path, command, or template by concatenating caller input.
   Bind values; allowlist identifiers.
6. Never log request bodies, tokens, decoded claims, or credentials. Log by
   allowlist.
7. Errors returned to a caller are generic. Detail goes to the logger only.
8. A new dependency is a supply-chain decision: check maintenance, pin it in the
   lockfile, and note that install hooks execute code.

**Before writing or modifying** a route handler, controller, guard/policy/filter,
auth or session flow, query, app bootstrap/config, or dependency manifest: load
the **`secure-coding`** skill and read the manifest rows matching the change.
Detect the stack — `nest-cli.json` → NestJS, `artisan`/`composer.json` → Laravel,
`pom.xml`/`build.gradle` → Spring Boot; no match means the language-agnostic core
still applies. If `SECURITY-NOTES.md` exists at the project root, read it too.

Flag a violation even when the user did not ask about security, and even when the
surrounding code already violates it — say so once, concisely, and follow the
user's call.
