#!/usr/bin/env bash
# Writes the canonical team-policy stubs from adapters/examples/ into enrolled projects.
# Bash twin of sync-stubs.ps1: same decisions, same file contents, same report.
# installer/tests/test-sync-stubs.sh checks that the two agree.
#
# Dry run by default (see installer/DESIGN.md): it prints what it would change and writes
# nothing. Pass --apply to write. It never commits, fetches, pushes, or touches pointer.json.
#
# A project is enrolled when it has .team-policy/pointer.json. Projects are looked for one
# and two levels below --root (so nested workspace repos such as
# MagicSpells-Workspace/MagicSpells are found), or taken from --project.
#
# Content is replaced only when it matches the current canonical text or a retired one from
# installer/retired/ exactly (line endings normalised, surrounding whitespace trimmed).
# For each enrolled project:
# - AGENTS.md: replaces a managed block (between the TEAM-POLICY MANAGED BOOTSTRAP markers)
#   or the legacy bootstrap paragraphs with the canonical block. If neither is present,
#   inserts the block after a leading H1 heading, or at the top when the file has an H1
#   further down, or under a new "# Agent instructions" heading.
# - CLAUDE.md: created when missing (Claude Code reads CLAUDE.md, not AGENTS.md).
# - CLAUDE.md, .github/copilot-instructions.md, .cursor/rules/team-policy.mdc: replaced when
#   the existing file is a known pointer stub. Copilot and Cursor stubs are not created
#   where a project has none.
# Everything else is reported with a warning and left alone: custom stubs, locally edited
# managed blocks, missing/unpaired/repeated markers, a managed block next to the legacy
# paragraphs, files that are not valid UTF-8, and files with mixed line endings.
# Line endings and a UTF-8 BOM of an existing file are kept; new files follow AGENTS.md.
# Matching is case-sensitive.
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

# The decisions mirror sync-stubs.ps1 step by step; keep the two in sync.
exec perl -e '
use strict; use warnings;
use Encode ();
use File::Path qw(make_path);
$| = 1;

my ($apply, $examples, $retired, @projects) = @ARGV;

sub slurp { my ($p) = @_; open my $f, "<:raw", $p or die "$p: $!\n"; local $/; my $t = <$f>; defined $t ? $t : "" }
sub to_lf { my ($t) = @_; $t =~ s/\r\n/\n/g; $t }
sub trim_ws { my ($t) = @_; $t =~ s/\A[ \t\r\n\f\x0B]+//; $t =~ s/[ \t\r\n\f\x0B]+\z//; $t }
sub canonical { my $t = slurp($_[0]); $t =~ s/\A\xEF\xBB\xBF//; trim_ws(to_lf($t)) }
sub read_retired {
    my $d = "$retired/$_[0]";
    opendir my $h, $d or die "$d: $!\n";
    my @names = sort grep { -f "$d/$_" } readdir $h;
    map { canonical("$d/$_") } @names;
}
sub count_of { my ($text, $needle) = @_; my $n = () = $text =~ /\Q$needle\E/g; $n }

# Reads a project file. problem is set instead of text when it cannot be edited safely.
sub read_doc {
    my $raw = slurp($_[0]);
    my $bom = ($raw =~ s/\A\xEF\xBB\xBF//) ? 1 : 0;
    my $copy = $raw;
    return { problem => "not valid UTF-8; left alone" }
        unless eval { Encode::decode("UTF-8", $copy, Encode::FB_CROAK); 1 };
    my $crlf = () = $raw =~ /\r\n/g;
    my $lf = () = $raw =~ /(?<!\r)\n/g;
    return { problem => "mixed line endings; left alone" } if $crlf && $lf;
    return { text => to_lf($raw), eol => ($crlf ? "\r\n" : "\n"), bom => $bom };
}

my $doc = to_lf(slurp("$examples/bootstrap.md"));
$doc =~ /```markdown\n(.*?)\n```/s or die "No fenced markdown block in adapters/examples/bootstrap.md\n";
my $block = trim_ws($1);
my @retired_blocks = read_retired("bootstrap");
my @legacy_texts = read_retired("legacy-bootstrap");

my @stubs = (
    { rel => "CLAUDE.md",                       want => canonical("$examples/claude-code.md"),          retired => [read_retired("claude")] },
    { rel => ".github/copilot-instructions.md", want => canonical("$examples/copilot-instructions.md"), retired => [read_retired("copilot")] },
    { rel => ".cursor/rules/team-policy.mdc",   want => canonical("$examples/cursor-rule.mdc"),         retired => [read_retired("cursor")] },
);

my $begin_marker = "<!-- BEGIN TEAM-POLICY MANAGED BOOTSTRAP -->";
my $end_marker   = "<!-- END TEAM-POLICY MANAGED BOOTSTRAP -->";
# A leading H1, allowing only blank lines and complete HTML comments before it.
my $leading_h1 = qr/\A(?:[ \t]*\n|[ \t]*<!--(?:(?!-->).)*-->[ \t]*\n)*# [^\n]*\n/s;

# Decides what to do with an AGENTS.md text: returns new (and what) or warn.
sub plan_agents {
    my ($old) = @_;
    my $begins = count_of($old, $begin_marker);
    my $ends = count_of($old, $end_marker);
    my ($legacy_count, $legacy_hit) = (0, undef);
    for my $l (@legacy_texts) { my $n = count_of($old, $l); if ($n) { $legacy_count += $n; $legacy_hit = $l } }

    if ($begins || $ends) {
        my $bi = index($old, $begin_marker);
        my $ei = index($old, $end_marker);
        return { warn => "bootstrap markers missing, unpaired or repeated; left alone" }
            if $begins != 1 || $ends != 1 || $ei < $bi;
        return { warn => "managed block and legacy bootstrap both present; left alone" } if $legacy_count;
        my $after = $ei + length $end_marker;
        my $cur = substr($old, $bi, $after - $bi);
        return { new => $old } if $cur eq $block;
        if (grep { $_ eq $cur } @retired_blocks) {
            return { new => substr($old, 0, $bi) . $block . substr($old, $after), what => "replace managed block" };
        }
        return { warn => "managed block edited locally; left alone, merge by hand" };
    }
    return { warn => "legacy bootstrap present more than once; left alone" } if $legacy_count > 1;
    if ($legacy_count == 1) {
        my $i = index($old, $legacy_hit);
        return { new => substr($old, 0, $i) . $block . substr($old, $i + length $legacy_hit), what => "replace legacy short bootstrap" };
    }
    if ($old =~ $leading_h1) {
        my $len = $+[0];
        my $rest = substr($old, $len);
        my $gap = (length $rest && substr($rest, 0, 1) ne "\n") ? "\n\n" : "\n";
        return { new => substr($old, 0, $len) . "\n" . $block . $gap . $rest, what => "insert block after heading" };
    }
    if ($old =~ /^# /m) {
        (my $body = $old) =~ s/\A\n+//;
        return { new => "$block\n\n$body", what => "insert block at top" };
    }
    return { new => "# Agent instructions\n\n$block\n", what => "insert heading and block" } if trim_ws($old) eq "";
    return { new => "# Agent instructions\n\n$block\n\n$old", what => "insert heading and block" };
}

sub save {
    my ($path, $lf_text, $eol, $bom, $what) = @_;
    print "  ", ($apply ? "wrote" : "would write"), " $path ($what)\n";
    return unless $apply;
    (my $dir = $path) =~ s{/[^/]*\z}{};
    make_path($dir) unless -d $dir;
    (my $out = $lf_text) =~ s/\n/$eol/g;
    $out = "\xEF\xBB\xBF$out" if $bom;
    open my $f, ">:raw", $path or die "$path: $!\n";
    print $f $out;
    close $f or die "$path: $!\n";
}

sub warning { print STDERR "WARNING: $_[0]\n" }

my $changed = 0;
for my $proj (@projects) {
    unless (-e "$proj/.team-policy/pointer.json") { warning("$proj has no .team-policy/pointer.json; skipped"); next }
    print "$proj\n";
    my $before = $changed;
    my $warned = 0;

    my $agents = "$proj/AGENTS.md";
    my $eol = "\n";
    if (-e $agents) {
        my $d = read_doc($agents);
        if ($d->{problem}) {
            warning("  $d->{problem}: $agents"); $warned = 1;
        } else {
            $eol = $d->{eol};
            my $plan = plan_agents($d->{text});
            if ($plan->{warn}) { warning("  $plan->{warn}: $agents"); $warned = 1 }
            elsif ($plan->{new} ne $d->{text}) { save($agents, $plan->{new}, $eol, $d->{bom}, $plan->{what}); $changed++ }
        }
    } else {
        my $plan = plan_agents("# Agent instructions\n");
        save($agents, $plan->{new}, $eol, 0, "create"); $changed++;
    }

    for my $s (@stubs) {
        my $path = "$proj/$s->{rel}";
        if (-e $path) {
            my $d = read_doc($path);
            if ($d->{problem}) { warning("  $d->{problem}: $path"); $warned = 1; next }
            my $cur = trim_ws($d->{text});
            next if $cur eq $s->{want};
            unless (grep { $_ eq $cur } @{ $s->{retired} }) {
                warning("  custom file left alone: $path"); $warned = 1;
                next;
            }
            save($path, "$s->{want}\n", $d->{eol}, $d->{bom}, "replace pointer stub");
        } elsif ($s->{rel} eq "CLAUDE.md") {
            save($path, "$s->{want}\n", $eol, 0, "create");
        } else {
            next;
        }
        $changed++;
    }
    print "  up to date\n" if $changed == $before && !$warned;
}

print "$changed file(s) ", ($apply ? "written" : "to write (dry run; pass --apply to write)"), ".\n";
' "$apply" "$here/../adapters/examples" "$here/retired" ${projects[@]+"${projects[@]}"}
