#!/usr/bin/env bash
#
# Integrity check for the secure-coding material. The repository promises three
# things — stable ids, resolvable cross-references, and install-location
# independence. This verifies all three instead of trusting them.
#
#   ./scripts/check-ids.sh

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE="$REPO/skills/secure-coding"
fails=0

red=$'\033[31m'; grn=$'\033[32m'; bold=$'\033[1m'; off=$'\033[0m'
fail() { printf '%s✘%s %s\n' "$red" "$off" "$*"; fails=$((fails + 1)); }
pass() { printf '%s✔%s %s\n' "$grn" "$off" "$*"; }

# 1 — every manifest row points at a file that exists ------------------------
printf '%s\n' "${bold}manifest rows resolve${off}"
missing=0
while read -r f; do
  [ -f "$CORE/$f" ] || { fail "manifest cites $f, which does not exist"; missing=1; }
done < <(grep -oE '`(owasp|stacks)/[A-Za-z0-9._-]+\.md`' "$CORE/SKILL.md" | tr -d '`' | sort -u)
[ "$missing" = 0 ] && pass "every file named in the manifest exists"

# 2 — every core category is in the manifest ---------------------------------
printf '%s\n' "${bold}no orphan category files${off}"
orphans=0
for f in "$CORE"/owasp/*.md "$CORE"/stacks/*.md; do
  rel="${f#"$CORE"/}"
  case "$rel" in stacks/_*) continue ;; esac   # templates are not categories
  grep -qF "\`$rel\`" "$CORE/SKILL.md" || { fail "$rel exists but no manifest row loads it"; orphans=1; }
done
[ "$orphans" = 0 ] && pass "every category file has a manifest row"

# 3 — cross-references resolve both ways -------------------------------------
printf '%s\n' "${bold}cross-references resolve${off}"
badref=0
while read -r ref; do
  file="${ref%% *}"; ids="${ref#* }"
  [ -f "$CORE/$file" ] || { fail "cross-reference to missing file: $file"; badref=1; continue; }
  for id in $(printf '%s' "$ids" | tr -d '()' | tr ',' ' '); do
    grep -qE "^#+ $id[[:space:]]|^- \*\*$id\*\*|\*\*$id\*\*" "$CORE/$file" \
      || { fail "$file is pointed at as $id, which is not defined there"; badref=1; }
  done
done < <(grep -hoE 'stacks/[a-z-]+\.md \([A-Z]+\.[0-9]+(, ?[A-Z]+\.[0-9]+)*\)' "$CORE"/owasp/*.md | sort -u)
[ "$badref" = 0 ] && pass "every → stacks/x.md (ID) points at an id that exists"

# 4 — every ref the report format enumerates is a real review question -------
printf '%s\n' "${bold}report-format refs exist as review questions${off}"
badq=0
while read -r q; do
  cat="${q%%.*}"
  f=$(ls "$CORE"/owasp/"$cat"-*.md 2>/dev/null | head -1)
  [ -n "$f" ] || { fail "report-format cites $q but there is no $cat file"; badq=1; continue; }
  grep -qF "**$q**" "$f" || { fail "report-format cites $q, which is not a review question in $(basename "$f")"; badq=1; }
done < <(grep -oE '\bA[0-9]{2}\.Q[0-9]+\b' "$REPO/skills/api-secure-report/references/report-format.md" | sort -u)
[ "$badq" = 0 ] && pass "every id enumerated in report-format.md is a real review question"

# 5 — review questions are numbered without gaps -----------------------------
printf '%s\n' "${bold}review questions are contiguous${off}"
gaps=0
for f in "$CORE"/owasp/*.md; do
  base=$(basename "$f" .md); cat="${base%%-*}"
  n=0
  while read -r i; do
    n=$((n + 1))
    [ "$i" = "$n" ] || { fail "$base jumps from Q$((n - 1)) to Q$i — ids must never be renumbered, but they must not skip either"; gaps=1; n=$i; }
  done < <(grep -oE "\*\*$cat\.Q[0-9]+\*\*" "$f" | sed -E 's/.*\.Q([0-9]+)\*\*/\1/')
  [ "$n" = 0 ] && { fail "$base has no review questions"; gaps=1; }
done
[ "$gaps" = 0 ] && pass "every category numbers its review questions 1..n"

# 6 — nothing in the shipped material hardcodes an install location ----------
printf '%s\n' "${bold}install-location independence${off}"
hits=$(grep -rn '~/\.claude' "$REPO/skills" "$REPO/agents" 2>/dev/null || true)
if [ -n "$hits" ]; then
  while read -r l; do fail "hardcoded install path: $l"; done <<< "$hits"
else
  pass "no shipped file references an absolute install path"
fi

# 7 — stack files declare their grounding ------------------------------------
printf '%s\n' "${bold}stack files declare grounding${off}"
ungrounded=0
for f in "$CORE"/stacks/*.md; do
  case "$(basename "$f")" in _*) continue ;; esac
  grep -qE '\*\*Status:?( )?(\*\*)?' "$f" \
    || { fail "$(basename "$f") has no **Status:** header — grounded or unverified must be visible"; ungrounded=1; }
done
[ "$ungrounded" = 0 ] && pass "every stack file states whether it is grounded"

# 8 — the version agrees everywhere it is written ---------------------------
printf '%s\n' "${bold}version agreement${off}"
v_plugin=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$REPO/.claude-plugin/plugin.json" | head -1)
v_market=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$REPO/.claude-plugin/marketplace.json" | head -1)
v_trig=$(sed -n 's/.*secure-coding trigger v\([0-9][^ ]*\).*/\1/p' "$CORE/TRIGGER.md" | head -1)
if [ "$v_plugin" = "$v_market" ] && [ "$v_plugin" = "$v_trig" ]; then
  pass "plugin.json, marketplace.json and TRIGGER.md all say $v_plugin"
else
  fail "version disagreement — plugin.json=$v_plugin marketplace.json=$v_market TRIGGER.md=$v_trig"
fi
grep -q "^## \[$v_plugin\]" "$REPO/CHANGELOG.md" 2>/dev/null \
  && pass "CHANGELOG.md has an entry for $v_plugin" \
  || fail "CHANGELOG.md has no ## [$v_plugin] entry"

printf '\n'
if [ "$fails" -gt 0 ]; then
  printf '%s%d check(s) failed%s\n' "$red" "$fails" "$off"
  exit 1
fi
printf '%sall checks passed%s\n' "$grn" "$off"
