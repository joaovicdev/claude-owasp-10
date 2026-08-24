# claude-owasp-10

OWASP Top 10:2025 rules written to be read **by an agent, while it writes your
backend code** — not by a human, afterwards, in a report nobody opens.

Install it and Claude stops needing to be asked about security. It flags the
unscoped `findById` while writing the handler, when the fix costs nothing.

```
you    add a GET /orders/:id endpoint

claude … writes the handler, then:

       A01.Q2 — orders.controller.ts:31 — the lookup is by id alone. An
       authenticated user can read any order by guessing the id. The guard
       proved who the caller is, not what they may reach.

       Scoped it in the query predicate instead of checking after the fetch:
         where: { id, tenantId: caller.tenantId }
```

It ships two skills. **`secure-coding`** is the material — ten agnostic category
files plus per-stack idiom, loaded a row at a time by a manifest.
**`/api-secure-report`** is the reference consumer: it enumerates every route in
a project and reports each one clean or with findings.

## Install

Pick one. Both give you the same files.

### For yourself, in every project

```
/plugin marketplace add joaovicdev/claude-owasp-10
/plugin install secure-coding@claude-owasp-10
```

Then paste the trigger into your global `CLAUDE.md` — **this step is not
optional**, and the next section explains why:

```bash
curl -sL https://raw.githubusercontent.com/joaovicdev/claude-owasp-10/main/skills/secure-coding/TRIGGER.md \
  >> ~/.claude/CLAUDE.md
```

### For one repository, shared with your team

The skills get committed into the repo, so everyone gets them from a plain
`git clone` — no per-developer setup, no machine-specific paths.

```bash
git clone https://github.com/joaovicdev/claude-owasp-10
./claude-owasp-10/install.sh --project /path/to/your/repo
```

That copies the skills into `.claude/skills/`, drops the read-only auditor into
`.claude/agents/`, adds one `@import` line to the repo's `CLAUDE.md`, and puts
`SECURITY-REPORT.md` in `.gitignore`. Commit the result. Teammates get it on
their next pull.

Run `./install.sh --check /path/to/your/repo` any time to see what is installed,
which version, and whether the trigger is actually wired.

## Why the trigger is not optional

A skill only helps if something makes the agent open it, and *"add an endpoint"*
does not read as a security request. Without the trigger the material sits on
disk doing nothing, and you have no way to tell — which is the worst possible
outcome for a security tool.

`TRIGGER.md` does two jobs: it inlines the eight rules that must never require a
file read, and it states the hard rule that routes, guards, queries, auth, config
and dependency changes require loading the matching manifest rows first.

## Check that it worked

Two questions, in a project where you installed it. They fail separately.

1. *"What security rules apply to adding a route that takes an id?"*
   The answer must say the lookup is scoped by the caller **in the query**.
   Generic "validate your input" advice means the trigger never fired.

2. *"Load the secure-coding skill — which manifest row covers CORS?"*
   Must answer `A02`. Anything else means Claude cannot find the files.

## `/api-secure-report`

Run it inside a backend project. It enumerates **every** route, marks each one
clean or carrying findings, and reports each finding as *route → vulnerability →
how an attacker exploits it → mitigation*, citing the rule id it came from.

```bash
/api-secure-report                            # pt-BR, whole repository
/api-secure-report en                         # another language; ids, paths and code stay as-is
/api-secure-report pt-BR src/modules/orders   # scoped to a subdirectory
```

[`examples/SECURITY-REPORT.example.md`](examples/SECURITY-REPORT.example.md) is a
full run against a deliberately vulnerable app — read that before pointing it at
anything you care about.

The scan fans out across subagents, one per module plus one per cross-cutting
area, each running the `## Grep signals` of its assigned rule files before
reading any code. Route enumeration and the output shape live in
[`skills/api-secure-report/references/`](skills/api-secure-report/references/).

It prints to the terminal and writes `SECURITY-REPORT.md` to the root of the
project under review, overwriting the previous one.

## What this does not do

It matters for a tool you are about to point at your employer's code.

- **No network.** Nothing is uploaded, no API is called, no telemetry is
  collected. The material is plain Markdown your agent reads locally.
- **Nothing is modified.** `/api-secure-report` has no `Edit`. Its subagents run
  as the `security-auditor` agent, which ships with no `Write` and no `Edit`
  either — enforced by the agent definition, not by asking politely in a prompt.
  The only file written is the report.
- **The report is sensitive.** It quotes internal paths and spells out how to
  exploit them. `install.sh --project` gitignores it up front; the skill checks
  and offers if you installed another way. Decide deliberately before committing
  it.
- **A clean report is not proof.** Every run closes with a `Limits` section
  stating what was not scanned. Read it.

## Per-project findings

Nothing in `owasp/` or `stacks/` records the state of a particular repository —
that is what keeps the files portable. Copy
[`skills/secure-coding/templates/SECURITY-NOTES.md`](skills/secure-coding/templates/SECURITY-NOTES.md)
to a project root to track that project's open findings and accepted risks. The
skill reads it when present, and `/api-secure-report` reports anything listed
there as an accepted risk in its own section rather than as a new finding.

## Layout

```
.claude-plugin/       plugin.json, marketplace.json — this repo is its own marketplace
skills/
  secure-coding/      SKILL.md (loader + manifest), TRIGGER.md,
                      owasp/ (A01..A10, agnostic core), stacks/, templates/
  api-secure-report/  the reference consumer
agents/               security-auditor — read-only, dispatched by the report skill
install.sh            the non-plugin route: --project, --check
scripts/check-ids.sh  material integrity, run in CI
```

## Conventions worth preserving

- **IDs are stable and never renumbered.** A future edition goes in
  `owasp/2029/` alongside, so a finding citing `A05.Q2` stays resolvable.
- **`## Review questions`** are the contract a review skill iterates over. Adding
  one extends every consumer.
- **`## Grep signals`** are a pre-filter, not proof.
- **Nothing restates the material.** Consumers read these files and cite ids.
- **Nothing shipped hardcodes an install path** — that is what lets one set of
  bytes work as a plugin, in a project, or in your home directory.

`./scripts/check-ids.sh` enforces all of these that can be enforced mechanically.

## Honest limits

`stacks/nestjs.md` is grounded in production NestJS code. `stacks/laravel.md` and
`stacks/spring-boot.md` say `Status: unverified` in their headers and mean it —
they are written from framework documentation, and you should tighten them the
first time you work in such a project.

If your stack is not one of the three, the language-agnostic core applies alone.
That is the design, not a degraded mode. `stacks/_TEMPLATE.md` and
[`CONTRIBUTING.md`](CONTRIBUTING.md) have the recipe for adding one.

## Attribution

The category names, numbering, ordering and scope in `owasp/` follow the
[**OWASP Top 10:2025**](https://owasp.org/Top10/2025/). Every position change and
category rename asserted in the file headers was checked against the official
pages, which are the authority — where this repo and OWASP disagree, OWASP is
right and the disagreement is a bug worth filing.

The prose, review questions, pseudocode and grep signals are original work
written for this repository. They are not an OWASP publication.

**This project is not affiliated with, endorsed by, or maintained by the OWASP
Foundation.** "OWASP" is their trademark and appears here only to identify the
material this skill is built from.

## License

MIT — see [`LICENSE`](LICENSE).

Note that MIT does not carry the OWASP attribution above into forks. If you fork
this, keeping that section is a courtesy to the people who did the underlying
work, not a legal obligation.
