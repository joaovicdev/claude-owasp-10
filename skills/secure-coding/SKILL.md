---
name: secure-coding
description: Language-agnostic OWASP Top 10:2025 rules for writing and reviewing backend/API code, plus per-stack idiom files for NestJS, Laravel and Spring Boot. Use before writing or modifying any route handler, controller, guard/policy, query, auth flow, app config, or dependency — in any language. Also use when the user asks what security guidance applies, or asks to check code against OWASP.
---

# Secure coding — OWASP Top 10:2025

These files are the **single source of truth** for security rules in every project
where this skill is installed. Consumers — a review skill, a CI check, a human —
read them and cite their ids; they never restate the material. If guidance here
conflicts with a memory or a habit, this wins.

The core (`owasp/`) is **language-agnostic on purpose** — it is installed in
NestJS, Laravel, Spring Boot and other backends. It uses neutral pseudocode and
neutral vocabulary (route handler, ORM, filter, DI container). Framework idiom
lives only in `stacks/`.

## How to use this

1. Detect the stack once per session: `nest-cli.json` → `stacks/nestjs.md` ·
   `artisan`/`composer.json` → `stacks/laravel.md` · `pom.xml`/`build.gradle` →
   `stacks/spring-boot.md`. **No match → use the core alone.** That is the design,
   not a degraded mode.
2. Read the manifest rows below that match what you are about to touch. Read
   those files. Do not read all ten.
3. If `SECURITY-NOTES.md` exists at the project root, read it — it carries that
   project's known-open findings and accepted risks. If it does not exist and the
   project has findings worth tracking, `templates/SECURITY-NOTES.md` beside this
   file is the blank to copy there.

Every path in this file is relative to this skill's own directory, so the same
bytes work whether the skill was installed as a plugin, committed into a
project's `.claude/skills/`, or linked into the user's global skills directory.

## Manifest

| ID | File | Load when the change touches |
|---|---|---|
| A01:2025 | `owasp/A01-broken-access-control.md` | any handler taking an id/slug/key, guards, policies, roles, permissions, tenant scoping, object lookup by user-supplied identifier; **an outbound request whose URL/host/port comes from the caller (SSRF); CSRF settings on a cookie-session app** |
| A02:2025 | `owasp/A02-security-misconfiguration.md` | app bootstrap, CORS, security headers, TLS options, debug flags, API docs exposure, admin/actuator endpoints, default credentials |
| A03:2025 | `owasp/A03-software-supply-chain-failures.md` | `package*.json`, `composer.json`/`.lock`, `pom.xml`, `build.gradle`, `requirements.txt`, `go.mod`, Dockerfile, CI workflow, any new dependency or install script |
| A04:2025 | `owasp/A04-cryptographic-failures.md` | password storage, tokens, encryption, hashing, random values, TLS, key management, PII at rest or in transit |
| A05:2025 | `owasp/A05-injection.md` | any query, raw SQL, ORM escape hatch, shell/exec, file path from input, LDAP/XPath/NoSQL filters, deserialization of input; **template rendering and any unescaped output construct (XSS)** |
| A06:2025 | `owasp/A06-insecure-design.md` | a new feature's shape: workflows, state machines, limits, quotas, money, invitations, password reset, anything where the *design* carries the risk |
| A07:2025 | `owasp/A07-authentication-failures.md` | login, logout, registration, password reset, MFA, sessions, tokens, refresh, impersonation, API keys |
| A08:2025 | `owasp/A08-software-or-data-integrity-failures.md` | deserialization, auto-update, plugin loading, webhook receivers, signed payloads, CI/CD publish steps, cache/CDN keys |
| A09:2025 | `owasp/A09-security-logging-and-alerting-failures.md` | loggers, interceptors, audit trails, error reporting, anything that writes request data anywhere |
| A10:2025 | `owasp/A10-mishandling-of-exceptional-conditions.md` | exception filters, error handlers, `catch` blocks, fallback/default branches, timeouts, retries, partial failure |
| NEST | `stacks/nestjs.md` | any NestJS project |
| LAR | `stacks/laravel.md` | any Laravel project |
| SPR | `stacks/spring-boot.md` | any Spring Boot project |

## Contract for downstream skills

Three things are stable and may be relied on by `code-review` or any other
consumer:

- **IDs never get renumbered.** `A01:2025`…`A10:2025`, `NEST.*`, `LAR.*`, `SPR.*`.
  A future edition goes in `owasp/2029/` alongside; existing IDs stay valid so old
  findings remain resolvable.
- **`## Review questions`** in every file are the review contract. Each has a
  stable id (`A01.Q2`) and is answerable yes/no from a diff. Report findings as
  `A01.Q2 — <file>:<line> — <what is wrong>`.
- **`## Grep signals`** are a cheap pre-filter — run them before spending context
  on a full read.

Adding a review question to a file automatically extends every consumer. That is
the intent: extend the file, never fork the material.

The `api-secure-report` skill, shipped alongside this one, is the reference
consumer — it reads these files, iterates the review questions, and cites the
ids. Read it before writing another one.

## Honest limits

`stacks/nestjs.md` is grounded in four real codebases. `stacks/laravel.md` and
`stacks/spring-boot.md` are written from framework documentation and carry a
`Status: unverified` header — treat their specifics as a starting point and
tighten them the first time you work in such a project. `CONTRIBUTING.md` has the
recipe for adding a stack.
