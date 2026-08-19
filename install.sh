#!/usr/bin/env bash
#
# claude-owasp-10 installer — github.com/joaovicdev/claude-owasp-10
#
#   ./install.sh                     install for your user, every project
#   ./install.sh --project [path]    install into one repository, for the team
#   ./install.sh --check   [path]    report what is installed, where, and whether it is stale
#
# Installing as a Claude Code plugin is the other route and needs no clone:
#   /plugin marketplace add joaovicdev/claude-owasp-10
#   /plugin install secure-coding@claude-owasp-10

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS=(secure-coding api-secure-report)
TRIGGER_LINE='@.claude/skills/secure-coding/TRIGGER.md'
STAMP='.claude/.secure-coding-version'

bold=$'\033[1m'; dim=$'\033[2m'; red=$'\033[31m'; grn=$'\033[32m'; ylw=$'\033[33m'; off=$'\033[0m'
say()  { printf '%s\n' "$*"; }
ok()   { printf '%s✔%s %s\n' "$grn" "$off" "$*"; }
warn() { printf '%s!%s %s\n' "$ylw" "$off" "$*"; }
die()  { printf '%s✘%s %s\n' "$red" "$off" "$*" >&2; exit 1; }

version() {
  # the single source of truth for the version, read without requiring jq
  sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    "$REPO/.claude-plugin/plugin.json" | head -1
}

[ -f "$REPO/.claude-plugin/plugin.json" ] || die "run this from a clone of claude-owasp-10 (no .claude-plugin/plugin.json next to the script)"
VERSION="$(version)"
[ -n "$VERSION" ] || die "could not read the version out of .claude-plugin/plugin.json"

# ---------------------------------------------------------------- global

install_global() {
  local dest="$HOME/.claude"
  mkdir -p "$dest/skills" "$dest/agents"

  for s in "${SKILLS[@]}"; do
    ln -sfn "$REPO/skills/$s" "$dest/skills/$s"
    ok "skills/$s → $dest/skills/$s"
  done
  ln -sfn "$REPO/agents/security-auditor.md" "$dest/agents/security-auditor.md"
  ok "agents/security-auditor.md → $dest/agents/security-auditor.md"

  say ""
  say "${bold}One step left, and it is not optional.${off}"
  say "Nothing makes an agent open a security skill on its own — \"add an endpoint\""
  say "does not read as a security request. Paste the trigger into your global CLAUDE.md:"
  say ""
  say "  ${dim}cat '$REPO/skills/secure-coding/TRIGGER.md' >> ~/.claude/CLAUDE.md${off}"
  say ""
  say "Then verify with:  ${dim}./install.sh --check${off}"
}

# --------------------------------------------------------------- project

install_project() {
  local root; root="$(cd "${1:-.}" && pwd)"
  [ -d "$root/.git" ] || warn "$root is not a git repository — the point of this mode is committing the result"

  local dest="$root/.claude"
  mkdir -p "$dest/skills" "$dest/agents"

  for s in "${SKILLS[@]}"; do
    if [ -e "$dest/skills/$s" ] && [ ! -e "$root/$STAMP" ]; then
      die "$dest/skills/$s exists and was not put there by this installer — move it aside first"
    fi
    rm -rf "$dest/skills/$s"
    cp -R "$REPO/skills/$s" "$dest/skills/$s"
    ok "skills/$s → .claude/skills/$s"
  done
  cp "$REPO/agents/security-auditor.md" "$dest/agents/security-auditor.md"
  ok "agents/security-auditor.md → .claude/agents/security-auditor.md"

  printf '%s\n' "$VERSION" > "$root/$STAMP"
  ok "version $VERSION stamped in $STAMP"

  # the trigger, as an import so it tracks upstream instead of drifting
  local md="$root/CLAUDE.md"
  if [ -f "$md" ] && grep -qF "$TRIGGER_LINE" "$md"; then
    ok "CLAUDE.md already imports the trigger"
  else
    [ -f "$md" ] && printf '\n' >> "$md"
    printf '%s\n' "$TRIGGER_LINE" >> "$md"
    ok "trigger import appended to CLAUDE.md"
  fi

  # a generated report spells out how to exploit this codebase
  local gi="$root/.gitignore"
  if [ -f "$gi" ] && grep -qxF 'SECURITY-REPORT.md' "$gi"; then
    ok ".gitignore already covers SECURITY-REPORT.md"
  else
    [ -f "$gi" ] && printf '\n' >> "$gi"
    printf '# quotes internal paths and describes how to exploit them\nSECURITY-REPORT.md\n' >> "$gi"
    ok "SECURITY-REPORT.md added to .gitignore"
  fi

  say ""
  say "${bold}Commit these so your team gets it from a plain git clone:${off}"
  say "  ${dim}git add .claude CLAUDE.md .gitignore && git commit -m 'chore: secure-coding skill $VERSION'${off}"
  say ""
  say "Verify with:  ${dim}$REPO/install.sh --check $root${off}"
}

# ----------------------------------------------------------------- check

check() {
  local root; root="$(cd "${1:-.}" && pwd)"
  local found=0

  say "${bold}upstream${off}    $VERSION  ($REPO)"
  say ""

  if [ -e "$root/.claude/skills/secure-coding/SKILL.md" ]; then
    found=1
    local have; have="$(cat "$root/$STAMP" 2>/dev/null || echo 'unstamped')"
    say "${bold}project${off}     $root/.claude/skills/"
    say "            version $have"
    [ "$have" = "$VERSION" ] || warn "        stale — re-run: ./install.sh --project $root"
    if [ -f "$root/CLAUDE.md" ] && grep -qF "$TRIGGER_LINE" "$root/CLAUDE.md"; then
      ok "        trigger imported in CLAUDE.md"
    else
      warn "        no trigger in CLAUDE.md — the skill will sit there unused"
    fi
    [ -f "$root/.claude/agents/security-auditor.md" ] \
      && ok "        security-auditor agent present" \
      || warn "        security-auditor agent missing — /api-secure-report loses enforced read-only"
  fi

  if [ -e "$HOME/.claude/skills/secure-coding/SKILL.md" ]; then
    found=1
    say "${bold}user${off}        $HOME/.claude/skills/"
    if grep -qsF 'secure-coding trigger' "$HOME/.claude/CLAUDE.md"; then
      ok "        trigger present in ~/.claude/CLAUDE.md"
    else
      warn "        no trigger in ~/.claude/CLAUDE.md — the skill will sit there unused"
    fi
  fi

  # a cache directory can outlive an uninstall — the registry is the authority
  if grep -qs '"secure-coding@' "$HOME/.claude/plugins/installed_plugins.json"; then
    found=1
    say "${bold}plugin${off}      installed via /plugin"
    ok "        agent and skills ship together"
  fi

  say ""
  if [ "$found" = 0 ]; then
    say "Not installed. Looked in:"
    say "  $root/.claude/skills/          (project)"
    say "  $HOME/.claude/skills/          (user)"
    say "  $HOME/.claude/plugins/cache/   (plugin)"
    exit 1
  fi

  say "${bold}Smoke test${off} — two questions, in the target project."
  say ""
  say "  1. ${dim}\"what security rules apply to adding a route that takes an id?\"${off}"
  say "     The answer must say the lookup is scoped by the caller ${bold}in the query${off}."
  say "     Generic \"validate your input\" advice means the trigger never fired."
  say ""
  say "  2. ${dim}\"load the secure-coding skill — which manifest row covers CORS?\"${off}"
  say "     Must answer A02. If it cannot find the skill, the files are not where"
  say "     Claude Code looks for them."
  say ""
  say "Question 1 exercises the trigger, question 2 the skill. They fail separately."
}

# ------------------------------------------------------------------ main

case "${1:-}" in
  ''|--global)  install_global ;;
  --project)    install_project "${2:-.}" ;;
  --check)      check "${2:-.}" ;;
  -h|--help)    sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' ;;
  *)            die "unknown option: $1  (try --help)" ;;
esac
