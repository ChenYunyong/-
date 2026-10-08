# exe_smoke.ps1 -- run the EXPORTED Windows package (the double-click artifact), hidden.
#
# PET-94 asks for a package you can double-click. So the exported binary itself has to be
# started, not just built. This launches it, hides its window with Win32 ShowWindow(SW_HIDE)
# (docs/09 section 8: the user must not see it), lets it run for N seconds, records what the
# engine printed, then stops it.
#
# Cleanup rule: only the exact PID this script started, plus that PID's own children whose
# image name starts with ArcaneBlueprint, are ever terminated. Nothing is killed by exe name.
#
# ASCII-only on purpose (PS 5.1 reads BOM-less .ps1 as ANSI).

param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [Parameter(Mandatory = $true)][string]$Log,
    [int]$Seconds = 15,
    [string[]]$ExtraArgs = @()
)

$ErrorActionPreference = 'Stop'

Add-Type -Namespace Sc -Name Native -MemberDefinition @'
public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
[DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
[DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr hWnd, System.Text.StringBuilder s, int n);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassNameW(IntPtr hWnd, System.Text.StringBuilder s, int n);
[DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr hWnd, uint msg, IntPtr w, IntPtr l);
'@

# WM_CLOSE = 0x0010. Asking the game to close itself (instead of killing it) matters: a killed
# process loses whatever stdio is still buffered, and the boot log is exactly what we want.
$WM_CLOSE = 0x0010

function Get-WindowTag([IntPtr]$h) {
    $t = New-Object System.Text.StringBuilder 512
    [void][Sc.Native]::GetWindowTextW($h, $t, 512)
    $c = New-Object System.Text.StringBuilder 512
    [void][Sc.Native]::GetClassNameW($h, $c, 512)
    return "title='$($t.ToString())' class='$($c.ToString())'"
}

function Get-ProcessWindows([int]$wanted) {
    $found = New-Object System.Collections.ArrayList
    $cb = [Sc.Native+EnumWindowsProc] {
        param([IntPtr]$hWnd, [IntPtr]$lParam)
        $owner = 0
        [void][Sc.Native]::GetWindowThreadProcessId($hWnd, [ref]$owner)
        if ($owner -eq $wanted) { [void]$found.Add($hWnd) }
        return $true
    }
    [void][Sc.Native]::EnumWindows($cb, [IntPtr]::Zero)
    return $found
}

$stdout = "$Log.stdout.txt"
$stderr = "$Log.stderr.txt"
foreach ($f in @($stdout, $stderr, $Log)) { if (Test-Path $f) { [void](Remove-Item $f -Force) } }

# -ArgumentList is only passed when it is non-empty: PowerShell rejects an empty array there
# ("ArgumentList ... cannot be null"), so the no-extra-args case has to omit the parameter.
$startArgs = @{
    FilePath = $Exe
    PassThru = $true
    RedirectStandardOutput = $stdout
    RedirectStandardError = $stderr
}
if (@($ExtraArgs).Count -gt 0) { $startArgs['ArgumentList'] = @($ExtraArgs) }
$proc = Start-Process @startArgs
$targetPid = $proc.Id
$watch = [System.Diagnostics.Stopwatch]::StartNew()
$events = New-Object System.Collections.ArrayList
$hidden = New-Object System.Collections.ArrayList
$firstHideMs = -1

while ($watch.Elapsed.TotalSeconds -lt $Seconds -and -not $proc.HasExited) {
    Start-Sleep -Milliseconds 50
    $proc.Refresh()
    if ($proc.HasExited) { break }
    $workers = @($targetPid)
    foreach ($k in (Get-CimInstance Win32_Process -Filter "ParentProcessId=$targetPid" -ErrorAction SilentlyContinue)) {
        $workers += [int]$k.ProcessId
    }
    foreach ($wpid in $workers) {
        foreach ($h in (Get-ProcessWindows $wpid)) {
            if ([Sc.Native]::IsWindowVisible($h)) {
                $ms = $watch.ElapsedMilliseconds
                $tag = Get-WindowTag $h
                [void][Sc.Native]::ShowWindow($h, 0)
                Start-Sleep -Milliseconds 30
                $after = [Sc.Native]::IsWindowVisible($h)
                [void]$events.Add("hide at ${ms}ms pid=$wpid hwnd=$h $tag visibleAfter=$after IsIconic=$([Sc.Native]::IsIconic($h))")
                if (-not $hidden.Contains($h)) { [void]$hidden.Add($h) }
                if ($firstHideMs -lt 0) { $firstHideMs = $ms }
            }
        }
    }
}

# Ask the game to close itself and give it time to flush stdout.
foreach ($h in $hidden) { [void][Sc.Native]::PostMessageW($h, $WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero) }
$graceful = $proc.WaitForExit(8000)

$alive = -not $proc.HasExited
$ranMs = $watch.ElapsedMilliseconds

# Stop only this run's own processes: the exact started PID, plus its children whose image
# name starts with ArcaneBlueprint. Never by executable name alone.
$victims = New-Object System.Collections.ArrayList
[void]$victims.Add($targetPid)
foreach ($k in (Get-CimInstance Win32_Process -Filter "ParentProcessId=$targetPid" -ErrorAction SilentlyContinue)) {
    if ($k.Name -like 'ArcaneBlueprint*') { [void]$victims.Add([int]$k.ProcessId) }
}
foreach ($v in $victims) {
    $p = Get-Process -Id $v -ErrorAction SilentlyContinue
    if ($p -ne $null) { Stop-Process -Id $v -Force -ErrorAction SilentlyContinue }
}
Start-Sleep -Milliseconds 400

$finalVis = @()
foreach ($h in $hidden) { $finalVis += "hwnd=$h IsWindowVisible=$([Sc.Native]::IsWindowVisible($h))" }

$out = New-Object System.Collections.ArrayList
[void]$out.Add("harness=exe_smoke.ps1 exe=$Exe")
[void]$out.Add("started_pid=$targetPid ran_ms=$ranMs still_alive_after_${Seconds}s=$alive")
[void]$out.Add("closed_itself_after_WM_CLOSE=$graceful exit_code=$(if ($proc.HasExited) { $proc.ExitCode } else { 'n/a' })")
[void]$out.Add("first_hide_at_ms=$firstHideMs windows_hidden=$($hidden.Count)")
foreach ($e in $events) { [void]$out.Add($e) }
[void]$out.Add("terminated_pids=$(($victims) -join ',')")
[void]$out.Add("after_terminate: " + ($(if ($finalVis.Count -eq 0) { 'nothing was ever hidden' } else { $finalVis -join '; ' })))
[void]$out.Add("---- stdout ----")
if (Test-Path $stdout) { foreach ($l in (Get-Content $stdout)) { [void]$out.Add($l) } }
[void]$out.Add("---- stderr ----")
if (Test-Path $stderr) { foreach ($l in (Get-Content $stderr)) { [void]$out.Add($l) } }
$out | Set-Content -Path $Log -Encoding UTF8

Write-Output "ran_ms=$ranMs alive=$alive hidden=$($hidden.Count) log=$Log"
