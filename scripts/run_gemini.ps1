param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]] $GeminiArguments
)

$toolRoot = Join-Path $env:LOCALAPPDATA 'Programs/TaxMiner'
$nodeDirectory = Join-Path $toolRoot 'node-v26.13.0-win-x64'
$geminiCommand = Join-Path $toolRoot 'gemini_cli/node_modules/.bin/gemini.cmd'

if (-not (Test-Path -LiteralPath (Join-Path $nodeDirectory 'node.exe'))) {
  throw 'Per-user Node.js was not found. Expected %LOCALAPPDATA%/Programs/TaxMiner/node-v26.13.0-win-x64/node.exe.'
}
if (-not (Test-Path -LiteralPath $geminiCommand)) {
  throw 'Per-user Gemini CLI was not found. Install @google/gemini-cli under %LOCALAPPDATA%/Programs/TaxMiner/gemini_cli.'
}

$env:PATH = $nodeDirectory + [IO.Path]::PathSeparator + $env:PATH
& $geminiCommand @GeminiArguments
exit $LASTEXITCODE
