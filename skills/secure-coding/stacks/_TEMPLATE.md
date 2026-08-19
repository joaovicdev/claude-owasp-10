# <Framework> — stack idiom

**ID prefix:** `<PREFIX>` · **Status: unverified against a real codebase.** Written
from framework documentation and the core rules. Treat the specifics as a
starting point and tighten them on first contact with a real project.

<!--
Promote the header to the grounded form only after reading real code:

**ID prefix:** `<PREFIX>` · **Status:** grounded in <n> production codebases
(<orm>, <auth>, <authz>). Ordered by observed frequency — the earlier the item,
the more often it was actually wrong. Findings are stated as patterns; no project
is identified, per `CONTRIBUTING.md`.

Never promote quietly. `CONTRIBUTING.md` has the full recipe; the short version:
survey real projects, rank items by how often they were wrong (not by severity,
not by OWASP number), keep each item to 4–8 lines, and use the framework's own
vocabulary.
-->

Vocabulary assumed here: <the words this framework's developers actually use —
"use-case" vs "application service", "policy" vs "voter", "middleware" vs
"filter">. Rename freely — the items are about shape, not names.

## <PREFIX>.1 — <the rule, as an imperative sentence> → A0X

<One line on why this is item 1: what it gets wrong, how often.>

```
# wrong
<the shape as it actually appears in a diff>

# right
<the same thing, correct>
```

## <PREFIX>.2 — <next rule> → A0X

<As above. Aim for 10 lines per item including the code. Past that, the item is
probably a core concern and belongs in `owasp/`, not here.>

## Grep signals

```bash
# <what this finds, and what to read once it hits>
rg -n '<pattern tuned to this language>'
```

<!--
Wiring, once the file is written — all three are checked by scripts/check-ids.sh:

1. Add a manifest row to `skills/secure-coding/SKILL.md`.
2. Add the detection file to the stack list in `skills/secure-coding/TRIGGER.md`
   and to Step 1 of `skills/api-secure-report/SKILL.md`.
3. Add a row to the `## Idiom by stack` table of every core file your items
   serve, and a `→ stacks/<file>.md (<PREFIX>.N)` pointer from each of those
   files. Point back with `→ A0X` from each item here.

An item with no core category means the core is missing something. Add it there
first.
-->
