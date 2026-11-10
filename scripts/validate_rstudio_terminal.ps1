$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath 'taxminer.Rproj')) {
    throw 'Run from the TaxMiner project root.'
}
$validation_report = 'reports/execution/rstudio_environment_validation.txt'
@(
    "started_at: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz')"
    "rstudio: $env:RSTUDIO"
    "term_program: $env:TERM_PROGRAM"
    'command: Rscript --vanilla scripts/validate_environment.R'
    'LANG and explicit LC categories cleared in this child process only.'
) | Set-Content -LiteralPath $validation_report -Encoding UTF8
Remove-Item Env:LANG,Env:LC_ALL,Env:LC_CTYPE,Env:LC_COLLATE,Env:LC_MONETARY,Env:LC_TIME,Env:LC_NUMERIC,Env:LC_MESSAGES -ErrorAction SilentlyContinue
$ErrorActionPreference = 'Continue'
& Rscript --vanilla scripts/validate_environment.R 2>&1 |
    ForEach-Object {
        $validation_line = $_.ToString()
        Add-Content -LiteralPath $validation_report -Value $validation_line -Encoding UTF8
        Write-Output $validation_line
    }
$validation_exit_code = $LASTEXITCODE
@(
    "exit_code: $validation_exit_code"
    "finished_at: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz')"
) | Add-Content -LiteralPath $validation_report -Encoding UTF8
exit $validation_exit_code
