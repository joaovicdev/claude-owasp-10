# A05:2025 — Injection

**ID:** `A05:2025` · **2021:** A03:2021 (#3 → #5) · **Applies to:** any

## Rule

1. **Values** are always bound as parameters. Never concatenate, interpolate, or
   format caller input into a query, command, path, template, or filter string.
2. **Identifiers** (column, table, sort direction, index, alias) cannot be bound.
   They go through an allowlist at the point of use — and the allowlist is the
   authority, not a validator someone remembered to call upstream.
3. Escaping is a fallback, not a strategy. If the API offers a parameterized form,
   using the raw form is a finding.
4. Input validation is a second layer, never the first. A validated string is
   still a value to be bound.
5. Output encoding is chosen by the **destination context** — HTML body, attribute,
   URL, JavaScript, CSS — never by the input. A template engine's automatic
   escaping is the safe path; every construct that switches it off is a sink.

## How it shows up in a backend API

- The parameterized path is used everywhere except the one "dynamic" bit — a
  `LIKE` built from a list, an `IN` clause assembled by joining, an `ORDER BY`
  taking a field name. That exception is the vulnerability.
- Query-builder APIs are the usual trap: they bind `where(x = ?, val)` but let a
  raw string through in `whereRaw`, `havingRaw`, `orderBy`, or a raw fragment.
  The safe and the unsafe call sit next to each other in the same class.
- A defense that lives *away from* the sink rots. If `orderBy(field)` is only
  safe because a validator is called at every call site, the next call site will
  forget. Put the allowlist where the string meets the query.
- Input that is not caller-typed *today* still gets interpolated the same way —
  role metadata, config, an enum. One refactor later it is a request parameter,
  and the concatenation is already there.
- Injection is not only SQL: shell/exec arguments, file paths, template engines
  with a user-supplied template, NoSQL filter documents, LDAP filters, XPath,
  header values (CRLF), and log lines (forging entries) are the same defect.
- Pointed at the browser, the same defect is XSS — by CVE count the largest CWE in
  this category, ahead of SQL injection. It arrives through the one field rendered
  unescaped because it "already contains HTML from the editor"; through an `href`
  or `src` built from input, where `javascript:` is a perfectly valid URL; and
  through data interpolated into a `<script>` block, where HTML escaping is simply
  the wrong encoder for the context.

## Anti-pattern

```
handler GET /tickets:
    field = request.query.orderField                     # typed as free string
    rows  = db.raw("SELECT * FROM tickets"
                 + " WHERE title LIKE '%" + request.query.q + "%'"
                 + " ORDER BY " + field)                 # value AND identifier
    run_shell("convert " + request.body.filename + " out.png")
```

## Correct

```
ORDERABLE = {"created_at", "title", "status"}            # allowlist at the sink

handler GET /tickets:
    q     = request.query.q
    field = request.query.orderField
    if field not in ORDERABLE: return 400
    rows  = db.query("SELECT id, title, status FROM tickets"          # named columns, not *
                   + " WHERE title LIKE ? ESCAPE '\\' ORDER BY " + field,
                     params: ["%" + escape_like(q) + "%"])  # value bound; identifier allowlisted
    run_process(["convert", safe_path(request.body.filename), "out.png"])
```

Three details carry most of the weight: the wildcards belong to the **bound
parameter**, not to the SQL string; `%` and `_` *inside* the search term are
escaped, or the caller widens the match at will and turns a search into a full
table read; and the process call takes an **argument vector**, never a command
string handed to a shell.

## Idiom by stack

| Stack | Parameterized form | The escape hatch to audit |
|---|---|---|
| NestJS / TypeORM | `where({ x })`, `:param` bindings | `query()`, `.where("raw " + x)`, `orderBy(\`t.${f}\`)` |
| Laravel / Eloquent | `where('x', $v)`, bindings array | `DB::raw`, `whereRaw`, `orderByRaw`, `selectRaw` |
| Spring Boot / JPA | `?1` / `:named` in `@Query`, Criteria API | string-concatenated `@Query`, `EntityManager.createNativeQuery` |
| Django | ORM filters, `params=` | `.raw()`, `.extra()`, `RawSQL` |

The same table for templates: Blade escapes with `{{ }}` and stops at `{!! !!}`;
Thymeleaf escapes with `th:text` and stops at `th:utext`; JSX escapes everything
except `dangerouslySetInnerHTML`. Where rich text genuinely must render as markup,
run it through a vetted allowlist-based sanitizer before storing it — the
unescaped render is then the one place that sanitizer is load-bearing, and it
should be obvious in review which line that is.

→ `stacks/nestjs.md (NEST.7)` · `stacks/laravel.md (LAR.5, LAR.11)` ·
`stacks/spring-boot.md (SPR.4, SPR.12)`

## Review questions

- **A05.Q1** — Is every caller-supplied **value** bound as a parameter rather
  than interpolated into the query string?
- **A05.Q2** — Is every caller-supplied **identifier** (sort field, column,
  direction, table) checked against an allowlist *at the query site*, not only
  in an upstream validator?
- **A05.Q3** — Does the DTO/request schema constrain sort and filter fields to a
  closed set, or is it typed as a free string?
- **A05.Q4** — Does any new raw/escape-hatch query API appear, and is the raw
  form necessary?
- **A05.Q5** — Are `LIKE` wildcards part of the bound value rather than the SQL?
- **A05.Q6** — Does any process execution build a command string instead of
  passing an argument vector? Is a shell involved at all?
- **A05.Q7** — Does caller input reach a filesystem path, a template body, a
  redirect target, or a response header without normalization and an allowlist?
- **A05.Q8** — Is interpolated input that is "not user-controlled today"
  documented as such, and would a refactor silently make it user-controlled?
- **A05.Q9** — Does any template render caller-supplied data through an unescaped
  construct, and is the encoder correct for the destination context (HTML body,
  attribute, URL, script)?

## Grep signals

```bash
# concatenation or interpolation next to query verbs
rg -n '(SELECT|INSERT|UPDATE|DELETE|WHERE|ORDER BY|LIKE).*(\+|\$\{|%s|\.format\(|f")'
# raw escape hatches, any stack
rg -n '\b(raw|Raw|createNativeQuery|whereRaw|orderByRaw|selectRaw|DB::raw|\$queryRaw|\.extra\()\b'
# dynamic ordering
rg -n 'orderBy\s*\(\s*[`"'"'"']?\$?\{?\s*(\w+\.)?(order|sort)'
# command execution
rg -n '\b(exec|execSync|system|popen|shell_exec|Runtime\.getRuntime|ProcessBuilder|child_process)\b'
# path from input
rg -n '(path|Path|File)\.(join|resolve)\s*\(.*\b(req|request|params|query|body|input)\b'
# unescaped template output
rg -n '\{\{\{|\{!!|th:utext|dangerouslySetInnerHTML|v-html|innerHTML\s*=|\|\s*safe\b'
```
