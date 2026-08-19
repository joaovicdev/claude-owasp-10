# Route discovery

Enumerating routes is the one step that must be exhaustive — a route missed here
is a route the report silently claims does not exist. Run the recipe for the
detected stack, then run the **Cross-check** at the bottom regardless of stack.

Every recipe produces the same line:

```
METHOD | PATH | file:line | guard/middleware observed
```

`PATH` is the full path, with the class-level prefix already joined to the
method-level segment. The last column is not decoration — an absent guard, or a
guard that disagrees with its siblings, is the A01 finding itself.

## NestJS

```bash
# method decorators — one line per route
rg -n '@(Get|Post|Put|Patch|Delete|Head|Options|All)\(' --type ts
# class prefixes — join these to the lines above
rg -n '@Controller\(' --type ts
# what protects them (or does not)
rg -n '@(UseGuards|Public|CheckAbilities|Roles|SkipThrottle|Throttle)\(' --type ts
```

Join by file: the nearest preceding `@Controller` is the prefix for every method
decorator below it. A `@Public()` on a route, or a controller with no
`@UseGuards` in a project that has a global `APP_GUARD`, goes in the last column
verbatim — `NEST.4` turns on exactly that.

Also enumerate non-HTTP entry points and mark them as such: `@MessagePattern`,
`@EventPattern`, `@SubscribeMessage` (WebSocket gateways), and `@Cron`. They
carry the same access-control burden with none of the guard plumbing.

## Laravel

```bash
# the route files are the source of truth
rg -n 'Route::(get|post|put|patch|delete|any|match|resource|apiResource)' routes/
# middleware, per route and per group
rg -n '->middleware\(|Route::middleware\(' routes/
```

If the environment allows running it, `php artisan route:list --json` is
authoritative — it expands `resource`/`apiResource` into their real routes and
resolves group middleware, which grepping cannot do reliably. It is a read-only
command, but it boots the app: if it fails or the environment is not configured,
fall back to the greps and expand resource routes by hand, recording in
**Limits** that the expansion was manual.

## Spring Boot

```bash
# the mapping family
rg -n '@(RequestMapping|GetMapping|PostMapping|PutMapping|PatchMapping|DeleteMapping)\('
# authorization, at class and method level
rg -n '@(PreAuthorize|PostAuthorize|Secured|RolesAllowed|PermitAll)\('
# and the chain that decides what is public
rg -n 'SecurityFilterChain|authorizeHttpRequests|requestMatchers|permitAll'
```

A class-level `@RequestMapping` is the prefix. `SPR.2` is about matcher order —
record the matchers in the order they appear, because a broad `permitAll()`
placed before a specific rule is the finding.

## Stack-agnostic fallback

No stack detected is a normal run, not a degraded one. Try these in order and
stop at the first that yields a complete list:

```bash
# 1. a checked-in API description, if the project has one
rg --files -g '{openapi,swagger}.{yaml,yml,json}'
# 2. Express / Fastify / Koa routers
rg -n '\b(app|router|fastify|server)\.(get|post|put|patch|delete|all)\s*\('
# 3. Django
rg -n 'path\(|re_path\(|url\(' --glob '**/urls.py'
# 4. Rails
rg -n '^\s*(get|post|put|patch|delete|resources|resource)\b' config/routes.rb
# 5. Go (net/http, chi, gin, echo)
rg -n '\.(HandleFunc|Handle|GET|POST|PUT|PATCH|DELETE)\('
# 6. last resort — path-shaped string literals
rg -n '["'"'"'`]/[a-zA-Z0-9_:{}/-]*["'"'"'`]'
```

An OpenAPI file describes what the API *claims* to expose. Treat it as a
starting list, then reconcile against the code — a route present in code and
absent from the spec is worth its own note.

## Cross-check

Whatever produced the list, before moving on:

1. **Count.** Compare the route count against a raw count of the stack's route
   markers. A gap means the join or the grep missed something.
2. **Sample.** Open two or three handler files and confirm every route in them
   made it into the list.
3. **Declare.** Anything that cannot be enumerated statically — dynamically
   registered routes, a catch-all proxy, an upstream gateway, generated
   controllers — is written down now and reproduced under **Limits** in the
   report. An uncovered area must never read as a clean one.
