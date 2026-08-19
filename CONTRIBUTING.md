# Adding or tightening a stack file

## The rule that matters

**Ground it, or mark it.** A stack file written from documentation is worth less
than one written from code that was actually wrong, and the difference must be
visible in the header:

```
**Status:** grounded in <n> production codebases (<orm>, <auth>, <authz>).
**Status: unverified against a real codebase.** Written from framework documentation.
```

Never quietly promote a file from unverified to grounded. Promote it when you
have read real projects and rewritten the items around what they got wrong.

## Recipe

1. **Survey before writing.** Read every project on this machine using the stack.
   For each, answer: how is input validated, where does authorization live, what
   is returned from handlers, which query APIs are used raw, what does the
   bootstrap configure (CORS, headers, docs, rate limiting), where do secrets come
   from, what does the error handler return, what does the logger record.
2. **Rank by observed frequency.** `NEST.1` is first because it was wrong in half
   the projects. Do not order by severity or by OWASP number — order by what the
   next diff is most likely to get wrong.
3. **Write each item in 4–8 lines**: the rule, the wrong form, the right form,
   and a `→ Ann` pointer to the core categories it serves. Budget roughly 10
   lines per item — `nestjs.md` runs ~185 for 17 items, and that ratio is the
   ceiling worth defending. Past it, an item belongs in the core, not here.
   (Core files run 95–155 lines. The spread is real: `A01` is the longest because
   it absorbed both SSRF and CSRF from the 2021 edition, and `A04` the shortest
   because its scope is narrow. Treat the shape as the guide, not the number —
   never trim substance to hit a rounder figure.)
4. **Use the project's own vocabulary.** If the codebase says "use-case", do not
   say "application service". The guidance has to sound like the code.
5. **Cite the pattern, never the evidence.** No `file:line`, no project names, no
   client identifiers — this repo is publishable. Concrete findings belong in that
   project's `SECURITY-NOTES.md`.
6. **Add `## Grep signals`** at the end, tuned to the language.
7. **Wire it up**: add a row to the manifest in `skills/secure-coding/SKILL.md`,
   add the detection file to the stack list in `skills/secure-coding/TRIGGER.md`
   and to Step 1 of `skills/api-secure-report/SKILL.md`, and add a row to the
   `## Idiom by stack` table of each core file the items serve.
8. **Run `./scripts/check-ids.sh`.** It fails on a manifest row pointing at a
   missing file, a `→ stacks/x.md (ID)` naming an id that does not exist, a gap
   in review-question numbering, a stack file with no `**Status:**` header, and a
   shipped file that hardcodes an install path. Green is the bar for a PR.

`skills/secure-coding/stacks/_TEMPLATE.md` is the blank, with this recipe's
wiring steps repeated in comments so they are in front of you while you write.

## Cross-reference discipline

Core files point at stack items as `→ stacks/<file>.md (NEST.3)`; stack items
point back as `→ A01`. Both directions are plain text, greppable, and survive
renaming. If an item has no core category, the core is missing something — add it
there first.

`A06` is the deliberate exception with no outgoing pointer, and says so in the
file: design flaws do not reduce to framework idiom. Do not add one to make the
grep tidy.

Core files carry seven sections. `## Applies when` is an optional eighth, used by
`A04` and `A06` — the two categories most often loaded when they do not actually
apply. Add it where the manifest row alone over-triggers, and nowhere else.

## Changing the core

The ten core files are agnostic. Anything that names a framework, a package, or a
language API belongs in `stacks/`. The test: if a sentence would confuse someone
reading it in a Go or Python project, it is in the wrong file.
