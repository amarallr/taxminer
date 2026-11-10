$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath 'taxminer.Rproj')) { throw 'Run from the TaxMiner project root.' }
$fixture = Join-Path (Get-Location) 'agent_smoke_fixture.md'
$report = 'reports/execution/agent_cli_rstudio_smoke.txt'
if (Test-Path -LiteralPath $fixture) { throw 'Refusing to overwrite an existing fixture.' }
Set-Content -LiteralPath $fixture -Value 'Synthetic token: RSTUDIO-SYNTHETIC-4821.' -Encoding UTF8
$results = [System.Collections.Generic.List[string]]::new()
try {
  $geminiOutput = & powershell.exe -NoProfile -File scripts/run_gemini.ps1 --approval-mode plan --prompt 'Read only agent_smoke_fixture.md and report the synthetic token. Do not edit, execute shell commands, or inspect any other path.' 2>&1 | Out-String
  $geminiExit = $LASTEXITCODE
  $results.Add("gemini_exit_code: $geminiExit")
  $results.Add($geminiOutput.Trim())
  $results.Add("gemini_synthetic_token_match: $($geminiOutput.Contains('RSTUDIO-SYNTHETIC-4821'))")

  $codexOutput = & codex exec --sandbox read-only --ask-for-approval on-request --skip-git-repo-check --ephemeral 'Read only agent_smoke_fixture.md and report the synthetic token. Do not edit, execute shell commands, or inspect any other path.' 2>&1 | Out-String
  $codexExit = $LASTEXITCODE
  $results.Add("codex_exit_code: $codexExit")
  $results.Add($codexOutput.Trim())
  $results.Add("codex_synthetic_token_match: $($codexOutput.Contains('RSTUDIO-SYNTHETIC-4821'))")
  $results | Set-Content -LiteralPath $report -Encoding UTF8
  if ($geminiExit -ne 0 -or $codexExit -ne 0 -or -not $geminiOutput.Contains('RSTUDIO-SYNTHETIC-4821') -or -not $codexOutput.Contains('RSTUDIO-SYNTHETIC-4821')) { exit 1 }
} finally {
  Remove-Item -LiteralPath $fixture -ErrorAction SilentlyContinue
}
