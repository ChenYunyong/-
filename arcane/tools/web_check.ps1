# web_check.ps1 -- does the exported web build actually boot in a browser?
#
# Serves arcane/build/web with a PLAIN static server (python -m http.server, which sends no
# COOP/COEP headers -- that is the whole point of the nothreads web build) and loads it in
# headless Edge. Two things come back:
#   * a screenshot   -- what the canvas actually shows.
#   * the JS console -- --enable-logging=stderr relays the page's console.* calls; this is
#                       where a game-level boot error shows up in full, and it is the only
#                       output that says WHETHER the engine got as far as running game code.
#
# Timing is the whole difficulty, and it was measured rather than guessed (2026-10-08):
#   * the virtual-time budget is a real knob. 30000 was too short; 60000 booted once and not
#     the next time. Default is 120000.
#   * the browser profile is cold on the FIRST invocation, and a cold pass often does not get
#     the engine started at all. So the page is loaded TWICE and both passes append their
#     console output to the same file -- one run alone produces false negatives.
# A DOM dump was tried and dropped: --dump-dom kept returning the pre-boot document (status
# overlay still present, <canvas> with no size) even on a warm profile, so it proved nothing.
#
# ASCII-only on purpose: PS 5.1 reads BOM-less .ps1 files as ANSI, and non-ASCII comments
# get mis-decoded into a parse error.

param(
    [Parameter(Mandatory = $true)][string]$Root,
    [int]$Port = 8392,
    [int]$Budget = 120000,
    [string]$OutDir = ''
)

$ErrorActionPreference = 'Stop'

if ($OutDir -eq '') { $OutDir = Join-Path $Root 'arcane\build\_webcheck' }
if (-not (Test-Path $OutDir)) { [void](New-Item -ItemType Directory -Path $OutDir -Force) }

$web = Join-Path $Root 'arcane\build\web'
$shot = Join-Path $OutDir 'web_boot.png'
$prof = Join-Path $OutDir 'edgeprof'
$conFile = Join-Path $OutDir 'edge_console.txt'

foreach ($f in @($shot, $conFile)) {
    if (Test-Path $f) { [void](Remove-Item $f -Force) }
}

$srv = Start-Process python -ArgumentList @('-m', 'http.server', "$Port", '--directory', $web) `
    -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 2

$edge = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
$common = @(
    '--headless=new', '--disable-gpu', '--enable-unsafe-swiftshader', '--no-first-run',
    '--no-default-browser-check', "--user-data-dir=$prof", '--window-size=960,540',
    '--enable-logging=stderr', '--v=1',
    "--virtual-time-budget=$Budget"
)

# Pass 1 only warms the profile; pass 2 is the one that counts. Measured: on the cold pass the
# screenshot catches the loading overlay (23701 bytes), on the warm pass it catches the frame
# the game actually drew (3660 bytes). Both passes' console output is kept, so a boot error
# that only surfaces on one of them still lands in the file.
$tmp1 = "$conFile.pass1"
$p1 = Start-Process -FilePath $edge -PassThru -Wait -RedirectStandardError $tmp1 `
    -ArgumentList ($common + @("http://127.0.0.1:$Port/index.html"))
Write-Output "pass1 (cold profile, warm-up) exit=$($p1.ExitCode)"
if (Test-Path $tmp1) { Get-Content $tmp1 -Encoding utf8 | Add-Content -Path $conFile -Encoding utf8 }
if (Test-Path $tmp1) { [void](Remove-Item $tmp1 -Force) }

$p2 = Start-Process -FilePath $edge -PassThru -Wait -RedirectStandardError "$conFile.pass2" `
    -ArgumentList ($common + @("--screenshot=$shot", "http://127.0.0.1:$Port/index.html"))
Write-Output "pass2 (warm profile, screenshot) exit=$($p2.ExitCode)"
if (Test-Path "$conFile.pass2") {
    Get-Content "$conFile.pass2" -Encoding utf8 | Add-Content -Path $conFile -Encoding utf8
    [void](Remove-Item "$conFile.pass2" -Force)
}

Stop-Process -Id $srv.Id -Force
Write-Output "server stopped pid=$($srv.Id)"

foreach ($pair in @(@('shot', $shot), @('console', $conFile))) {
    if (Test-Path $pair[1]) {
        Write-Output "$($pair[0]) bytes=$((Get-Item $pair[1]).Length)"
    } else {
        Write-Output "$($pair[0]) MISSING"
    }
}

# Count the page's own console lines. They are NOT echoed here on purpose: this text is
# Unicode and a GBK console mangles it into question marks, which would make a real error
# message unreadable. Read $conFile instead -- that file is written as UTF-8 by the browser.
if (Test-Path $conFile) {
    $hits = @(Select-String -Path $conFile -Pattern 'INFO:CONSOLE' -Encoding utf8)
    Write-Output "page console lines=$($hits.Count) -- read them in $conFile"
    if ($hits.Count -eq 0) {
        Write-Output "(none in either pass: the engine never started -- re-run with a larger -Budget)"
    }
}
