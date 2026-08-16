---
name: api-secure-report
description: Full security inventory of every HTTP route in a backend project — each route marked clean or carrying findings, with the exploitation path and the mitigation, written in the user's language (pt-BR by default). Use when the user runs /api-secure-report, or asks for a security report, audit or inventory of the project's APIs.
---

# API security report

Produces one artifact: an inventory of **every** route in the project under
review, each marked clean or carrying findings, plus a findings section stating
what is wrong, how an attacker reaches it, and what fixes it.

This skill is a **consumer** of the `secure-coding` skill. It never restates
security material — it reads `~/.claude/skills/secure-coding/` and cites its
stable ids (`A01.Q2`, `NEST.3`). If a rule seems missing, the fix is to add a
review question there, not to invent one here.

## Arguments

`/api-secure-report [language] [path]` — both positional, both optional.

| Argument | Default | Meaning |
|---|---|---|
| `language` | `pt-BR` | Output language: `pt-BR`, `en`, `es`, … Anything that is not a recognized language tag is treated as `path`. |
| `path` | repository root | Restrict the scan to a subdirectory. Stated in the report header when set. |

## Step 1 — Load the rules

1. Read `~/.claude/skills/secure-coding/SKILL.md` and use **its** manifest and
   stack-detection table. Do not duplicate that table here.
2. Detect the stack once: `nest-cli.json` → `stacks/nestjs.md` ·
   `artisan`/`composer.json` → `stacks/laravel.md` · `pom.xml`/`build.gradle` →
   `stacks/spring-boot.md`. No match means the language-agnostic core applies
   alone — that is the design, not a degraded run.
3. If `SECURITY-NOTES.md` exists at the project root, read it. Anything listed
   there under **Accepted risks** is reported in its own section as accepted, not
   as a new finding. Anything under **Open** that is still present is reported
   with its existing id.

## Step 2 — Enumerate the routes

Follow `references/route-discovery.md` for the detected stack, or its
stack-agnostic fallback. Every recipe produces the same line shape:

```
METHOD | PATH | file:line | guard/middleware observed
```

This list is the spine of the report — the inventory section is built from it,
not from whatever the analysis happened to find. Group the lines by
module/controller; that grouping is also how the fan-out is partitioned.

If enumeration cannot cover something — routes registered dynamically, an
upstream gateway, a generated router — record it now and reproduce it verbatim
under **Limits** in the report. Never let an uncovered area read as a clean one.

## Step 3 — Fan out

Dispatch both axes together, as `general-purpose` subagents, all read-only —
state in every prompt that the agent must not edit, create or delete any file.

**Per-module (route-local).** One subagent per group of routes; split groups so
none exceeds ~15 routes, and cap this axis at 8 concurrent agents, running the
remainder in further batches. Each agent gets its slice of the route list and
evaluates the categories that live inside a handler:

| Category | File to read |
|---|---|
| A01:2025 | `owasp/A01-broken-access-control.md` |
| A05:2025 | `owasp/A05-injection.md` |
| A09:2025 | `owasp/A09-security-logging-and-alerting-failures.md` |
| A10:2025 | `owasp/A10-mishandling-of-exceptional-conditions.md` |
| stack | the detected `stacks/*.md`, if any |

**Global (cross-cutting).** One subagent per area that is a property of the
project rather than of a route:

| Agent | Reads | Looks at |
|---|---|---|
| config | `owasp/A02-security-misconfiguration.md` | bootstrap, CORS, security headers, TLS options, debug flags, API docs exposure, admin/actuator endpoints |
| deps | `owasp/A03-software-supply-chain-failures.md` | dependency manifests and lockfiles, Dockerfile, CI workflows, install scripts |
| auth | `owasp/A04-cryptographic-failures.md`, `owasp/A07-authentication-failures.md` | login, registration, reset, MFA, sessions, tokens, API keys, password storage, key management |
| design | `owasp/A06-insecure-design.md`, `owasp/A08-software-or-data-integrity-failures.md` | workflows, limits, quotas, money, invitations, webhook receivers, deserialization, signed payloads |

Every subagent prompt must say, explicitly:

- Read the listed files by absolute path under
  `~/.claude/skills/secure-coding/` before looking at any project code.
- Run that file's `## Grep signals` first as a pre-filter, then read only the
  code the signals hit. A grep signal is a lead, not proof — confirm by reading.
- Answer each `## Review question` of the assigned files against the assigned
  scope.
- Return **only** blocks in the contract from `references/report-format.md`,
  written in **English**. Translation happens once, at consolidation, so the
  vocabulary stays consistent across agents.
- Report a finding only with a `file:line` the agent actually read.

## Step 4 — Consolidate

- **Deduplicate** by `(route, ref)`. A cross-cutting finding — a bare
  `ValidationPipe`, a permissive CORS — appears once in the global section, never
  repeated on every route it happens to affect.
- **Drop** any finding without a verifiable `file:line`, and any `ref` that does
  not exist in the `secure-coding` files. A fabricated id breaks the contract
  that makes findings resolvable.
- **Order** the inventory by module, then by path. Order findings by severity,
  then by module. Number them so the report can be discussed by number.
- **Cross-check** against `SECURITY-NOTES.md`: an accepted risk moves to its own
  section, an already-open finding keeps its existing id.

## Step 5 — Emit

Print the report to the terminal **and** write it to `SECURITY-REPORT.md` at the
root of the project under review — not in this skill's repository. If that file
already exists, say so and that it is being overwritten.

Use the template in `references/report-format.md`. Translate the prose and the
labels into the requested language. Never translate: ids (`A01.Q2`, `NEST.3`),
file paths, route paths, HTTP methods, identifiers, or code.

Close with the fixed **Limits** section: what was not scanned, how many routes
were actually read, and that no finding is not proof of no vulnerability.
