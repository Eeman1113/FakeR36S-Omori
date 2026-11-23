# FakeR36S-Omori

**OMORI running natively on the fake R36S / GA36-MB handheld (Allwinner A23: two Cortex-A7 cores,
Mali-400, 512 MB) under [FakeR36S-OS](https://github.com/Eeman1113/FakeR36S-OS). Bring your own copy
of the game.**

This is a 32-bit ARM build of [**OMORI ReZig**](https://github.com/josepilas/OMORI-ReZig) by
**José Pilas**, who did the hard part: a native engine, written in Zig, that reads OMORI's maps,
dialogue, art and audio from your own game files and runs them without RPG Maker. That matters here,
because OMORI is an RPG Maker MV game and its real runtime is a browser engine. On two A7 cores with
512 MB of RAM, that was never going to happen. A native engine can.

Upstream targets the **real** R36S, which is an ARM64 Cortex-A35, and ships through PortMaster.
The fake board is 32-bit ARMv7 and FakeR36S-OS has its own Ports system, so this repo adds the two
patches needed to compile for ARMv7 and a launcher that fits FakeR36S-OS.

## Install

1. Download `FakeR36S-Omori-*.zip` from [Releases](../../releases).
2. Extract it into `ports/` on the card's **HOME** partition, so `ports/omori/run.sh` exists.
3. Put your own game into `ports/omori/original/`:
   - **Android:** copy your `.apk` in. Keep your own copy, the launcher deletes the staged one
     after a successful extract.
   - **PC:** copy `www/` and its matching `Launch_OMORI.bat` in together.
4. Open **OMORI** from the Ports menu. The first start prepares the game and takes a while.

**Nothing of the game is in this repository.** You supply it.

### Space

The Android APK is about 686 MB and unpacks to roughly 878 MB. Make sure HOME has at least 1.6 GB
free before the first launch, since the APK and the extracted data both exist for a while.

## Controls

| Input | Action |
| --- | --- |
| D-pad or left stick | Walk, navigate menus |
| A | Interact, confirm, advance dialogue |
| B or Start | Back, or the field menu once the story allows it |
| X | Hold to dash |
| Hold Y, left or right | Pick the party leader when tagging is enabled |
| L or R | Page up and down |
| Select + Start | Exit |

## What the 32-bit patches do

| Patch | Why |
| --- | --- |
| `0001-32-bit-arm-usize-atomics` | Three counters used `std.atomic.Value(u64)`. ARMv7 has no inline 64-bit atomic load or read-modify-write, so Zig refuses to emit them. `usize` is still 64-bit on aarch64, so upstream behaviour does not change. |
| `0002-32-bit-arm-puthex-index` | The crash handler's `putHex` indexed a lookup table with a `u64`. On aarch64 `usize` *is* `u64` so it compiled; on ARMv7 it needs a cast. The value is always 0 to 15. |

Both are portability fixes rather than fork-only hacks, and are offered upstream.

## Building

Needs **Zig 0.15.2** and git. No cross toolchain: Zig brings its own.

```sh
./build.sh 0.0.1
```

Fetches ReZig, applies the patches, builds `omori-native` for `arm-linux-gnueabihf` with
`-Dcpu=cortex_a7` (so NEON and VFPv4 are used), and packages the port into `out/`.

## Status

**Early.** Upstream ReZig is itself at 0.0.1 and verifies only the opening and recruitment routes;
later story branches, minigames and some battle mechanics are unconfirmed. This port adds a new CPU
architecture on top of that, so treat it as something to test rather than to rely on.
[Report what you find](../../issues).

## Credits

**OMORI ReZig and the R36S port it builds on are by [José Pilas](https://github.com/josepilas).
OMORI is by OMOCAT and team. Project-owned engine code is available under MPL 2.0. The game and its
assets belong to their respective rights holders.**

[Upstream licence](https://github.com/josepilas/OMORI-ReZig/blob/main/LICENSE) ·
[Upstream third-party notices](https://github.com/josepilas/OMORI-ReZig/blob/main/docs/THIRD_PARTY.md)

This repository contributes only the 32-bit ARM build and a FakeR36S-OS launcher. Every line of the
engine is José Pilas's work, and the hard part (an RPG Maker runtime rewritten natively, which is
the only reason this is possible on a 512 MB handheld) was done before this repo existed.

- **[OMORI ReZig](https://github.com/josepilas/OMORI-ReZig)** by **José Pilas**: the engine. MPL-2.0.
- **OMOCAT and team**: OMORI itself. No game data ships here, you supply your own copy.
- **[goodluckOS](https://github.com/CodeZombie/goodluckOS)** by **CodeZombie** and contributors:
  the base of FakeR36S-OS, including the reverse engineered display and gamepad drivers that make
  this board run Linux at all.
- The bundled `licenses/` folder carries the notices for SDL2, dr_mp3, dr_wav, LZString, PySDL2 and
  the RPG Maker MV runtime, shipped unmodified from upstream.

Engine code stays under **MPL-2.0**, as upstream. The two portability patches in `patches/` are
offered back to the ReZig project.
