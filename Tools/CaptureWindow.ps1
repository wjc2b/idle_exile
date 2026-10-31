# 截取游戏窗口的客户区（不含任务栏、浏览器、桌面），存到 %TEMP%\se-shots。
# 只用窗口句柄 + GetClientRect，绝不整屏截图，避免把桌面上的其他东西带进仓库。
#
# 用法：
#   powershell -NoProfile -ExecutionPolicy Bypass -File Tools\CaptureWindow.ps1 -Name doll
#   ... -Tab 2                      打开时停在角色页
#   ... -Drag "1512,245,375,445"    先做一次真实鼠标拖拽（起点 x,y 终点 x,y）
#   ... -KeepOpen                   截完不关，方便接手调试
param(
    [string]$Name = "shot",
    [string]$Tab = "2",
    [string]$Resolution = "1920x1000",
    [string]$Drag = "",
    [int]$WaitSeconds = 9,
    [switch]$KeepOpen
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class GodotWin {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, int dx, int dy, int d, UIntPtr e);
  public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
}
"@

$godot = 'f:\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64.exe'
$repo = Split-Path -Parent $PSScriptRoot
$dir = Join-Path $env:TEMP 'se-shots'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$logOut = Join-Path $dir 'game.out.log'
$logErr = Join-Path $dir 'game.err.log'

$argList = @('--path', '.', '--position', '0,0', '--resolution', $Resolution, '--', "--tab=$Tab")
$p = Start-Process -FilePath $godot -ArgumentList $argList -WorkingDirectory $repo -PassThru `
    -RedirectStandardOutput $logOut -RedirectStandardError $logErr
Start-Sleep -Seconds $WaitSeconds
if ($p.HasExited) { throw "游戏退出，stderr: $(Get-Content $logErr -Raw)" }

$h = $p.MainWindowHandle
[GodotWin]::SetWindowPos($h, [GodotWin]::HWND_TOPMOST, 0, 0, 0, 0, 0x0040 -bor 0x0001 -bor 0x0002) | Out-Null
[GodotWin]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds 1000

if ($Drag -ne '') {
    $c = $Drag.Split(',')
    if ($c.Count -ne 4) { throw "-Drag 需要 'sx,sy,ex,ey'" }
    $sx = [int]$c[0]; $sy = [int]$c[1]; $ex = [int]$c[2]; $ey = [int]$c[3]
    [GodotWin]::SetCursorPos($sx, $sy) | Out-Null
    Start-Sleep -Milliseconds 250
    [GodotWin]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 200
    for ($i = 1; $i -le 16; $i++) {
        [GodotWin]::SetCursorPos($sx + [int](($ex - $sx) * $i / 16), $sy + [int](($ey - $sy) * $i / 16)) | Out-Null
        Start-Sleep -Milliseconds 45
    }
    Start-Sleep -Milliseconds 200
    [GodotWin]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 800
}

# 鼠标移开，别让 tooltip 挡住纸娃娃
[GodotWin]::SetCursorPos(1900, 980) | Out-Null
Start-Sleep -Milliseconds 400

$rect = New-Object GodotWin+RECT
[GodotWin]::GetClientRect($h, [ref]$rect) | Out-Null
$pt = New-Object GodotWin+POINT
[GodotWin]::ClientToScreen($h, [ref]$pt) | Out-Null
$w = $rect.Right - $rect.Left
$ht = $rect.Bottom - $rect.Top
if ($w -le 0 -or $ht -le 0) { throw "窗口客户区尺寸异常: ${w}x${ht}" }

$bmp = New-Object System.Drawing.Bitmap $w, $ht
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($pt.X, $pt.Y, 0, 0, (New-Object System.Drawing.Size($w, $ht)))
$out = Join-Path $dir ($Name + '.png')
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()

if (-not $KeepOpen) {
    $p.CloseMainWindow() | Out-Null
    Start-Sleep -Seconds 2
    if (-not $p.HasExited) { $p.Kill() }
}

$err = Get-Content $logErr -Raw
if ($err -and $err.Trim() -ne '') { Write-Warning "游戏 stderr: $err" }
Write-Host "saved $out (${w}x${ht})"