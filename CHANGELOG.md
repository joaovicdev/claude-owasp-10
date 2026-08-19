# Changelog

Versions follow [SemVer](https://semver.org/). For this repository that means:

- **Major** — a stable id is removed or its meaning changes, or an install layout
  breaks. The `IDs never get renumbered` promise makes this rare by design.
- **Minor** — new review questions, a new category or stack file, new tooling.
  Additive: a consumer written against the previous minor keeps working.
- **Patch** — wording, grep signals, fixes that change no id.

## [1.0.0]

First public release. The material itself is unchanged; everything here is about
making it installable by someone other than the author.

### Added

- **Two install routes from one source.** As a Claude Code plugin
  (`/plugin marketplace add joaovicdev/claude-owasp-10`), or vendored into a
  single repository with `./install.sh --project`, so a team gets the skill from
  a plain `git clone`.
- **`install.sh`** with `--project`, `--check` and a global mode. `--check`
  reports where the skill was found, which version, and whether the trigger is
  actually wired — the previous failure mode was silent.
- **`security-auditor` agent.** `/api-secure-report` used to ask `general-purpose`
  subagents not to edit anything. The auditor ships with no `Write` and no
  `Edit`, so read-only is enforced by the agent definition.
- **`TRIGGER.md`**, importable into a project's `CLAUDE.md` with a single `@`
  line, so the trigger tracks upstream instead of being pasted once and drifting.
- **`scripts/check-ids.sh`** — verifies that manifest rows resolve, cross
  references point at ids that exist, `report-format.md` cites only real review
  questions, review questions are contiguous, no shipped file hardcodes an
  install path, and the version agrees everywhere. Runs in CI.
- **`stacks/_TEMPLATE.md`** for contributing a stack the repository does not ship.

### Changed

- **Layout** is now `skills/secure-coding/` and `skills/api-secure-report/` as
  siblings. Previously `SKILL.md` sat at the repository root and
  `api-secure-report/` was nested *inside* the `secure-coding` skill.
- **No shipped file references an absolute install path.** `/api-secure-report`
  resolves the rules directory relative to its own location and passes that
  absolute path to its subagents. The hardcoded `~/.claude/skills/...` in the
  trigger and in three places in `api-secure-report/SKILL.md` used to resolve to
  nothing outside the author's machine — and the scan continued anyway.
- **`/api-secure-report` refuses to run without its rules** instead of producing
  a clean-looking report from a partial rule set.
- **`SECURITY-REPORT.md`** is offered to `.gitignore` rather than only warned
  about in the README. `install.sh --project` adds it up front.
- **README** is written for someone adopting the skill rather than for the author.

[1.0.0]: https://github.com/joaovicdev/claude-owasp-10/releases/tag/v1.0.0
