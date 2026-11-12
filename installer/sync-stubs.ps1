<#
.SYNOPSIS
  Writes the canonical team-policy stubs from adapters/examples/ into enrolled projects.

.DESCRIPTION
  Dry run by default (see installer/DESIGN.md): it prints what it would change and writes
  nothing. Pass -Apply to write. It never commits, fetches, pushes, or touches pointer.json.

  A project is enrolled when it has .team-policy/pointer.json. Projects are looked for one
  and two levels below -Root (so nested workspace repos such as
  MagicSpells-Workspace/MagicSpells are found), or taken from -Project.

  For each enrolled project:
  - AGENTS.md: replaces the block between the TEAM-POLICY MANAGED BOOTSTRAP markers, or the
    legacy short bootstrap paragraph ("Resolve shared policy using ..."), with the canonical
    block. If neither is present, inserts the block after the first heading.
  - CLAUDE.md: created when missing (Claude Code reads CLAUDE.md, not AGENTS.md).
  - CLAUDE.md, .github/copilot-instructions.md, .cursor/rules/team-policy.mdc: replaced when
    the existing file is a short pointer stub. Any other existing file is reported and left
    alone. Copilot and Cursor stubs are not created where a project has none.
  Line endings of an existing file are kept; new files follow AGENTS.md. Matching is
  case-sensitive. sync-stubs.sh is the bash twin of this script (same decisions and output).

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
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Read-Text([string]$path) { [System.IO.File]::ReadAllText($path, $utf8) }
function To-Lf([string]$text) { $text -replace "`r`n", "`n" }

$bootstrapDoc = To-Lf (Read-Text (Join-Path $examples 'bootstrap.md'))
if ($bootstrapDoc -cnotmatch '(?s)```markdown\n(.*?)\n```') { throw "No fenced markdown block in adapters/examples/bootstrap.md" }
$block = $Matches[1].Trim()

$stubs = [ordered]@{
    'CLAUDE.md'                       = To-Lf (Read-Text (Join-Path $examples 'CLAUDE.md'))
    '.github/copilot-instructions.md' = To-Lf (Read-Text (Join-Path $examples 'copilot-instructions.md'))
    '.cursor/rules/team-policy.mdc'   = To-Lf (Read-Text (Join-Path $examples 'cursor-rule.mdc'))
}

$managedRx = '(?s)<!-- BEGIN TEAM-POLICY MANAGED BOOTSTRAP -->.*?<!-- END TEAM-POLICY MANAGED BOOTSTRAP -->'
$legacyRx  = '(?s)Resolve shared policy using `\.team-policy/pointer\.json`.*?follow its linked guidance relevant to the task\.'
$stubRx    = '^(# Claude Code|Follow |@AGENTS\.md|---\ndescription: "?(Team development policy|Candidate team policy))'

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

function Save([string]$path, [string]$lfText, [string]$eol, [string]$what) {
    $verb = if ($Apply) { 'wrote' } else { 'would write' }
    Write-Host ("  {0} {1} ({2})" -f $verb, $path, $what)
    if (-not $Apply) { return }
    $dir = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText($path, ($lfText -replace "`n", $eol), $utf8)
}

$changed = 0
foreach ($proj in Get-Projects) {
    if (-not (Test-Path -LiteralPath (Join-Path $proj '.team-policy/pointer.json'))) {
        Write-Warning "$proj has no .team-policy/pointer.json; skipped"
        continue
    }
    Write-Host $proj
    $before = $changed

    $agentsPath = Join-Path $proj 'AGENTS.md'
    $eol = "`n"
    if (Test-Path -LiteralPath $agentsPath) {
        $raw = Read-Text $agentsPath
        if ($raw -match "`r`n") { $eol = "`r`n" }
        $old = To-Lf $raw
    } else {
        $old = "# Agent instructions`n"
    }
    $evaluator = [System.Text.RegularExpressions.MatchEvaluator] { param($m) $block }
    if ($old -cmatch $managedRx) {
        $new = [regex]::Replace($old, $managedRx, $evaluator); $what = 'replace managed block'
    } elseif ($old -cmatch $legacyRx) {
        $new = [regex]::Replace($old, $legacyRx, $evaluator); $what = 'replace legacy short bootstrap'
    } elseif ($old -cmatch '^# [^\n]*\n') {
        $new = $old -creplace '^(# [^\n]*\n)', ('$1' + "`n" + $block.Replace('$', '$$') + "`n"); $what = 'insert block after heading'
    } else {
        $new = "# Agent instructions`n`n$block`n`n$old"; $what = 'insert heading and block'
    }
    if ($new -cne $old) { Save $agentsPath $new $eol $what; $changed++ }

    foreach ($rel in $stubs.Keys) {
        $path = Join-Path $proj $rel
        $want = $stubs[$rel]
        $fileEol = $eol
        if (Test-Path -LiteralPath $path) {
            $raw = Read-Text $path
            $fileEol = if ($raw -match "`r`n") { "`r`n" } else { "`n" }
            $cur = To-Lf $raw
            if ($cur.TrimEnd() -ceq $want.TrimEnd()) { continue }
            if (($cur.TrimEnd() -split "`n").Count -gt 8 -or $cur -cnotmatch $stubRx) {
                Write-Warning "  custom file left alone: $path"
                continue
            }
            Save $path $want $fileEol 'replace pointer stub'
        } elseif ($rel -eq 'CLAUDE.md') {
            Save $path $want $fileEol 'create'
        } else {
            continue
        }
        $changed++
    }
    if ($changed -eq $before) { Write-Host '  up to date' }
}

$mode = if ($Apply) { 'written' } else { 'to write (dry run; pass -Apply to write)' }
Write-Host ("{0} file(s) {1}." -f $changed, $mode)
