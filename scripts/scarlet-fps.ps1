param(
    [Parameter(Mandatory)][string]$Game,
    [ValidateSet('series-s', 'series-x')][string]$Console = 'series-s',
    # The size the title draws for: 'auto' (the default) your monitor's, as the nearest of 3840x2160,
    # 2560x1440, 1920x1080 or 1280x720 not above it; 'console' the console's own 4K (the most work for the
    # card: 2560x1440 inside on Series X); or one of those sizes. The title draws at 2/3 of it inside.
    [ValidatePattern('^(auto|console|\d{3,5}x\d{3,5})$')][string]$Res = 'auto',
    [ValidateRange(0, 3)][int]$MipDrop = 1,
    [int]$CardBuffersMB = 1024,
    [int]$CardWindowsMB = 512,
    [switch]$Hooks,
    [switch]$ProbeRays,
    [switch]$RayTracing,
    [switch]$Prewarm,
    # Leave the title's saved settings alone. Unset: the screen size the title saved (settings.xml,
    # resolutionFullscreen) is set to the size drawn for, so the interface is laid out for it.
    [switch]$KeepSettings,
    # Seconds after the start during which A is pressed by itself (0: off).
    [int]$AutoA = 0,
    # (Port of Kemerd/VIctory-NVIDIA-RT 60368f8, GPL-3.0.) DLSS frame generation: frames shown for each
    # one rendered (2 to 6; 3 and more need an RTX 50), 0 off (the default). Needs NVIDIA's files
    # (-StreamlineDir) and an RTX 40 or later; on another card it logs why and stays off.
    [ValidateSet(0, 2, 3, 4, 5, 6)][int]$FrameGen = 0,
    # DLSS in place of the title's upscaling. Unset: off, or 'quality' with -FrameGen (frame
    # generation takes its depth and motion vectors from the upscaling; on Series X only DLSS makes one).
    [ValidateSet('', 'off', 'dlaa', 'quality', 'balanced', 'performance')][string]$Dlss = '',
    # NVIDIA Reflex with DLSS or frame generation (the source launcher's default: boost). Frame
    # generation turns Reflex's low latency on by itself; 'off' leaves only that.
    [ValidateSet('off', 'on', 'boost')][string]$Reflex = 'boost',
    # The folder with sl.interposer.dll and the rest of NVIDIA's files (Get-NVIDIA-DLSS.cmd of the
    # source puts them in nvidia-sdk\Streamline\bin\x64). Unset: looked for there, beside this
    # repository and under %LOCALAPPDATA%\victory.
    [string]$StreamlineDir = ''
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $root 'target\release\victory.exe'
if (-not (Test-Path -LiteralPath $exe)) {
    $exe = Join-Path $root 'victory.exe'
}
if (-not (Test-Path -LiteralPath $exe)) {
    throw "Release binary not found next to script or in target\release\victory.exe"
}
if (-not (Test-Path -LiteralPath $Game)) {
    throw "Game not found: $Game"
}
if (Get-Process victory -ErrorAction SilentlyContinue) {
    Write-Host "victory.exe is already running." -ForegroundColor Yellow
    exit 1
}

# Clear inherited VICTORY_* except path overrides (keeps default save & cache)
$keep = 'VICTORY_CONFIG', 'VICTORY_GAME_DIR', 'VICTORY_CACHE_DIR', 'VICTORY_DATA_DIR'
Get-ChildItem Env:VICTORY_* -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin $keep } | ForEach-Object { Remove-Item "Env:$($_.Name)" }

$gameDir = Split-Path -Parent (Resolve-Path -LiteralPath $Game)
$set = [ordered]@{
    VICTORY_GAME_DIR             = $gameDir
    VICTORY_PIPELINE_BOOK        = '1'
    VICTORY_LOG                  = 'info'
    VICTORY_FRAME_INTERVAL_MS    = '16.667'

    # RTX 3070 8GB VRAM budget + Scarlett page pool (-1.2 GB texture VRAM)
    VICTORY_DYNAMIC_SLOTS        = '524288'
    VICTORY_MAX_PRELUDES         = '32'
    VICTORY_CARD_BUFFERS_MB      = "$CardBuffersMB"
    VICTORY_CARD_WINDOWS_MB      = "$CardWindowsMB"
    VICTORY_TEXTURE_MIP_DROP     = "$MipDrop"
    VICTORY_TEXTURE_ROOM_PERCENT = '94'
    VICTORY_PAGE_POOL            = '1'
    VICTORY_STAGING_PACK         = '1'
    VICTORY_LEVELS_ON_DEMAND     = '0'

    # Scarlett CPU submit & upload wins (+ 3050 Nsight A/B tweaks)
    VICTORY_WAIT_RESIDENT        = '0'
    VICTORY_JOIN_COPIES          = '0'
    VICTORY_REFRESH_ONCE         = '0'   # merged build: 1 stretched meshes and corrupted posters
    VICTORY_CARD_REHASH_RUNS     = '1'
    VICTORY_BACK_OWN_VIEW        = '1'
    VICTORY_WIDE_MERGE           = '1'
    VICTORY_MIRROR_FAST          = '1'
    VICTORY_PIPELINE_WAIT_MS     = '20'
    VICTORY_NO_WATCHDOG          = '1'   # LOCAL: the title's own watchdog does not end a long frame
    VICTORY_ASYNC_SUBMIT         = '1'
    VICTORY_QUEUE2               = '1'
    VICTORY_INDIRECT_WINDOW      = '1'
    VICTORY_TEXTURE_NO_WAIT      = '1'
    VICTORY_COPY_PLAIN           = '1'
    VICTORY_WIDE_TEXTURES        = '1'
    VICTORY_INDIRECT_GATHER      = '1'
    VICTORY_LATE_WAIT_LISTS      = '1024'
    VICTORY_CARD_FILLS_BATCH     = '0'
    VICTORY_GATHER_DISPATCH      = '0'
    VICTORY_RELAY                = '2'
    VICTORY_WIDE_BACK            = '1'
    VICTORY_RELAY_COPY           = '1'
    VICTORY_CARD_STEPS           = '2'
    VICTORY_INDIRECT_BATCH       = '2'
    VICTORY_MAP_THREADS          = '1'
    VICTORY_CARD_AWAKE           = '0'
    VICTORY_SHOW_AFTER           = '1'
    VICTORY_JOIN_PARTS           = '8'
    VICTORY_UPLOAD_AHEAD         = '1'
    VICTORY_CARD_BUFFERS_MIN_KB  = '64'
    VICTORY_POOL_DISCARD         = '1'
    VICTORY_FILL_TITLE           = '1'
    VICTORY_PARTIAL_DELTA        = '1'
    VICTORY_BAKE_DELTA           = '1'
    VICTORY_MAP_LOCK_FINE        = '1'
    VICTORY_POOL_CAP             = '1'
    VICTORY_TABLE_MEMO           = '1'
    VICTORY_LIST_ALIAS_EXACT     = '1'
    VICTORY_LIST_HOLD            = '1'
    VICTORY_EARLY_TEXTURES_MS    = '40'
    VICTORY_BAKE_TEXTURES_MS     = '10000'
    VICTORY_HEAP_PASS_MAX        = '0'
    VICTORY_HEAP_CHANGED_MAX     = '0'
    VICTORY_LEAVE_OUT            = '02384a60fda6f2d0,5dc3b25986622949,6f225b641c5b0708'   # + the two water light programs (dark water tiles on NVIDIA)
    VICTORY_WC_NO_BACK           = '1'
    VICTORY_WC_NO_BACK_MIN_KB    = '1024'
    VICTORY_SYNC_IN_PLACE        = '1'
    VICTORY_SPANS_QUICK          = '1'
    VICTORY_SYNC_FINE            = '1'
    VICTORY_HEAP_SYNC_FIRST      = '1'
    VICTORY_HEAP_SYNC_AT_SUBMIT  = '1'
    VICTORY_SOFT_VIEWS           = 'copies'
    VICTORY_SAMPLERS_MADE        = '1'   # 0 loads them from the saved library (faster starts) but colour grading comes out posterized: dark, banded light
    VICTORY_TABLE_NAMED_ONLY     = '1'
    VICTORY_QUEUE_MARKS          = '1'
    VICTORY_PORT_CONSTANTS       = '1'
    VICTORY_EARLY_DEPTH          = '1'

    # Merged build (scarlett 80 ms changes on this fork)
    VICTORY_COPY_BESIDE          = '1'
    VICTORY_STORE_BESIDE         = '1'
    VICTORY_GPU_BACK_MAX_KB      = '1024'
}
if ($Hooks) {
    $set.VICTORY_GPU_ONLY = '1'
    $set.VICTORY_KNOWN_WRITES = '1'
}
if ($ProbeRays -and -not $RayTracing) {
    $set.VICTORY_PROBE_RAYS = '1'
    $set.VICTORY_PLANE_NOW = '1'
} elseif (-not $RayTracing) {
    $set.VICTORY_AMBIENT = '0.8'
    $set.VICTORY_AMBIENT_AIR = '1.5'
    $set.VICTORY_AMBIENT_SPECULAR = '1'   # reflections stand-in (from trustno1-coder/VIctory-NVIDIA)
}
# The display reported to the title (-Res): by default the monitor's, so a 1080p screen is not drawn for at 4K.
$display = $Res
if ($display -eq 'auto') {
    $display = ''
    $height = 0
    try {
        Add-Type -Namespace ScarletFps -Name Display -MemberDefinition @'
[System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential, CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
public struct DEVMODE {
    [System.Runtime.InteropServices.MarshalAs(System.Runtime.InteropServices.UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
    public short dmSpecVersion, dmDriverVersion, dmSize, dmDriverExtra;
    public int dmFields, dmPositionX, dmPositionY, dmDisplayOrientation, dmDisplayFixedOutput;
    public short dmColor, dmDuplex, dmYResolution, dmTTOption, dmCollate;
    [System.Runtime.InteropServices.MarshalAs(System.Runtime.InteropServices.UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
    public short dmLogPixels;
    public int dmBitsPerPel, dmPelsWidth, dmPelsHeight, dmDisplayFlags, dmDisplayFrequency;
}
[System.Runtime.InteropServices.DllImport("user32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
public static extern bool EnumDisplaySettings(string name, int mode, ref DEVMODE dm);
'@
        $dm = New-Object 'ScarletFps.Display+DEVMODE'
        $dm.dmSize = [System.Runtime.InteropServices.Marshal]::SizeOf($dm)
        # -1: the primary monitor's current mode, in real pixels (not scaled by Windows' text size).
        if ([ScarletFps.Display]::EnumDisplaySettings($null, -1, [ref]$dm)) { $height = $dm.dmPelsHeight }
    } catch {}
    if ($height -le 0) {
        try { $height = (Get-CimInstance Win32_VideoController | Measure-Object CurrentVerticalResolution -Maximum).Maximum } catch {}
    }
    if ($height -ge 2160) { $display = '3840x2160' }
    elseif ($height -ge 1440) { $display = '2560x1440' }
    elseif ($height -ge 1080) { $display = '1920x1080' }
    elseif ($height -gt 0) { $display = '1280x720' }
    if ($display) { Write-Host "Display reported to the title: $display (your monitor; -Res to change)" }
} elseif ($display -eq 'console') {
    $display = ''
}
if ($display) {
    $set.VICTORY_DISPLAY_MODE = $display
    # The output size the title draws for (VICTORY_OUTPUT, its own settings patched at load): the display mode
    # alone changes nothing, the title keeps its 4K output (2560x1440 inside on Series X). Only the title's
    # own modes take.
    if ($display -in '1280x720', '1664x936', '1920x1080', '2560x1440', '3840x2160') { $set.VICTORY_OUTPUT = $display }
    else { Write-Host "-Res $display is not one of the title's own sizes: only the display mode is changed" -ForegroundColor Yellow }
}
# The title lays its interface out for the screen size it saved in its settings (settings.xml,
# resolutionFullscreen), not for the size it draws: saved at 4K by a first run, the interface comes out
# twice as big at 1920x1080. That saved size is set to the size drawn for (the console's 4K without one);
# the file is kept once as settings.xml.bak first. -KeepSettings leaves it alone.
if (-not $KeepSettings) {
    $want = if ($set.Contains('VICTORY_OUTPUT')) { $set.VICTORY_OUTPUT } else { '3840x2160' }
    $w, $h = $want -split 'x'
    $dataDir = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'victory\data' } else { '' }
    if ($dataDir -and (Test-Path -LiteralPath $dataDir)) {
        foreach ($titleDir in Get-ChildItem -LiteralPath $dataDir -Directory) {
            $xml = Join-Path $titleDir.FullName 'storage\settings\settings.xml'
            if (-not (Test-Path -LiteralPath $xml)) { continue }
            try {
                $text = [System.IO.File]::ReadAllText($xml)
                $re = [regex]'(<resolutionFullscreen>\s*<width value=")(\d+)(" />\s*<height value=")(\d+)'
                $m = $re.Match($text)
                if (-not $m.Success -or ($m.Groups[2].Value -eq $w -and $m.Groups[4].Value -eq $h)) { continue }
                $bak = "$xml.bak"
                if (-not (Test-Path -LiteralPath $bak)) { Copy-Item -LiteralPath $xml -Destination $bak }
                $new = $text.Substring(0, $m.Index) + $m.Groups[1].Value + $w + $m.Groups[3].Value + $h +
                    $text.Substring($m.Index + $m.Length)
                [System.IO.File]::WriteAllText($xml, $new, (New-Object System.Text.UTF8Encoding($false)))
                Write-Host "Saved screen size $($m.Groups[2].Value)x$($m.Groups[4].Value) -> $want in $xml (-KeepSettings: leave it)"
            } catch {
                Write-Host "Could not set the saved screen size in ${xml}: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }
}
if ($RayTracing) { $set.VICTORY_BVH_BUILDER = '1' }
if ($AutoA -gt 0) { $set.VICTORY_AUTO_A = "$AutoA" }

# (Port of Kemerd/VIctory-NVIDIA-RT 60368f8, GPL-3.0.) DLSS and frame generation: the switches the
# source launcher passes. Nothing is set (and no NVIDIA file is loaded) without -FrameGen or -Dlss.
if ($Dlss -eq '') { $Dlss = if ($FrameGen -gt 0) { 'quality' } else { 'off' } }
if ($FrameGen -gt 0 -or $Dlss -ne 'off') {
    $slDirs = @($StreamlineDir, (Join-Path $root 'nvidia-sdk\Streamline\bin\x64'))
    if ($env:LOCALAPPDATA) { $slDirs += Join-Path $env:LOCALAPPDATA 'victory\nvidia-sdk\Streamline\bin\x64' }
    $slDirs += 'C:\dev\sdk\streamline-sdk-v2.14.16\bin\x64'
    $slDir = $slDirs | Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $_ 'sl.interposer.dll')) } | Select-Object -First 1
    if (-not $slDir) {
        Write-Host "NVIDIA's files (sl.interposer.dll and the rest) are not on this PC: running without DLSS and frame generation (-StreamlineDir names their folder)." -ForegroundColor Yellow
    } else {
        $set.VICTORY_STREAMLINE_DIR = $slDir
        if ($Dlss -ne 'off') {
            $set.VICTORY_DLSS = '1'
            $set.VICTORY_DLSS_MODE = $Dlss
        }
        if ($FrameGen -gt 0) {
            $set.VICTORY_FRAMEGEN = '1'
            $set.VICTORY_FRAMEGEN_X = "$FrameGen"
            # Frame generation takes 1.5 to 2 GB of the card's memory, which the layer otherwise
            # fills with textures: it is left a fifth of the budget (as the source launcher does).
            $set.VICTORY_TEXTURE_ROOM_PERCENT = '80'
            if ($Console -eq 'series-x' -and $Dlss -eq 'off') {
                Write-Host "Frame generation on Series X needs DLSS (-Dlss quality or another mode): it stays off." -ForegroundColor Yellow
            }
        }
        if ($Reflex -ne 'off') { $set.VICTORY_REFLEX = $Reflex }
    }
}

foreach ($k in $set.Keys) { Set-Item -Path "Env:$k" -Value $set[$k] }

if ($Prewarm) {
    Write-Host "Prewarming shaders and pipelines..." -ForegroundColor Cyan
    & $exe shaders $gameDir
    & $exe warm
}

$runsDir = Join-Path $root 'runs'
New-Item -ItemType Directory -Force -Path $runsDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logPath = Join-Path $runsDir "3070-$stamp.log"

Write-Host "=== victory-scarlett RTX 3070 8GB (release, $Console, MipDrop=$MipDrop, PagePool=1) ===" -ForegroundColor Green
if ($set.Contains('VICTORY_STREAMLINE_DIR')) {
    # (Port of Kemerd/VIctory-NVIDIA-RT 60368f8, GPL-3.0.)
    Write-Host "DLSS $Dlss, frame generation $(if ($FrameGen -gt 0) { "${FrameGen}x" } else { 'off' }), Reflex $Reflex (NVIDIA's files: $($set.VICTORY_STREAMLINE_DIR))"
}
Write-Host "Log: $logPath"
$ErrorActionPreference = 'Continue'
& $exe run $Game --execute --console $Console 2>&1 | Tee-Object -FilePath $logPath
exit $LASTEXITCODE
