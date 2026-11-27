param(
    [Parameter(Mandatory)][string]$Game,
    [ValidateSet('series-s', 'series-x')][string]$Console = 'series-s',
    [ValidateRange(0, 3)][int]$MipDrop = 1,
    [int]$CardBuffersMB = 1024,
    [int]$CardWindowsMB = 512,
    [ValidateRange(0.0, 1.0)][double]$Cas = 0.7,
    [switch]$NoThin,
    [switch]$NoWcBar,
    [switch]$NoTiled,
    [switch]$Tiled,
    [switch]$NoHooks,
    [switch]$Hooks,
    [switch]$ProbeRays,
    [switch]$RayTracing,
    [switch]$Prewarm,
    # Seconds after the start during which A is pressed by itself (0: off).
    [int]$AutoA = 0
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $root 'target\fast\victory.exe'
if (-not (Test-Path -LiteralPath $exe)) {
    $exe = Join-Path $root 'target\release\victory.exe'
}
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
    VICTORY_LOG                  = 'warn,victory_gpu::host=info,victory_hle::modules::dsp=debug'
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
    VICTORY_JOIN_COPIES          = '1'
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
    VICTORY_LATE_WAIT_LISTS      = '256'
    VICTORY_CARD_FILLS_BATCH     = '0'
    VICTORY_GATHER_DISPATCH      = '0'
    VICTORY_RELAY                = '2'
    VICTORY_WIDE_BACK            = '1'
    VICTORY_RELAY_COPY           = '1'
    VICTORY_CARD_STEPS           = '2'
    VICTORY_INDIRECT_BATCH       = '2'
    VICTORY_MAP_THREADS          = '1'
    VICTORY_CARD_AWAKE           = '0'   # 1 stalled RTX 4080 GPU by +5-8 ms/frame
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
    VICTORY_EARLY_TEXTURES_MS    = '12'    # default 12 ms: avoids 40 ms driving hitches without starving world textures
    VICTORY_BAKE_TEXTURES_MS     = '10000'
    VICTORY_HEAP_PASS_MAX        = '4096'  # high enough so buildings/character skinning never go stale, still caps huge spikes
    VICTORY_HEAP_CHANGED_MAX     = '8192'  # prevents stretched meshes / missing walls while avoiding 20 ms spikes
    VICTORY_LEAVE_OUT            = '02384a60fda6f2d0,5dc3b25986622949,6f225b641c5b0708'   # + the two water light programs (dark water tiles on NVIDIA)
    VICTORY_WC_NO_BACK           = '1'
    VICTORY_WC_NO_BACK_MIN_KB    = '1024'  # keep <1024 KiB skinning/visibility buffers copying back so NPCs/walls don't glitch
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

    # Merged build (scarlett 80 ms changes on this fork) + 7800X3D / RTX 4080 open-world tuning
    VICTORY_COPY_BESIDE          = '1'
    VICTORY_STORE_BESIDE         = '1'
    VICTORY_GPU_BACK_MAX_KB      = '1024'  # restore 1024 KiB so 512-1024 KiB character/building buffers don't stretch or disappear
    VICTORY_THIN                 = '1'    # offload 45k-60k list calls/frame to 6 worker threads (8 starved submit thread by +6 ms)
    VICTORY_THIN_THREADS         = '6'
    VICTORY_WINDOWS_BAR_MB       = '1024' # Resizable BAR GPU upload heap for windows (proven sweet spot on RTX 40-series)
    VICTORY_WC_BAR               = '1'    # map write-combined buffers directly in RTX 4080 Resizable BAR (no CPU twin, no hashes/compares!)
    VICTORY_VIEW_KNOWN           = '1'    # skip redundant kernel checks on known guarded view memory
    VICTORY_ARM_SPAN             = '4'    # coalesce VirtualProtect TLB shootdowns across small clean gaps
    VICTORY_CAS                  = $Cas.ToString([System.Globalization.CultureInfo]::InvariantCulture)
}
if ($NoWcBar) {
    $set.Remove('VICTORY_WC_BAR')
}
if ($Tiled -and -not $NoTiled) {
    $set.VICTORY_TILED = '1'
    $set.VICTORY_TILED_MB = '4096'
    $set.VICTORY_TILED_MIN_KB = '1024'
}
if ($NoThin) {
    $set.Remove('VICTORY_THIN')
    $set.Remove('VICTORY_THIN_THREADS')
}
if ($Hooks -and -not $NoHooks) {
    $set.VICTORY_GPU_ONLY = '1'
    $set.VICTORY_KNOWN_WRITES = '1'
}
if ($ProbeRays -and -not $RayTracing) {
    $set.VICTORY_PROBE_RAYS = '1'
    $set.VICTORY_PLANE_NOW = '1'
    $set.VICTORY_AMBIENT_FLOOR = '0.035'   # subtle moonlit floor so night ground doesn't crush to pitch black
} elseif (-not $RayTracing) {
    $set.VICTORY_AMBIENT = '0.8'
    $set.VICTORY_AMBIENT_AIR = '0.6'       # trimmed from 1.5 to reduce washed-out haze and deepen blacks
    $set.VICTORY_AMBIENT_SHADE = '0.5,0.4' # contact-shadow crease contrast
    $set.VICTORY_AMBIENT_FLOOR = '0.035'   # subtle moonlit floor so night ground doesn't crush to pitch black
    $set.VICTORY_AMBIENT_SPECULAR = '1'    # reflections stand-in (from trustno1-coder/VIctory-NVIDIA)
}
if ($RayTracing) { $set.VICTORY_BVH_BUILDER = '1' }
if ($AutoA -gt 0) { $set.VICTORY_AUTO_A = "$AutoA" }

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
Write-Host "Log: $logPath"
$ErrorActionPreference = 'Continue'
& $exe run $Game --execute --console $Console 2>&1 | Tee-Object -FilePath $logPath
exit $LASTEXITCODE
