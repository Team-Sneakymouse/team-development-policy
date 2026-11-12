#!/usr/bin/env bash
# Runs installer/sync-stubs.sh, and installer/sync-stubs.ps1 when PowerShell (pwsh or Windows
# PowerShell) is available, over the same fixture projects in a temporary folder, and checks
# each against the same expected files and warnings. Touches nothing outside that folder.
#
# Usage: installer/tests/test-sync-stubs.sh
# Needs bash 3.2+ and perl 5, like sync-stubs.sh.

set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
installer=$(cd "$here/.." && pwd)
examples=$(cd "$installer/../adapters/examples" && pwd)
retired="$installer/retired"
tmp=$(mktemp -d 2>/dev/null || mktemp -d -t sync-stubs-test)
trap 'rm -rf "$tmp"' EXIT

failures=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }

trimmed() { perl -0777 -pe 's/\A\xEF\xBB\xBF//; s/\r\n/\n/g; s/\A[ \t\r\n\f\x0B]+//; s/[ \t\r\n\f\x0B]+\z//' "$1"; }
block=$(perl -0777 -ne 's/\r\n/\n/g; /```markdown\n(.*?)\n```/s or die; my $b = $1; $b =~ s/\A\s+//; $b =~ s/\s+\z//; print $b' "$examples/bootstrap.md")
claude=$(trimmed "$examples/claude-code.md")
copilot=$(trimmed "$examples/copilot-instructions.md")
cursor=$(trimmed "$examples/cursor-rule.mdc")
old_block=$(trimmed "$retired/bootstrap/1.md")
legacy=$(trimmed "$retired/legacy-bootstrap/1.md")
legacy_1=${legacy%%$'\n\n'*}
legacy_2=${legacy#*$'\n\n'}
begin='<!-- BEGIN TEAM-POLICY MANAGED BOOTSTRAP -->'

fx="$tmp/fixtures"     # input projects
ex="$tmp/expected"     # the same projects after --apply
warns="$tmp/warns"     # lines of: project<TAB>file<TAB>warning text
: > "$warns"

# project NAME: an enrolled project with the canonical CLAUDE.md, in both trees.
project() {
    mkdir -p "$fx/$1/.team-policy" "$ex/$1/.team-policy"
    printf '{}\n' > "$fx/$1/.team-policy/pointer.json"
    printf '{}\n' > "$ex/$1/.team-policy/pointer.json"
    printf '%s\n' "$claude" > "$fx/$1/CLAUDE.md"
    printf '%s\n' "$claude" > "$ex/$1/CLAUDE.md"
}
# given NAME FILE (content on stdin): input file; also the expected file until `want` overrides it.
given() { mkdir -p "$(dirname "$fx/$1/$2")" "$(dirname "$ex/$1/$2")"; cat > "$fx/$1/$2"; cp "$fx/$1/$2" "$ex/$1/$2"; }
# want NAME FILE (content on stdin): expected file after --apply.
want() { mkdir -p "$(dirname "$ex/$1/$2")"; cat > "$ex/$1/$2"; }
# warns NAME FILE TEXT: the run must print this warning for that file.
warns() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$warns"; }
crlf() { perl -pe 's/\n/\r\n/'; }

# --- fixtures -------------------------------------------------------------------------------

project up-to-date
printf '# P\n\n%s\n' "$block" | given up-to-date AGENTS.md

project retired-block
printf '# P\n\n%s\n\nLocal facts.\n' "$old_block" | given retired-block AGENTS.md
printf '# P\n\n%s\n\nLocal facts.\n' "$block" | want retired-block AGENTS.md

# Finding 5: a locally edited managed block is not overwritten.
project edited-block
printf '# P\n\n%s\n' "${old_block/relative to this project root/relative to this project root (MagicSpells\/)}" | given edited-block AGENTS.md
warns edited-block AGENTS.md 'managed block edited locally; left alone, merge by hand'

project legacy
printf '# P\n\n%s\n\nLocal facts.\n' "$legacy" | given legacy AGENTS.md
printf '# P\n\n%s\n\nLocal facts.\n' "$block" | want legacy AGENTS.md

# Finding 7: text between the two legacy paragraphs is never deleted.
project legacy-split
printf '# P\n\n%s\n\nKEEP ME\n\n%s\n' "$legacy_1" "$legacy_2" | given legacy-split AGENTS.md
warns legacy-split AGENTS.md 'legacy bootstrap edited locally; left alone, merge by hand'

# Legacy paragraphs that were edited are not left behind next to a new block.
project legacy-reworded
printf '# P\n\n%s\n\nLocal facts.\n' "${legacy/when safe/when safe (never on Fridays)}" | given legacy-reworded AGENTS.md
warns legacy-reworded AGENTS.md 'legacy bootstrap edited locally; left alone, merge by hand'

project legacy-other-case
printf '# P\n\n%s\n' "${legacy/Resolve shared policy/First, resolve shared policy}" | given legacy-other-case AGENTS.md
warns legacy-other-case AGENTS.md 'legacy bootstrap edited locally; left alone, merge by hand'

project legacy-second-only
printf '# P\n\n%s\n' "$legacy_2" | given legacy-second-only AGENTS.md
warns legacy-second-only AGENTS.md 'legacy bootstrap edited locally; left alone, merge by hand'

project legacy-and-reworded
printf '# P\n\n%s\n\n%s\n' "$legacy" "${legacy/when safe/when it is safe}" | given legacy-and-reworded AGENTS.md
warns legacy-and-reworded AGENTS.md 'legacy bootstrap edited locally; left alone, merge by hand'

project block-and-reworded-legacy
printf '# P\n\n%s\n\n%s\n' "$block" "${legacy/when safe/when it is safe}" | given block-and-reworded-legacy AGENTS.md
warns block-and-reworded-legacy AGENTS.md 'managed block and legacy bootstrap both present; left alone'

project legacy-crlf
printf '# P\n\n%s\n\nLocal facts.\n' "$legacy" | crlf | given legacy-crlf AGENTS.md
printf '# P\n\n%s\n\nLocal facts.\n' "$block" | crlf | want legacy-crlf AGENTS.md

project legacy-bom
printf '\357\273\277# P\n\n%s\n' "$legacy" | given legacy-bom AGENTS.md
printf '\357\273\277# P\n\n%s\n' "$block" | want legacy-bom AGENTS.md

# Finding 4: short files with real instructions are not treated as pointer stubs.
project custom-claude-import
printf '# P\n\n%s\n' "$block" | given custom-claude-import AGENTS.md
printf '@AGENTS.md\n\nAlways run ./gradlew check before committing.\n' | given custom-claude-import CLAUDE.md
warns custom-claude-import CLAUDE.md 'custom file left alone'

project custom-claude-heading
printf '# P\n\n%s\n' "$block" | given custom-claude-heading AGENTS.md
printf '# Claude Code\n\nBuild with ./gradlew shadowJar, never ./gradlew build.\n' | given custom-claude-heading CLAUDE.md
warns custom-claude-heading CLAUDE.md 'custom file left alone'

project custom-cursor
printf '# P\n\n%s\n' "$block" | given custom-cursor AGENTS.md
printf -- '---\ndescription: Team development policy — follow AGENTS.md\nalwaysApply: true\n---\n\nFollow [AGENTS.md](../../AGENTS.md). Workspace layout lives in `Workspace/.cursor/rules/workspace-overview.mdc`.\n' | given custom-cursor .cursor/rules/team-policy.mdc
warns custom-cursor .cursor/rules/team-policy.mdc 'custom file left alone'

project retired-stubs
printf '# P\n\n%s\n' "$block" | given retired-stubs AGENTS.md
given retired-stubs CLAUDE.md < "$retired/claude/1.md"
given retired-stubs .github/copilot-instructions.md < "$retired/copilot/1.md"
crlf < "$retired/cursor/1.mdc" | given retired-stubs .cursor/rules/team-policy.mdc
printf '%s\n' "$claude" | want retired-stubs CLAUDE.md
printf '%s\n' "$copilot" | want retired-stubs .github/copilot-instructions.md
printf '%s\n' "$cursor" | crlf | want retired-stubs .cursor/rules/team-policy.mdc

# Finding 8: no second H1 when the heading is not on the first line.
project heading-after-comment
printf '<!-- generated -->\n# P\nBody.\n' | given heading-after-comment AGENTS.md
printf '<!-- generated -->\n# P\n\n%s\n\nBody.\n' "$block" | want heading-after-comment AGENTS.md

project heading-after-blank
printf '\n# P\n\nBody.\n' | given heading-after-blank AGENTS.md
printf '\n# P\n\n%s\n\nBody.\n' "$block" | want heading-after-blank AGENTS.md

project heading-no-newline
printf '# P' | given heading-no-newline AGENTS.md
printf '# P\n\n%s\n' "$block" | want heading-no-newline AGENTS.md

# The block is never put above front matter.
project front-matter
printf -- '---\ntitle: P\n---\n\n# P\n\nBody.\n' | given front-matter AGENTS.md
warns front-matter AGENTS.md 'front matter and no bootstrap block; left alone, add the block by hand'

project front-matter-with-block
printf -- '---\ntitle: P\n---\n\n# P\n\n%s\n' "$old_block" | given front-matter-with-block AGENTS.md
printf -- '---\ntitle: P\n---\n\n# P\n\n%s\n' "$block" | want front-matter-with-block AGENTS.md

project heading-later
printf '## Notes\n\nText.\n\n# P\n' | given heading-later AGENTS.md
printf '%s\n\n## Notes\n\nText.\n\n# P\n' "$block" | want heading-later AGENTS.md

project no-heading
printf 'Some text.\n' | given no-heading AGENTS.md
printf '# Agent instructions\n\n%s\n\nSome text.\n' "$block" | want no-heading AGENTS.md

project no-agents
rm "$fx/no-agents/CLAUDE.md"
printf '# Agent instructions\n\n%s\n' "$block" | want no-agents AGENTS.md

# Finding 9: malformed or mixed bootstrap markers are refused, not patched around.
project missing-end
printf '# P\n\n%s\nOld text.\n' "$begin" | given missing-end AGENTS.md
warns missing-end AGENTS.md 'bootstrap markers missing, unpaired or repeated; left alone'

project two-blocks
printf '# P\n\n%s\n\n%s\n' "$block" "$block" | given two-blocks AGENTS.md
warns two-blocks AGENTS.md 'bootstrap markers missing, unpaired or repeated; left alone'

project block-and-legacy
printf '# P\n\n%s\n\n%s\n' "$old_block" "$legacy" | given block-and-legacy AGENTS.md
warns block-and-legacy AGENTS.md 'managed block and legacy bootstrap both present; left alone'

project legacy-twice
printf '# P\n\n%s\n\n%s\n' "$legacy" "$legacy" | given legacy-twice AGENTS.md
warns legacy-twice AGENTS.md 'legacy bootstrap present more than once; left alone'

# Finding 6: matching is case-sensitive, so `@agents.md` is not the `@AGENTS.md` stub.
project lowercase-stub
printf '# P\n\n%s\n' "$block" | given lowercase-stub AGENTS.md
printf '@agents.md\n' | given lowercase-stub CLAUDE.md
warns lowercase-stub CLAUDE.md 'custom file left alone'

# Finding 10: encoding and line endings are never damaged.
project cp1252
printf '# P\n\nCaf\351 rules.\n\n%s\n' "$legacy" | given cp1252 AGENTS.md
warns cp1252 AGENTS.md 'not valid UTF-8; left alone'

project mixed-eol
printf '# P\r\n\r\n%s\n\nLocal facts.\n' "$legacy" | given mixed-eol AGENTS.md
warns mixed-eol AGENTS.md 'mixed line endings; left alone'

# --- runs -----------------------------------------------------------------------------------

check_run() {  # name tree log
    local name=$1 tree=$2 log=$3
    if ! diff -r "$ex" "$tree" > "$tmp/$name.diff"; then
        fail "$name: files differ from expected:"; sed 's/^/    /' "$tmp/$name.diff" | head -40
    fi
    # Join wrapped lines: Windows PowerShell wraps long warnings in redirected output.
    local joined; joined=$(tr -d '\r\n' < "$log")
    while IFS="$(printf '\t')" read -r proj file text; do
        file_re=$(printf '%s' "$file" | perl -pe 's{/}{[/\\\\]}g; s{\.}{\\.}g')
        printf '%s' "$joined" | perl -e 'local $/; my $j = <STDIN>; exit($j =~ /\Q$ARGV[0]\E: \S*?[\/\\]\Q$ARGV[1]\E[\/\\]$ARGV[2]/ ? 0 : 1)' "$text" "$proj" "$file_re" \
            || fail "$name: no \"$text\" warning for $proj/$file"
    done < "$warns"
    local count; count=$(grep -c 'WARNING' "$log" || true)
    local expected; expected=$(wc -l < "$warns" | tr -d ' ')
    [ "$count" -eq "$expected" ] || fail "$name: $count warnings, expected $expected"
}

run_impl() {  # name command...
    local name=$1; shift
    local tree="$tmp/$name"
    cp -R "$fx" "$tree"
    "$@" "$tree" dry > "$tmp/$name.dry.log" 2>&1 || { fail "$name: dry run exited non-zero"; cat "$tmp/$name.dry.log"; return; }
    diff -r "$fx" "$tree" > /dev/null || fail "$name: dry run changed files"
    "$@" "$tree" apply > "$tmp/$name.log" 2>&1 || { fail "$name: apply exited non-zero"; cat "$tmp/$name.log"; return; }
    perl -pi -e 's/\r$//' "$tmp/$name.log"
    check_run "$name" "$tree" "$tmp/$name.log"
    grep -q 'up-to-date' "$tmp/$name.log" && grep -A1 'up-to-date$' "$tmp/$name.log" | grep -q 'up to date' \
        || fail "$name: up-to-date project not reported as up to date"
    "$@" "$tree" apply > "$tmp/$name.again.log" 2>&1 || fail "$name: second apply exited non-zero"
    grep -q '^0 file(s) written' "$tmp/$name.again.log" || fail "$name: second apply was not a no-op"
    echo "$name: checked"
}

bash_impl() {  # tree mode
    if [ "$2" = apply ]; then bash "$installer/sync-stubs.sh" --root "$1" --apply; else bash "$installer/sync-stubs.sh" --root "$1"; fi
}
run_impl bash bash_impl

ps=''
if command -v pwsh > /dev/null 2>&1; then ps=pwsh
elif command -v powershell.exe > /dev/null 2>&1; then ps=powershell.exe
fi
if [ -n "$ps" ]; then
    native() { if command -v cygpath > /dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi; }
    ps_impl() {  # tree mode
        local args=(-NoProfile -ExecutionPolicy Bypass -File "$(native "$installer/sync-stubs.ps1")" -Root "$(native "$1")")
        [ "$2" = apply ] && args+=(-Apply)
        "$ps" "${args[@]}"
    }
    run_impl powershell ps_impl
else
    echo "powershell: skipped (neither pwsh nor powershell.exe found)"
fi

if [ "$failures" -gt 0 ]; then echo "$failures failure(s)"; exit 1; fi
echo "all checks passed"
