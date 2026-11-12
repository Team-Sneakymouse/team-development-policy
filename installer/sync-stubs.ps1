<#
.SYNOPSIS
  Writes the canonical team-policy stubs from adapters/examples/ into enrolled projects.

.DESCRIPTION
  Dry run by default (see installer/DESIGN.md): it prints what it would change and writes
  nothing. Pass -Apply to write. It never commits, fetches, pushes, or touches pointer.json.

  A project is enrolled when it has .team-policy/pointer.json. Projects are looked for one
  and two levels below -Root (so nested workspace repos such as
  MagicSpells-Workspace/MagicSpells are found), or taken from -Project.

  Content is replaced only when it matches the current canonical text or a retired one from
  installer/retired/ exactly (line endings normalised, surrounding whitespace trimmed).
  For each enrolled project:
  - AGENTS.md: replaces a managed block (between the TEAM-POLICY MANAGED BOOTSTRAP markers)
    or the legacy bootstrap paragraphs with the canonical block. If neither is present,
    inserts the block after a leading H1 heading, or at the top when the file has an H1
    further down, or under a new "# Agent instructions" heading.
  - CLAUDE.md: created when missing (Claude Code reads CLAUDE.md, not AGENTS.md).
  - CLAUDE.md, .github/copilot-instructions.md, .cursor/rules/team-policy.mdc: replaced when
    the existing file is a known pointer stub. Copilot and Cursor stubs are not created
    where a project has none.
  Everything else is reported with a warning and left alone: custom stubs, locally edited
  managed blocks or legacy paragraphs, missing/unpaired/repeated markers, a managed block
  next to the legacy paragraphs, an AGENTS.md that starts with front matter and has no
  bootstrap yet, files that are not valid UTF-8, and files with mixed line endings.
  Line endings and a UTF-8 BOM of an existing file are kept; new files follow AGENTS.md.
  Matching is case-sensitive. sync-stubs.sh is the bash twin of this script (same decisions
  and output); installer/tests/test-sync-stubs.sh checks that they agree.

.EXAMPLE
  ./installer/sync-stubs.ps1                         # dry run over every enrolled project
  ./installer/sync-stubs.ps1 -Project ../SneakyWizards,../sneakyroyale
  ./installer/sync-stubs.ps1 -Apply                  # write; review with git diff in each project
#>
param(
    [string]$Root = (Join-Path $PSScriptRoot '../..'),
    [string[]]$Project,
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
$examples = Join-Path $PSScriptRoot '../adapters/examples'
$retired = Join-Path $PSScriptRoot 'retired'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
$wsChars = [char[]]" `t`r`n`f`v"

function Read-Text([string]$path) { [System.IO.File]::ReadAllText($path, $utf8) }
function To-Lf([string]$text) { $text -replace "`r`n", "`n" }
function Trim-Ws([string]$text) { $text.Trim($wsChars) }
function Read-Canonical([string]$path) { Trim-Ws (To-Lf (Read-Text $path)) }
function Read-Retired([string]$kind) {
    @(Get-ChildItem -LiteralPath (Join-Path $retired $kind) -File | Sort-Object Name | ForEach-Object { Read-Canonical $_.FullName })
}
function Count-Of([string]$text, [string]$needle) { [regex]::Matches($text, [regex]::Escape($needle)).Count }

# Reads a project file. Problem is set instead of Text when it can't be edited safely.
function Read-Doc([string]$path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $start = if ($bom) { 3 } else { 0 }
    try { $raw = $strictUtf8.GetString($bytes, $start, $bytes.Length - $start) }
    catch { return @{ Problem = 'not valid UTF-8; left alone' } }
    $crlf = [regex]::Matches($raw, "`r`n").Count
    $lf = [regex]::Matches($raw, "(?<!`r)`n").Count
    if ($crlf -gt 0 -and $lf -gt 0) { return @{ Problem = 'mixed line endings; left alone' } }
    $eol = if ($crlf -gt 0) { "`r`n" } else { "`n" }
    @{ Text = (To-Lf $raw); Eol = $eol; Bom = $bom; Problem = $null }
}

$bootstrapDoc = To-Lf (Read-Text (Join-Path $examples 'bootstrap.md'))
if ($bootstrapDoc -cnotmatch '(?s)```markdown\n(.*?)\n```') { throw "No fenced markdown block in adapters/examples/bootstrap.md" }
$block = Trim-Ws $Matches[1]
$retiredBlocks = Read-Retired 'bootstrap'
$legacyTexts = Read-Retired 'legacy-bootstrap'

$stubs = [ordered]@{
    'CLAUDE.md'                       = @{ Want = Read-Canonical (Join-Path $examples 'claude-code.md');          Retired = Read-Retired 'claude' }
    '.github/copilot-instructions.md' = @{ Want = Read-Canonical (Join-Path $examples 'copilot-instructions.md'); Retired = Read-Retired 'copilot' }
    '.cursor/rules/team-policy.mdc'   = @{ Want = Read-Canonical (Join-Path $examples 'cursor-rule.mdc');         Retired = Read-Retired 'cursor' }
}

$beginMarker = '<!-- BEGIN TEAM-POLICY MANAGED BOOTSTRAP -->'
$endMarker   = '<!-- END TEAM-POLICY MANAGED BOOTSTRAP -->'
$ordinal = [System.StringComparison]::Ordinal
# A leading H1, allowing only blank lines and complete HTML comments before it.
$leadingH1Rx = '\A(?:[ \t]*\n|[ \t]*<!--(?:(?!-->).)*-->[ \t]*\n)*# [^\n]*(?:\n|\z)'
# Wording of the legacy bootstrap paragraphs. Where it is left once the exact legacy texts
# are taken out, the paragraphs were edited locally. Has no match in any canonical block.
$legacyWordingRx = New-Object System.Text.RegularExpressions.Regex(
    'resolve shared policy using|read the resolved checkout\x27s',
    ([System.Text.RegularExpressions.RegexOptions]'IgnoreCase, CultureInvariant'))

# Decides what to do with an AGENTS.md text: returns New (and What) or Warn.
function Plan-Agents([string]$old) {
    $begins = Count-Of $old $beginMarker
    $ends = Count-Of $old $endMarker
    $legacyCount = 0; $legacyHit = $null; $others = $old
    foreach ($l in $legacyTexts) {
        $n = Count-Of $old $l
        if ($n -gt 0) { $legacyCount += $n; $legacyHit = $l; $others = $others.Replace($l, '') }
    }
    $legacyEdited = $legacyWordingRx.IsMatch($others)

    if ($begins -gt 0 -or $ends -gt 0) {
        $bi = $old.IndexOf($beginMarker, $ordinal)
        $ei = $old.IndexOf($endMarker, $ordinal)
        if ($begins -ne 1 -or $ends -ne 1 -or $ei -lt $bi) { return @{ Warn = 'bootstrap markers missing, unpaired or repeated; left alone' } }
        if ($legacyCount -gt 0 -or $legacyEdited) { return @{ Warn = 'managed block and legacy bootstrap both present; left alone' } }
        $after = $ei + $endMarker.Length
        $cur = $old.Substring($bi, $after - $bi)
        if ($cur -ceq $block) { return @{ New = $old } }
        if ($retiredBlocks -ccontains $cur) {
            return @{ New = $old.Substring(0, $bi) + $block + $old.Substring($after); What = 'replace managed block' }
        }
        return @{ Warn = 'managed block edited locally; left alone, merge by hand' }
    }
    if ($legacyEdited) { return @{ Warn = 'legacy bootstrap edited locally; left alone, merge by hand' } }
    if ($legacyCount -gt 1) { return @{ Warn = 'legacy bootstrap present more than once; left alone' } }
    if ($legacyCount -eq 1) {
        $i = $old.IndexOf($legacyHit, $ordinal)
        return @{ New = $old.Substring(0, $i) + $block + $old.Substring($i + $legacyHit.Length); What = 'replace legacy short bootstrap' }
    }
    if ($old -cmatch '\A---[ \t]*\n') { return @{ Warn = 'front matter and no bootstrap block; left alone, add the block by hand' } }
    $m = [regex]::Match($old, $leadingH1Rx, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($m.Success) {
        $head = $old.Substring(0, $m.Length)
        if (-not $head.EndsWith("`n", $ordinal)) { $head += "`n" }
        $rest = $old.Substring($m.Length)
        $gap = if ($rest.Length -gt 0 -and -not $rest.StartsWith("`n", $ordinal)) { "`n`n" } else { "`n" }
        return @{ New = $head + "`n" + $block + $gap + $rest; What = 'insert block after heading' }
    }
    if ($old -cmatch '(?m)^# ') {
        return @{ New = $block + "`n`n" + ($old -creplace '\A\n+', ''); What = 'insert block at top' }
    }
    if ((Trim-Ws $old) -ceq '') { return @{ New = "# Agent instructions`n`n$block`n"; What = 'insert heading and block' } }
    @{ New = "# Agent instructions`n`n$block`n`n$old"; What = 'insert heading and block' }
}

function Get-Projects {
    # powershell -File passes "a,b" as one string, so split it here.
    if ($Project) { return $Project | ForEach-Object { $_ -split ',' } | Where-Object { $_ } | ForEach-Object { (Resolve-Path $_).Path } }
    $rootPath = (Resolve-Path $Root).Path
    $level1 = Get-ChildItem -LiteralPath $rootPath -Directory -Force
    $level2 = $level1 | ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Directory -Force -ErrorAction SilentlyContinue }
    @($level1) + @($level2) |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName '.team-policy/pointer.json') } |
        ForEach-Object { $_.FullName }
}

function Save([string]$path, [string]$lfText, [string]$eol, [bool]$bom, [string]$what) {
    $verb = if ($Apply) { 'wrote' } else { 'would write' }
    Write-Host ("  {0} {1} ({2})" -f $verb, $path, $what)
    if (-not $Apply) { return }
    $dir = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $bytes = $utf8.GetBytes(($lfText -replace "`n", $eol))
    if ($bom) { $bytes = [byte[]](0xEF, 0xBB, 0xBF) + $bytes }
    [System.IO.File]::WriteAllBytes($path, $bytes)
}

$changed = 0
foreach ($proj in Get-Projects) {
    if (-not (Test-Path -LiteralPath (Join-Path $proj '.team-policy/pointer.json'))) {
        Write-Warning "$proj has no .team-policy/pointer.json; skipped"
        continue
    }
    Write-Host $proj
    $before = $changed
    $warned = $false

    $agentsPath = Join-Path $proj 'AGENTS.md'
    $eol = "`n"
    if (Test-Path -LiteralPath $agentsPath) {
        $doc = Read-Doc $agentsPath
        if ($doc.Problem) {
            Write-Warning "  $($doc.Problem): $agentsPath"; $warned = $true
        } else {
            $eol = $doc.Eol
            $plan = Plan-Agents $doc.Text
            if ($plan.Warn) { Write-Warning "  $($plan.Warn): $agentsPath"; $warned = $true }
            elseif ($plan.New -cne $doc.Text) { Save $agentsPath $plan.New $eol $doc.Bom $plan.What; $changed++ }
        }
    } else {
        $plan = Plan-Agents "# Agent instructions`n"
        Save $agentsPath $plan.New $eol $false 'create'; $changed++
    }

    foreach ($rel in $stubs.Keys) {
        $path = Join-Path $proj $rel
        $want = $stubs[$rel].Want
        if (Test-Path -LiteralPath $path) {
            $doc = Read-Doc $path
            if ($doc.Problem) { Write-Warning "  $($doc.Problem): $path"; $warned = $true; continue }
            $cur = Trim-Ws $doc.Text
            if ($cur -ceq $want) { continue }
            if ($stubs[$rel].Retired -cnotcontains $cur) {
                Write-Warning "  custom file left alone: $path"; $warned = $true
                continue
            }
            Save $path "$want`n" $doc.Eol $doc.Bom 'replace pointer stub'
        } elseif ($rel -eq 'CLAUDE.md') {
            Save $path "$want`n" $eol $false 'create'
        } else {
            continue
        }
        $changed++
    }
    if ($changed -eq $before -and -not $warned) { Write-Host '  up to date' }
}

$mode = if ($Apply) { 'written' } else { 'to write (dry run; pass -Apply to write)' }
Write-Host ("{0} file(s) {1}." -f $changed, $mode)
