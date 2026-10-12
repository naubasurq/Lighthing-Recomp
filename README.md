# Lighthing-Recomp

A native port of **Final Fantasy XIII (Xbox 360)** built by statically recompiling the original PowerPC executable to C++ with the [ReXGlue SDK](https://github.com/rexglue/rexglue-sdk). The goal is to run the game natively on modern hardware: desktop Linux first, then Android, and iOS as a long shot.

> **Status: early work in progress, Linux only.** The game boots, gets past the Square Enix logo and renders 3D gameplay with correct textures. It is **not playable yet**: there is no in-game music or effects (only cutscene audio), Lightning's hair and the minimap are corrupted, characters can flicker, and performance is poor.

This repository contains **no game code and no game data**. You need your own copy of the game (see [Legal](#legal)).

## Goals

1. Run the Xbox 360 build of Final Fantasy XIII natively on x86-64 Linux.
2. Fix rendering, audio and stability until the game is fully playable start to finish.
3. Make the renderer and runtime fast enough for modest hardware.
4. Port it to **Android** (budget CPUs and SoCs) and, if feasible, **iOS**.

## How it works

- `default.xex` (Title ID `535107E4`, Media ID `602A3E5A`, version 0.0.0.2) is translated function by function into C++ by `rexglue codegen`, driven by `ffxiii_manifest.toml`.
- The ReXGlue runtime (derived from [Xenia](https://github.com/xenia-canary/xenia-canary)) provides the Xbox 360 kernel and XAM emulation, the Xenos GPU on Vulkan, audio and the virtual file system.
- This repository supplies what the toolchain cannot discover by itself: the manifest with function boundaries and indirect-call thunks, the small application entry point, build presets, helper scripts and the SDK patches we depend on.

## Status

| Area | State |
|---|---|
| Codegen of `default.xex` | Done, builds and links |
| Boot | Gets past the Square Enix logo and into the game |
| 3D rendering | Environments and characters draw with correct textures |
| Textures | Fixed. They were nearly black because of an SDK shader translator bug (see below) |
| Hair, minimap, character flicker | Broken. Hair draws as flickering multicolored noise, the minimap is corrupted |
| Audio | Cutscene audio only. Music and effects are silent (XMA contexts are created but never kicked) |
| Performance | Poor. Stutters, still to be profiled |
| Stability | Some code paths hit unresolved branches (a manifest fix is pending testing) |
| Android | Not started |
| iOS | Not started |

There is no completion percentage because nothing has been measured against a full playthrough. Roughly: the engine runs and draws the game world, and everything after that (audio, polish, performance, other platforms) is still ahead.

## Fixes so far

**Black textures.** Every texture was multiplied by a value close to zero. The SPIR-V translator applied the texture exponent adjust (`exp_adjust`) by reading it from dword 4 of the texture fetch constant, but the field lives in dword 3 (bits 13-18). Dword 4 holds the LOD bias and other fields, so the extracted value was a large negative exponent. The patch in [`patches/rexglue-sdk/`](patches/rexglue-sdk) loads dword 3 instead. It affects every game that uses `exp_adjust`, not just this one.

**Disappearing characters and textures.** Caused by bypassing the global critical region lock in the function dispatcher during an experiment. With the lock restored, objects stay visible.

## Known issues

- **Audio:** the game creates its XMA decoder contexts but never kicks them, so nothing is decoded. A game thread keeps writing to an unknown XMA register (`0x601`) in a tight loop. Under investigation.
- **Unresolved branch near `0x8257CC98`:** a manifest entry split a loop into two functions and the codegen emitted a fatal unresolved branch, which killed the game. A fix is in the manifest and is being tested.
- **Hair:** flickering multicolored noise on Lightning's hair. Probably a texture format, render target or vertex fetch problem.
- **Minimap:** corrupted. Probably related to render-to-texture.
- **Stutter:** waits in the runtime poll with 1 ms sleeps, adding latency to every synchronization.
- **Debug builds** are far too slow to judge anything. Always test with the Release preset.

## Roadmap

### Linux desktop
- [x] Boot into the game
- [x] Fix black textures
- [x] Fix disappearing characters
- [ ] Working music and effects (XMA)
- [ ] Fix hair, flicker and minimap
- [ ] Replace polling waits with blocking waits
- [ ] Pipeline cache to remove shader compilation stutter
- [ ] Complete a full playthrough without crashes

### Android
The plan is to reuse the recompiled code and the Vulkan renderer on Android, targeting budget CPUs and SoCs. This is the hardest goal in the project, so expectations are modest:
- Mobile Vulkan drivers may lack extensions the renderer relies on, which would need alternative render target paths.
- The desktop build uses around 1.6 GB of resident memory.
- Low-end hardware may never reach a playable frame rate.

The first milestone is a test build that boots, to learn exactly which features are missing.

### iOS
Aspirational. Static recompilation avoids the JIT restrictions that block most emulators on iOS, which is a real advantage. The obstacles are a Vulkan-to-Metal layer (such as MoltenVK), distribution and the same performance limits as Android. No work has started.

## Requirements

- Linux x86-64 with a Vulkan capable GPU (developed on CachyOS).
- Your own copy of Final Fantasy XIII for Xbox 360, with `default.xex` and its data files extracted.
- The ReXGlue SDK 0.10.x, built from source with the patches in `patches/rexglue-sdk/` applied.
- CMake, Ninja, Clang and Git.

## Building

```sh
# 1. Build and install the ReXGlue SDK with our patches applied
git clone https://github.com/rexglue/rexglue-sdk && cd rexglue-sdk
git apply /path/to/Lighthing-Recomp/patches/rexglue-sdk/*.patch
cmake --preset linux-amd64 && cmake --build --preset linux-amd64-release -j4
cmake --install out/build/linux-amd64 --config Release --prefix $HOME/rexglue-sdk/out/install/linux-amd64
cd -

# 2. Generate the recompiled sources from your default.xex
rexglue codegen ffxiii_manifest.toml --force --ignore-stamp

# 3. Configure and build the game (Release strongly recommended)
cmake --preset linux-amd64-release
cmake --build --preset linux-amd64-release -j4
```

The runtime and GPU plugin libraries (`librexruntime.so`, `librexgpu-xenos.so`) must sit next to the executable or be on `LD_LIBRARY_PATH`.

## Running

```sh
cd out/build/linux-amd64-release
./ffxiii --game_data_root=/path/to/game/data --gpu_plugin=xenos
```

Useful flags: `--log_file=<path>`, `--log_verbose=true`, `--log_noisy=true` (needed to see XMA and audio activity).

## Troubleshooting

- **Textures are black:** the SDK was built without the `exp_adjust` patch. Apply it, rebuild, reinstall the SDK and relink the game.
- **Nothing changes after rebuilding the SDK:** the game loads its own copy of `librexruntime.so` from the build directory. Copy the freshly installed library next to the executable.
- **`error while loading shared libraries`:** copy `librexruntime.so` and `librexgpu-xenos.so` from the SDK install `lib/` folder next to the executable.
- **Very low performance:** make sure you are running the Release build, not Debug.
- **The game dies with `Unresolved branch`:** an address is missing from the manifest. Report it with the log line.

## Repository layout

| Path | What |
|---|---|
| `ffxiii_manifest.toml` | Codegen manifest: function boundaries and thunks |
| `src/` | Application entry point |
| `CMakeLists.txt`, `CMakePresets.json` | Build configuration |
| `patches/rexglue-sdk/` | Fixes carried on top of the ReXGlue SDK |
| `tools/` | Helper scripts used during development |
| `generated/` | Codegen output. **Not committed** (translated game code) |

## Contributing

Bug reports are most useful with a RenderDoc capture, a log file and a description of what you see on screen. The areas where help matters most are the shader translator, XMA audio and the runtime wait implementation.

## Legal

This project is not affiliated with, endorsed by or sponsored by Square Enix or Microsoft. *Final Fantasy* is a trademark of Square Enix.

The repository distributes no copyrighted game material: no executables, no recompiled game code, and no assets. The build only works with game files extracted from a copy you legally own.

## Credits

- [ReXGlue SDK](https://github.com/rexglue/rexglue-sdk): recompiler and runtime
- [Xenia](https://github.com/xenia-canary/xenia-canary): the emulator whose kernel, GPU and audio research the runtime builds on
- [XenonRecomp](https://github.com/hedge-dev/XenonRecomp): the pioneering Xbox 360 static recompiler

## License

The code in this repository is released under the MIT License. This does not cover the game, its assets, or the third-party SDKs and tools it uses.
