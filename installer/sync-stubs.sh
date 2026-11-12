#!/usr/bin/env bash
# Writes the canonical team-policy stubs from adapters/examples/ into enrolled projects.
# Bash twin of sync-stubs.ps1: same decisions, same file contents, same report.
#
# Dry run by default (see installer/DESIGN.md): it prints what it would change and writes
# nothing. Pass --apply to write. It never commits, fetches, pushes, or touches pointer.json.
#
# A project is enrolled when it has .team-policy/pointer.json. Projects are looked for one
# and two levels below --root (so nested workspace repos such as
# MagicSpells-Workspace/MagicSpells are found), or taken from --project.
#
# For each enrolled project:
# - AGENTS.md: replaces the block between the TEAM-POLICY MANAGED BOOTSTRAP markers, or the
#   legacy short bootstrap paragraph ("Resolve shared policy using ..."), with the canonical
#   block. If neither is present, inserts the block after the first heading.
# - CLAUDE.md: created when missing (Claude Code reads CLAUDE.md, not AGENTS.md).
# - CLAUDE.md, .github/copilot-instructions.md, .cursor/rules/team-policy.mdc: replaced when
#   the existing file is a short pointer stub. Any other existing file is reported and left
#   alone. Copilot and Cursor stubs are not created where a project has none.
# Line endings of an existing file are kept; new files follow AGENTS.md. Files are written
# as UTF-8 without a BOM.
#
# Needs bash 3.2+ and perl 5 (both ship with macOS, Git for Windows and most Linux
# distributions). No GNU-only tool flags.
#
# Usage:
#   installer/sync-stubs.sh                         # dry run over every enrolled project
#   installer/sync-stubs.sh --project ../SneakyWizards,../sneakyroyale
#   installer/sync-stubs.sh --apply                 # write; review with git diff in each project
# Options:
#   --root DIR       folder holding the projects (default: the folder holding this checkout)
#   --project LIST   comma-separated project folders instead of searching --root; repeatable
#   --apply          write the changes

set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root="$here/../.."
apply=0
project_args=()

usage() { sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; }

while [ $# -gt 0 ]; do
    case "$1" in
        --apply) apply=1 ;;
        --root) root=${2:?--root needs a folder}; shift ;;
        --root=*) root=${1#--root=} ;;
        --project) project_args+=("${2:?--project needs a folder}"); shift ;;
        --project=*) project_args+=("${1#--project=}") ;;
        -h|--help) usage; exit 0 ;;
        *) echo "sync-stubs: unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

examples="$here/../adapters/examples"
tmp=$(mktemp -d 2>/dev/null || mktemp -d -t sync-stubs)
trap 'rm -rf "$tmp"' EXIT

# Print a file with a leading UTF-8 BOM removed and CRLF turned into LF.
to_lf() { perl -0777 -pe 's/\A\xEF\xBB\xBF//; s/\r\n/\n/g' "$1"; }

# Succeed when the file contains a CRLF.
has_crlf() { perl -e 'local $/; my $t = <>; exit((defined $t && $t =~ /\r\n/) ? 0 : 1)' "$1"; }

to_lf "$examples/bootstrap.md" | perl -e '
    local $/; my $doc = <STDIN>;
    $doc =~ /```markdown\n(.*?)\n```/s or die "No fenced markdown block in adapters/examples/bootstrap.md\n";
    my $block = $1; $block =~ s/\A\s+//; $block =~ s/\s+\z//; print $block;' > "$tmp/block"

stub_rels=("CLAUDE.md" ".github/copilot-instructions.md" ".cursor/rules/team-policy.mdc")
stub_srcs=("CLAUDE.md" "copilot-instructions.md" "cursor-rule.mdc")
for i in 0 1 2; do to_lf "$examples/${stub_srcs[$i]}" > "$tmp/want.$i"; done

# Projects in the same order as the PowerShell script: first level, then second level per
# first-level folder, each sorted case-insensitively.
projects=()
if [ ${#project_args[@]} -gt 0 ]; then
    for list in "${project_args[@]}"; do
        while IFS= read -r p; do
            [ -n "$p" ] || continue
            resolved=$(cd "$p" 2>/dev/null && pwd) || { echo "sync-stubs: cannot find path '$p'" >&2; exit 1; }
            projects+=("$resolved")
        done <<EOF
$(printf '%s\n' "$list" | tr ',' '\n')
EOF
    done
else
    rootp=$(cd "$root" && pwd)
    shopt -s nullglob dotglob
    sorted_dirs() { for d in "$1"/*/; do printf '%s\n' "${d%/}"; done | LC_ALL=C sort -f; }
    level1=()
    while IFS= read -r d; do level1+=("$d"); done <<EOF
$(sorted_dirs "$rootp")
EOF
    candidates=()
    for d in ${level1[@]+"${level1[@]}"}; do [ -n "$d" ] && candidates+=("$d"); done
    for d in ${level1[@]+"${level1[@]}"}; do
        [ -n "$d" ] || continue
        while IFS= read -r c; do [ -n "$c" ] && candidates+=("$c"); done <<EOF
$(sorted_dirs "$d")
EOF
    done
    shopt -u nullglob dotglob
    for d in ${candidates[@]+"${candidates[@]}"}; do
        [ -e "$d/.team-policy/pointer.json" ] && projects+=("$d")
    done
fi

save() {  # target lf-content-file eol what
    local verb='would write'
    [ "$apply" -eq 1 ] && verb='wrote'
    echo "  $verb $1 ($4)"
    [ "$apply" -eq 1 ] || return 0
    mkdir -p "$(dirname "$1")"
    if [ "$3" = crlf ]; then perl -pe 's/\n/\r\n/g' "$2" > "$1"; else cat "$2" > "$1"; fi
}

changed=0
for proj in ${projects[@]+"${projects[@]}"}; do
    if [ ! -e "$proj/.team-policy/pointer.json" ]; then
        echo "WARNING: $proj has no .team-policy/pointer.json; skipped" >&2
        continue
    fi
    echo "$proj"
    before=$changed

    agents="$proj/AGENTS.md"
    eol=lf
    if [ -e "$agents" ]; then
        if has_crlf "$agents"; then eol=crlf; fi
        to_lf "$agents" > "$tmp/old"
    else
        printf '# Agent instructions\n' > "$tmp/old"
    fi
    what=$(BLOCK="$tmp/block" OUT="$tmp/new" perl -e '
        local $/;
        open my $b, "<", $ENV{BLOCK} or die "$ENV{BLOCK}: $!\n"; my $block = <$b>;
        my $old = <STDIN>; $old = "" unless defined $old;
        my $managed = qr/<!-- BEGIN TEAM-POLICY MANAGED BOOTSTRAP -->.*?<!-- END TEAM-POLICY MANAGED BOOTSTRAP -->/s;
        my $legacy = qr/Resolve shared policy using `\.team-policy\/pointer\.json`.*?follow its linked guidance relevant to the task\./s;
        my ($new, $what) = ($old);
        if    ($old =~ $managed)         { $new =~ s/$managed/$block/g; $what = "replace managed block" }
        elsif ($old =~ $legacy)          { $new =~ s/$legacy/$block/g;  $what = "replace legacy short bootstrap" }
        elsif ($old =~ /\A# [^\n]*\n/)   { $new =~ s/\A(# [^\n]*\n)/$1\n$block\n/; $what = "insert block after heading" }
        else                             { $new = "# Agent instructions\n\n$block\n\n$old"; $what = "insert heading and block" }
        open my $o, ">", $ENV{OUT} or die "$ENV{OUT}: $!\n"; print $o $new; close $o;
        print $what;' < "$tmp/old")
    if ! cmp -s "$tmp/old" "$tmp/new"; then
        save "$agents" "$tmp/new" "$eol" "$what"
        changed=$((changed + 1))
    fi

    for i in 0 1 2; do
        rel=${stub_rels[$i]}
        path="$proj/$rel"
        want="$tmp/want.$i"
        file_eol=$eol
        if [ -e "$path" ]; then
            if has_crlf "$path"; then file_eol=crlf; else file_eol=lf; fi
            to_lf "$path" > "$tmp/cur"
            verdict=$(perl -e '
                local $/;
                open my $c, "<", $ARGV[0] or die; my $cur = <$c>;  $cur = ""  unless defined $cur;
                open my $w, "<", $ARGV[1] or die; my $want = <$w>; $want = "" unless defined $want;
                (my $ct = $cur) =~ s/\s+\z//; (my $wt = $want) =~ s/\s+\z//;
                if ($ct eq $wt) { print "same"; exit }
                my $lines = ($ct =~ tr/\n//) + 1;
                my $stub = qr/\A(?:# Claude Code|Follow |\@AGENTS\.md|---\ndescription: "?(?:Team development policy|Candidate team policy))/;
                print(($lines > 8 || $cur !~ $stub) ? "custom" : "stub");' "$tmp/cur" "$want")
            case $verdict in
                same) continue ;;
                custom) echo "WARNING:   custom file left alone: $path" >&2; continue ;;
            esac
            save "$path" "$want" "$file_eol" 'replace pointer stub'
        elif [ "$rel" = CLAUDE.md ]; then
            save "$path" "$want" "$file_eol" 'create'
        else
            continue
        fi
        changed=$((changed + 1))
    done
    if [ "$changed" -eq "$before" ]; then echo '  up to date'; fi
done

if [ "$apply" -eq 1 ]; then mode='written'; else mode='to write (dry run; pass --apply to write)'; fi
echo "$changed file(s) $mode."
