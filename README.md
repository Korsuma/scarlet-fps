# Scarlet-FPS

**Runs the title in Xbox Series S mode by default and works in Xbox Series X mode too. With a better GPU, use
Series X (`-Console series-x`) for the better picture.**

A build of the VIctory layer for running your own Xbox Series dump of the title on a Windows PC with an NVIDIA
card. Its aim is to be the most stable public build with the highest frame rate.

It combines three lines of work:

| Part | From | What it gives |
|---|---|---|
| FPS optimisations | this repository | Less CPU time in the copy path and on the submitting thread |
| The base | [Yaekai/victory-scarlett-3070](https://github.com/Yaekai/victory-scarlett-3070), a fork of [Op-lite/victory-scarlett](https://github.com/Op-lite/victory-scarlett) | The scarlett renderer, tuned for NVIDIA cards |
| Lighting and texture fixes | [trustno1-coder/VIctory-NVIDIA](https://github.com/trustno1-coder/VIctory-NVIDIA) | Newer lighting stand-in, reflections stand-in, BC7 texture fix, the open-water fix |

**This repository contains no game files, code or assets.** You need your own copy of the title. It is not
affiliated with or endorsed by the title's developer or publisher.

## What we measured

Same PC (4 cores / 8 threads, RTX A4500 20 GB), Series S mode, standing at the first spawn, release builds:

| | 3070 fork | Scarlet-FPS |
|---|---|---|
| Frame time | 85 ms | 78 ms |
| Submitting thread, preparing | 64 ms | 58 ms |
| Copied back from the card each frame | 21 MB | 0.6 MB |

Of the public builds we have run on this PC, this is the fastest. We have not measured every public build, and
numbers on other hardware will differ.

## Install and run

You need Windows 10 or 11, an NVIDIA RTX card with a recent driver, 32 GB of RAM, [Rust](https://rustup.rs) and
the Visual Studio C++ Build Tools (with the Windows SDK).

1. Build once, from inside this folder:
   ```powershell
   cargo build --release --bin victory
   ```
2. Start the game:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\scarlet-fps.ps1 -Game "C:\path\to\your-game.exe"
   ```

The window title shows `COMPILING SHADERS (n left)` while shaders are being prepared and `WARMED UP` when they
are done. The first start is the slowest; the picture can have black or missing parts until it says `WARMED UP`.
Logs are written to `runs\`.

## Options

Add these to the start command.

| Option | What it does |
|---|---|
| `-Console series-x` | Runs the title as an Xbox Series X: better picture, more work for the card. The default is Series S. The optimisations work in both; on a higher-end GPU choose Series X. |
| `-Res 1920x1080` | The size the title draws for. Default `auto`: your monitor's (the nearest of 3840x2160, 2560x1440, 1920x1080, 1280x720 not above it), so a 1080p screen is not drawn for at 4K. The title draws at 2/3 of it inside (1280x720 for 1080p on Series X). `-Res console` keeps the console's own 4K, the most work for the card. Output-size patch from [LooperSalty/AnyXboxX](https://github.com/LooperSalty/AnyXboxX). |
| `-ProbeRays` | Lights the scene with the title's own light probes instead of the estimate. Brighter, more natural shade and nights; costs a few milliseconds a frame on the card. |
| `-MipDrop 0` | Full texture detail. The default (`1`) drops the top level of large textures to fit 8 GB cards; use `0` with 12 GB or more. |
| `-RayTracing` | The title's own ray tracing. Best light, much slower. |
| `-Prewarm` | Translates all shaders before the first start instead of while playing. |
| `-AutoA 200` | Presses A through the start screens for that many seconds. |

### Frame generation and DLSS (NVIDIA, off by default)

From [Kemerd/VIctory-NVIDIA-RT](https://github.com/Kemerd/VIctory-NVIDIA-RT), through NVIDIA Streamline. Nothing changes
unless one of these is given.

| Option | What it does |
|---|---|
| `-FrameGen 2` | DLSS Frame Generation: frames shown for each one rendered, `2` to `6` (`3` and more need an RTX 50). Needs an RTX 40 or later; on another card it logs why and stays off. Turns on `-Dlss quality` unless `-Dlss` is given. |
| `-Dlss quality` | DLSS in place of the title's own upscaling: `off`, `dlaa`, `quality`, `balanced` or `performance`. Works on RTX 20 and later. In Series X mode frame generation needs it. |
| `-Reflex boost` | NVIDIA Reflex with DLSS or frame generation: `off`, `on` or `boost` (the default). |
| `-StreamlineDir <folder>` | The folder with NVIDIA's Streamline files. Unset: looked for in `nvidia-sdk\Streamline\bin\x64` beside this repository, then under `%LOCALAPPDATA%\victory`. |

NVIDIA's files are not part of this repository. Get the Streamline SDK v2.14.16 from NVIDIA and point
`-StreamlineDir` at its `bin\x64` folder (`sl.interposer.dll`, `sl.common.dll`, `sl.dlss.dll`, `sl.dlss_g.dll`,
`sl.reflex.dll`, `sl.pcl.dll`, `nvngx_dlss.dll`, `nvngx_dlssg.dll`). Without them the build starts as before and says
so in its log.

Example, Series X with frame generation:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\scarlet-fps.ps1 -Game "C:\path\to\your-game.exe" -Console series-x -FrameGen 2 -StreamlineDir "C:\path\to\streamline\bin\x64"
```

## What is different from the 3070 fork

Code:
- Copy-back limit (`VICTORY_GPU_BACK_MAX_KB`): large buffers the title's shaders write stay on the card.
- Title writes handled beside the write guards (`VICTORY_COPY_BESIDE`, `VICTORY_STORE_BESIDE`): fewer write faults.
- The lighting stand-in, reflections stand-in (`VICTORY_AMBIENT_SPECULAR`) and BC7 rotation fix from
  VIctory-NVIDIA.
- Window title with the shader state.
- More switches that are off unless set: `VICTORY_TILED`, `VICTORY_ASK_QUIET`, `VICTORY_VIEW_KNOWN`,
  `VICTORY_ARM_SPAN`, `VICTORY_AMBIENT_ONCE`, `VICTORY_AMBIENT_LEFTOVER`.

Launcher defaults (`scripts\scarlet-fps.ps1`):
- `VICTORY_REFRESH_ONCE=0`: with 1, stretched meshes and corrupted posters.
- The water's two tiled light programs are left out (`5dc3b25986622949`, `6f225b641c5b0708`): on NVIDIA cards
  they leave dark tiles and black foam on open water. The water is a little darker and bluer without them.
- `VICTORY_COPY_BESIDE=1`, `VICTORY_STORE_BESIDE=1`, `VICTORY_GPU_BACK_MAX_KB=1024`, `VICTORY_AMBIENT_SPECULAR=1`.

## Known limits

- About 1,100 pipelines are rebuilt at every start (as in the 3070 fork and VIctory-NVIDIA): loading them from
  disk can give wrong colour grading on NVIDIA cards. On a slow CPU this takes several minutes.
- With the default lighting estimate, deep shade and nights are darker than they should be. `-ProbeRays` is the
  fix for now.
- A first start with an empty shader cache has not been timed on this build.

## Credits and licence

Scarlet-FPS is built on the work of
[Marvisak/VIctory](https://github.com/Marvisak/VIctory),
[fxceless/victory-fork](https://github.com/fxceless/victory-fork),
[Op-lite/victory-scarlett](https://github.com/Op-lite/victory-scarlett),
[Yaekai/victory-scarlett-3070](https://github.com/Yaekai/victory-scarlett-3070),
[trustno1-coder/VIctory-NVIDIA](https://github.com/trustno1-coder/VIctory-NVIDIA) and
[Kemerd/VIctory-NVIDIA-RT](https://github.com/Kemerd/VIctory-NVIDIA-RT) (frame generation, DLSS and Reflex).

Licensed GPL-3.0-or-later, as they are.
