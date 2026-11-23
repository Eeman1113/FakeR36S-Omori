# Installing and building FakeR36S-Omori

Two routes. Take the prebuilt release if you just want to play. Build it yourself if you want to
change the engine or the patches.

Everything here assumes a **fake R36S / GA36-MB board with an Allwinner A23** running
[FakeR36S-OS](https://github.com/Eeman1113/FakeR36S-OS). If your console has four CPU cores it is an
A33 or a real RK3326 and none of this applies.

---

## Before you start

**Free up space.** This is the thing most likely to bite you. The Android APK is about 686 MB and
unpacks to roughly 878 MB, and both exist at once during the first launch.

```sh
df -h /Volumes/HOME        # macOS, with the card plugged in
```

You want **1.6 GB free** or more. If you are short, prune some ROMs first.

**Have your own copy of OMORI.** Nothing of the game ships here. Either:

| Edition | What you need |
| --- | --- |
| Android | your `.apk` |
| PC | the `www/` folder and its matching `Launch_OMORI.bat`, together |

---

## Route 1: the prebuilt release

1. Download `FakeR36S-Omori-*.zip` from [Releases](../../releases).
2. Extract it at the **root of the card's HOME partition**, not inside `ports/`. The zip carries its
   own folder structure.

   ```sh
   unzip FakeR36S-Omori-0.0.3.zip -d /Volumes/HOME/
   ```

   Afterwards you should have all three of these:

   ```
   /Volumes/HOME/ports/omori/run.sh
   /Volumes/HOME/.local/share/applications/omori.puppy
   /Volumes/HOME/.local/share/icons/omori.png
   ```

3. Copy your game in:

   ```sh
   cp "OMORI-v1-0-8-1.apk" /Volumes/HOME/ports/omori/original/
   ```

   Keep your own copy of the APK. The launcher deletes the staged one after a successful extract.

4. Eject properly, then put the card back in the console.

   ```sh
   sync && diskutil eject /Volumes/HOME
   ```

5. Open **OMORI** from the **Ports** menu. The first launch unpacks the game and takes several
   minutes behind the spinner. Later launches are quick.

### A macOS warning

Copying to a FAT32 card from macOS leaves `._` companion files next to everything. They keep the
original extension, so EmulationStation lists them as games and they fail instantly when opened.
Clean them up before ejecting:

```sh
dot_clean -m /Volumes/HOME
find /Volumes/HOME -name '._*' -delete
```

---

## Route 2: build it yourself

You need **Zig 0.15.2** and git. There is no cross toolchain to install: Zig brings its own, and it
cross-compiles to 32-bit ARM from macOS or Linux without help.

```sh
# macOS, Apple Silicon
curl -LO https://ziglang.org/download/0.15.2/zig-aarch64-macos-0.15.2.tar.xz
tar -xf zig-aarch64-macos-0.15.2.tar.xz
export PATH="$PWD/zig-aarch64-macos-0.15.2:$PATH"

# Linux x86_64
curl -LO https://ziglang.org/download/0.15.2/zig-x86_64-linux-0.15.2.tar.xz
tar -xf zig-x86_64-linux-0.15.2.tar.xz
export PATH="$PWD/zig-x86_64-linux-0.15.2:$PATH"

zig version      # must print 0.15.2
```

Then:

```sh
git clone https://github.com/Eeman1113/FakeR36S-Omori
cd FakeR36S-Omori
./build.sh 0.0.3
```

That fetches OMORI ReZig, applies the two 32-bit ARM patches, compiles for
`arm-linux-gnueabihf` with `-Dcpu=cortex_a7` so NEON and VFPv4 are used, and writes
`out/FakeR36S-Omori-0.0.3.zip`. Install that exactly as in Route 1.

Takes about a minute on an M-series Mac. Check it produced the right thing:

```sh
unzip -p out/FakeR36S-Omori-0.0.3.zip ports/omori/bin/omori-native > /tmp/e && file /tmp/e
# want: ELF 32-bit LSB executable, ARM, EABI5
```

### Changing the engine

The Zig source lives in the upstream project, not here. This repo carries only the patches:

```
patches/rezig/0001-32-bit-arm-usize-atomics.patch
patches/rezig/0002-32-bit-arm-puthex-index.patch
```

`build.sh` clones upstream into `work/rezig/`, so you can edit there, rerun the Zig build by hand,
and regenerate a patch with `git -C work/rezig diff > patches/rezig/0003-your-change.patch`.

---

## If it does not work

Read the logs on the card, in this order:

| File | Covers |
| --- | --- |
| `ports/omori/logs/short.txt` | start here, the summary |
| `ports/omori/logs/extract.log` | unpacking your APK or PC data |
| `ports/omori/logs/runtime.log` | crashes and anything after the game opens |
| `ports/omori/logs/launcher.log` | the launcher itself |

**The one line that matters most** is in `runtime.log`:

```
renderer: SOFTWARE renderer active
```

If you see that, the Mali-400 accelerated path failed and nothing else is worth tuning until it
works. Upstream's own watchdog gives up after 10 seconds in that state. Report it with the log
rather than trying to work around it.

Other quick checks:

- Nothing in the Ports menu? Confirm `ports/omori/run.sh` exists and is executable
  (`chmod +x`), since `fr-ports-sync` skips entries whose command is not runnable.
- Fails during the first launch? Usually space. Check `df -h` on HOME.
- Runs but stutters? See the tuning note below before assuming it is the CPU.

## Tuning

`run.sh` already pins the CPU with `cpuprofile max` (turbo on, clock held at the top) for as long as
the game is open, and restores it on exit.

The one knob worth touching is the image cache. Upstream defaults to 48 MiB:

```sh
OMORI_IMAGE_CACHE_MIB=32   # less memory, more re-decoding
OMORI_IMAGE_CACHE_MIB=64   # fewer re-decodes, more memory
```

Bigger is not automatically better here. The board has 512 MB in total, and once it starts swapping
through zram you lose far more frames than decoding ever cost you. Change it in `ports/omori/run.sh`
and measure before keeping it.

## Status

Upstream ReZig is at 0.0.1 and verifies only the opening and recruitment routes. This port adds a
new CPU architecture on top of that and **has not yet been run on hardware by anyone**. Treat it as
something to test. [Report what you find](../../issues), working or not.
