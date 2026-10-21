# Pre-session readiness check for Windows. Run from the repo folder:
#   powershell -ExecutionPolicy Bypass -File .\verify.ps1
$ready = $true

function Report($name, $passed, $hint) {
    if ($passed) {
        Write-Host ("  [OK]   {0}" -f $name) -ForegroundColor Green
    } else {
        Write-Host ("  [FAIL] {0} - {1}" -f $name, $hint) -ForegroundColor Red
        $script:ready = $false
    }
}

Write-Host "Checking your machine"
Report "Docker installed" ([bool](Get-Command docker -ErrorAction SilentlyContinue)) "install Docker Desktop"
Report "Git installed" ([bool](Get-Command git -ErrorAction SilentlyContinue)) "install Git for Windows"

docker info *> $null
Report "Docker running" ($LASTEXITCODE -eq 0) "start Docker Desktop and wait until it says 'running'"

docker image inspect secure-path-toolbox:1.0 *> $null
Report "Image secure-path-toolbox:1.0" ($LASTEXITCODE -eq 0) "run 'docker compose build' in this folder"

if ($ready) {
    docker compose run --rm toolbox selftest
    if ($LASTEXITCODE -ne 0) { $ready = $false }
}

if ($ready) {
    Write-Host "`nREADY - see you at the session." -ForegroundColor Green
} else {
    Write-Host "`nNOT READY - fix the items above, or send the output to the facilitator." -ForegroundColor Red
    exit 1
}
