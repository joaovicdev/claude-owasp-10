# claude-owasp-10

A Claude Code skill (`secure-coding`): OWASP Top 10:2025 rules written to be read
by an agent while it writes backend code, in any language.

The core (`owasp/`) is deliberately **language-agnostic** — neutral pseudocode,
neutral vocabulary, an "idiom by stack" table per file. Framework specifics live
in `stacks/`. That split is what lets the same material be installed in a NestJS
service, a Laravel app, and a Spring Boot API without editing anything.

```
SKILL.md          loader + manifest — which file to read for which change
owasp/            A01..A10, agnostic core
stacks/           nestjs.md, laravel.md, spring-boot.md
templates/        claude-md-snippet.md, the trigger (required — see step 2)
                  SECURITY-NOTES.md, copied into a project to track its findings
api-secure-report/  a second skill — /api-secure-report, see below
```

## Install

**Step 1 — clone and symlink.** Clone anywhere you keep your repositories. The
symlink name is what Claude Code uses as the skill name, so both names are fixed
regardless of where the clone lives. The repository ships two skills, so it takes
two symlinks.

```bash
git clone <this repo> claude-owasp-10
mkdir -p ~/.claude/skills
ln -sfn "$(pwd)/claude-owasp-10" ~/.claude/skills/secure-coding
ln -sfn "$(pwd)/claude-owasp-10/api-secure-report" ~/.claude/skills/api-secure-report
```

**Step 2 — install the trigger. This step is not optional.** The skill only helps
if something makes the agent read it, and "add an endpoint" does not read as a
security request. Paste the contents of
[`templates/claude-md-snippet.md`](templates/claude-md-snippet.md) into your
global `~/.claude/CLAUDE.md`, which is in context in every session. It inlines the
handful of rules that must never require a file read, and states the hard rule
that routes, guards, queries, auth, config, and dependency changes require loading
the matching manifest rows first.

Skip step 2 and the skill sits on disk doing nothing.

## `/api-secure-report`

The second skill is the reference consumer of the material above. Run it inside a
backend project and it enumerates **every** route, marks each one clean or
carrying findings, and reports each finding as *route → vulnerability → how an
attacker exploits it → mitigation*, citing the id it came from.

```bash
/api-secure-report            # pt-BR, whole repository
/api-secure-report en         # another language; ids, paths and code stay as-is
/api-secure-report pt-BR src/modules/orders   # scoped to a subdirectory
```

It prints to the terminal and writes `SECURITY-REPORT.md` to the root of the
project under review, overwriting the previous one. That file quotes internal
paths and describes how to exploit them — decide deliberately whether it belongs
in version control.

Route enumeration and the output shape live in
[`api-secure-report/references/`](api-secure-report/references/). The scan itself
fans out across subagents, one per module plus one per cross-cutting area, each
running the `## Grep signals` of its assigned files before reading any code.

## Per-project findings

Nothing in `owasp/` or `stacks/` records the state of a particular repository —
that is what keeps the files portable. Copy `templates/SECURITY-NOTES.md` to a
project root to track that project's open findings and accepted risks. The skill
reads it when present.

## Conventions worth preserving

- **IDs are stable and never renumbered.** A future edition goes in `owasp/2029/`
  alongside, so a finding citing `A05.Q2` stays resolvable.
- **`## Review questions`** are the contract a review skill iterates over. Adding
  one extends every consumer.
- **`## Grep signals`** are a pre-filter, not proof.
- Nothing here restates the material. Consumers read these files.

`stacks/nestjs.md` is grounded in production NestJS code, stated as patterns with
no project identified. `stacks/laravel.md` and `stacks/spring-boot.md` say
`Status: unverified` in their headers and mean it. `CONTRIBUTING.md` has the
recipe for adding a stack.

## Attribution

The category names, numbering, ordering and scope in `owasp/` follow the
[**OWASP Top 10:2025**](https://owasp.org/Top10/2025/). Every position change and
category rename asserted in the file headers was checked against the official
pages, which are the authority — where this repo and OWASP disagree, OWASP is
right and the disagreement is a bug worth filing.

The prose, review questions, pseudocode and grep signals are original work written
for this repository. They are not an OWASP publication.

**This project is not affiliated with, endorsed by, or maintained by the OWASP
Foundation.** "OWASP" is their trademark and appears here only to identify the
material this skill is built from.

## Licence

MIT — see [`LICENSE`](LICENSE).

Note that MIT does not carry the OWASP attribution above into forks. If you fork
this, keeping that section is a courtesy to the people who did the underlying
work, not a legal obligation.
