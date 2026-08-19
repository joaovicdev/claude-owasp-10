# Security notes — <project>

Per-project security state. The rules live in the `secure-coding` skill; this
file records only what is true **here**. Read alongside the skill.

> These entries rot. Treat them as hints and re-verify before relying on one.
> Any change that closes an `OPEN` item updates its line in the same commit.

**Stack:** <framework, ORM, auth> · **Last reviewed:** <YYYY-MM-DD>

## Open

| ID | Ref | Finding | Impact if it matters |
|---|---|---|---|
| O-1 | `A02.Q1` | <what is wrong, in one line> | <what an attacker gets> |

## Accepted risks

Each entry states the precondition that would force a revisit. An accepted risk
without a revisit condition is an ignored risk.

| ID | Ref | Risk | Why accepted | Revisit when |
|---|---|---|---|---|
| R-1 | `A08.Q1` | <risk> | <reason> | <the condition that invalidates the reason> |

## Verified clean

Worth recording so a reviewer does not re-derive it — with the date, because it
expires.

| Ref | Checked | Date |
|---|---|---|
| `A05.Q1` | <what was checked> | <YYYY-MM-DD> |

## Project-specific rules

Anything true here that the generic material cannot know — an in-house pattern to
copy, a boundary that is load-bearing, a file nobody should touch without
understanding why.
