param(
  [string] $Report = 'reports/execution/agent_cli_rstudio_smoke.txt'
)
# Synthetic read-only smoke test for Codex, Claude Code and Gemini CLI.
# Run from the project root. Uses only a temporary synthetic fixture.
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath 'taxminer.Rproj')) { throw 'Run from the TaxMiner project root.' }
$fixtureName = 'agent_smoke_fixture.md'
$fixture = Join-Path (Get-Location) $fixtureName
$token = 'RSTUDIO-SYNTHETIC-4821'
$prompt = "Read only $fixtureName and report the synthetic token. Do not edit, execute shell commands, or inspect any other path."
# Codex reads files through shell commands; its read-only sandbox blocks writes.
$codexPrompt = "Run exactly one read-only command to print $fixtureName, then report the synthetic token. Do not edit or inspect any other path."
if (Test-Path -LiteralPath $fixture) { throw 'Refusing to overwrite an existing fixture.' }

$results = [System.Collections.Generic.List[string]]::new()
$results.Add("started_at: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz')")
$results.Add("rstudio: $env:RSTUDIO")
$results.Add("term_program: $env:TERM_PROGRAM")
$failed = $false

function Invoke-AgentSmoke([string] $Name, [scriptblock] $Command) {
  # Native stderr must not abort the run in Windows PowerShell 5.1.
  $ErrorActionPreference = 'Continue'
  $output = & $Command 2>&1 | ForEach-Object { $_.ToString() } | Out-String
  $exitCode = $LASTEXITCODE
  $match = $output.Contains($token)
  $script:results.Add("${Name}_exit_code: $exitCode")
  $script:results.Add("${Name}_synthetic_token_match: $match")
  $script:results.Add("${Name}_output_begin")
  $script:results.Add($output.Trim())
  $script:results.Add("${Name}_output_end")
  if ($exitCode -ne 0 -or -not $match) { $script:failed = $true }
}

Set-Content -LiteralPath $fixture -Value "Synthetic token: $token." -Encoding UTF8
try {
  Invoke-AgentSmoke 'codex' { '' | codex exec --sandbox read-only --skip-git-repo-check --ephemeral $codexPrompt }
  Invoke-AgentSmoke 'claude' { claude -p --tools Read --permission-mode manual $prompt }
  Invoke-AgentSmoke 'gemini' { powershell.exe -NoProfile -File scripts/run_gemini.ps1 --approval-mode plan --prompt $prompt }
} finally {
  Remove-Item -LiteralPath $fixture -ErrorAction SilentlyContinue
  $results.Add("fixture_removed: $(-not (Test-Path -LiteralPath $fixture))")
  $results.Add("finished_at: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz')")
  $results | Set-Content -LiteralPath $Report -Encoding UTF8
}
if ($failed) { exit 1 }
exit 0
