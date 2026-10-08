# hide_run.ps1 -- hide the Godot window from the OUTSIDE, then run a --script capture tool.
#
# Why outside: docs/09 section 8 requires non-headless forensics not to disturb the user.
# Godot's own route (DisplayServer.window_set_mode(WINDOW_MODE_MINIMIZED)) was measured to
# STOP RENDERING -- the probe hung forever on frame_post_draw. So instead we use Win32
# ShowWindow(SW_HIDE): the window leaves the screen but keeps rendering.
#
# Judgement is by MEASUREMENT, not by "I passed the flag" (section 8, item 2): right after
# hiding we read IsWindowVisible back, and we also record how many milliseconds passed
# between process start and the window being hidden -- that is the real "user could have
# seen it" duration.
#
# We enumerate EVERY top-level window of the process (EnumWindows) instead of trusting
# Process.MainWindowHandle. Measured 2026-10-08: with the *console* build, MainWindowHandle
# returned title='Godot Engine (Console)' class='ConsoleWindowClass' -- we hid the console
# and the game window stayed on screen for the whole 29.7s run. Hence: use the non-console
# build (one process, one window) and enumerate properly. The title/class of every window we
# hide goes into the log, so "we hid the game window" is on record.
#
# NOTE: this file is deliberately ASCII-only. PowerShell 5.1 reads BOM-less .ps1 files using
# the system ANSI codepage; non-ASCII comments here get mis-decoded and break the parse.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File hide_run.ps1 -Exe <godot.exe> -Arcane <project dir> `
#       -ScriptPath res://tools/xxx.gd -Log <log file>

param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [Parameter(Mandatory = $true)][string]$Arcane,
    [Parameter(Mandatory = $true)][string]$ScriptPath,
    [Parameter(Mandatory = $true)][string]$Log
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
'@

function Get-WindowTag([IntPtr]$h) {
    $title = New-Object System.Text.StringBuilder 512
    [void][Sc.Native]::GetWindowTextW($h, $title, 512)
    $cls = New-Object System.Text.StringBuilder 512
    [void][Sc.Native]::GetClassNameW($h, $cls, 512)
    return "title='$($title.ToString())' class='$($cls.ToString())'"
}

$SW_HIDE = 0

$proc = Start-Process -FilePath $Exe -PassThru `
    -ArgumentList @('--path', $Arcane, '--script', $ScriptPath)
$targetPid = $proc.Id

$watch = [System.Diagnostics.Stopwatch]::StartNew()
$events = New-Object System.Collections.ArrayList
$seenTitles = New-Object System.Collections.ArrayList
$firstHideMs = -1
$hiddenHandles = New-Object System.Collections.ArrayList

function Get-ProcessWindows([int]$wanted) {
    $found = New-Object System.Collections.ArrayList
    $callback = [Sc.Native+EnumWindowsProc] {
        param([IntPtr]$hWnd, [IntPtr]$lParam)
        $owner = 0
        [void][Sc.Native]::GetWindowThreadProcessId($hWnd, [ref]$owner)
        if ($owner -eq $wanted) { [void]$found.Add($hWnd) }
        return $true
    }
    [void][Sc.Native]::EnumWindows($callback, [IntPtr]::Zero)
    return $found
}

while (-not $proc.HasExited) {
    Start-Sleep -Milliseconds 40
    $proc.Refresh()
    if ($proc.HasExited) { break }
    foreach ($h in (Get-ProcessWindows $targetPid)) {
        $tag = Get-WindowTag $h
        if (-not $seenTitles.Contains($tag)) {
            [void]$seenTitles.Add($tag)
            [void]$events.Add("seen at $($watch.ElapsedMilliseconds)ms hwnd=$h $tag")
        }
        if ([Sc.Native]::IsWindowVisible($h)) {
            $ms = $watch.ElapsedMilliseconds
            [void][Sc.Native]::ShowWindow($h, $SW_HIDE)
            Start-Sleep -Milliseconds 30
            $after = [Sc.Native]::IsWindowVisible($h)
            $iconic = [Sc.Native]::IsIconic($h)
            [void]$events.Add("hide#$($events.Count + 1): at ${ms}ms hwnd=$h $tag visibleBefore=True visibleAfter=$after IsIconic=$iconic")
            if (-not $hiddenHandles.Contains($h)) { [void]$hiddenHandles.Add($h) }
            if ($firstHideMs -lt 0) { $firstHideMs = $ms }
        }
    }
}

$proc.WaitForExit()
$finalVis = @()
foreach ($h in $hiddenHandles) {
    $finalVis += "hwnd=$h IsWindowVisible=$([Sc.Native]::IsWindowVisible($h))"
}

$out = New-Object System.Collections.ArrayList
[void]$out.Add("harness=hide_run.ps1 script=$ScriptPath")
[void]$out.Add("exe=$Exe")
[void]$out.Add("exit_code=$($proc.ExitCode) wall_ms=$($watch.ElapsedMilliseconds)")
[void]$out.Add("first_hide_at_ms=$firstHideMs (process start -> window already on screen; the user could in principle see it for this long)")
[void]$out.Add("windows_hidden=$($hiddenHandles.Count)")
foreach ($e in $events) { [void]$out.Add($e) }
[void]$out.Add("after_exit: " + ($(if ($finalVis.Count -eq 0) { 'nothing was ever hidden' } else { $finalVis -join '; ' })))
$out | Set-Content -Path $Log -Encoding ASCII

Write-Output "exit=$($proc.ExitCode) windows_hidden=$($hiddenHandles.Count) first_hide_ms=$firstHideMs"
Get-Content $Log
