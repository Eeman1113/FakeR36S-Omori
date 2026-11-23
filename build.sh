#!/bin/bash
# Build OMORI ReZig for the fake R36S (GA36-MB, Allwinner A23: 32-bit ARM, Cortex-A7, Mali-400)
# and package it as a FakeR36S-OS port. Needs Zig 0.15.2 and git. No cross toolchain: Zig brings
# its own. Usage:  ./build.sh [version]
set -euo pipefail
VERSION=${1:-0.0.1}
REZIG_REF=${REZIG_REF:-v0.0.1}
HERE=$(cd "$(dirname "$0")" && pwd)
OUT="$HERE/out"; WORK="$HERE/work"
TARGET=arm-linux-gnueabihf.2.31      # armhf, glibc 2.31 floor: runs on newer too
CPU=cortex_a7                        # the A23's core: NEON + VFPv4

rm -rf "$WORK" "$OUT"; mkdir -p "$WORK" "$OUT"

echo "==> fetching OMORI ReZig $REZIG_REF"
git clone -q --depth 1 --branch "$REZIG_REF" https://github.com/josepilas/OMORI-ReZig.git "$WORK/rezig"

echo "==> applying the 32-bit ARM patches"
for p in "$HERE"/patches/rezig/*.patch; do
    echo "    $(basename "$p")"
    git -C "$WORK/rezig" apply "$p"
done

echo "==> building omori-native for $TARGET ($CPU)"
( cd "$WORK/rezig/runtime" && zig build -Dtarget="$TARGET" -Dcpu="$CPU" -Doptimize=ReleaseFast )

file "$WORK/rezig/runtime/zig-out/bin/omori-native" | grep -q "ELF 32-bit.*ARM" \
    || { echo "!! not a 32-bit ARM binary"; exit 1; }

echo "==> packaging the port"
# The zip extracts at the root of HOME, which is the layout fr-ports-sync expects:
#   ports/<id>/                              the port itself
#   .local/share/applications/<id>.puppy     the Ports menu entry it reads
#   .local/share/icons/<id>.png              the icon that entry points at
PKG="$WORK/pkg"
PORT="$PKG/ports/omori"
mkdir -p "$PORT" "$PKG/.local/share/applications" "$PKG/.local/share/icons"

cp -r "$WORK/rezig/omori/." "$PORT/" 2>/dev/null || true
cp "$WORK/rezig/OMORI.sh" "$PORT/"

# Best effort strip: smaller binary means less to page in on a 512 MB board. Never fatal,
# zig objcopy does not implement every mode for every target.
mkdir -p "$PORT/bin"
SRC="$WORK/rezig/runtime/zig-out/bin/omori-native"
zig objcopy --strip-debug "$SRC" "$PORT/bin/omori-native" 2>/dev/null \
  || llvm-strip -o "$PORT/bin/omori-native" "$SRC" 2>/dev/null \
  || { cp "$SRC" "$PORT/bin/omori-native"; echo "    (unstripped: no working strip for armhf here)"; }
chmod +x "$PORT/bin/omori-native"

cp "$HERE/app/run.sh" "$PORT/run.sh"; chmod +x "$PORT/run.sh" "$PORT/OMORI.sh"
sed "s/@VERSION@/$VERSION/" "$HERE/app/omori.puppy" > "$PKG/.local/share/applications/omori.puppy"
cp "$HERE/app/icon.png" "$PKG/.local/share/icons/omori.png"

mkdir -p "$PORT/original"
cat > "$PORT/original/PUT-YOUR-GAME-HERE.txt" <<'TXT'
Put your own OMORI here, then open OMORI from the Ports menu.

  Android : copy your .apk into this folder. Keep your own copy, the launcher
            deletes the staged one after a successful extract.
  PC      : copy www/ and its Launch_OMORI.bat in here together.

Nothing of the game ships with this port.
TXT

# the launcher resolves the engine as <port>/bin/omori-native; fail loudly rather than ship a dud
[ -x "$PORT/bin/omori-native" ] || { echo "!! bin/omori-native missing: OMORI.sh would not find it"; exit 1; }
[ -f "$PKG/.local/share/applications/omori.puppy" ] || { echo "!! the Ports menu entry is missing"; exit 1; }
[ -f "$PKG/.local/share/icons/omori.png" ] || { echo "!! the icon is missing"; exit 1; }

( cd "$PKG" && zip -qr "$OUT/FakeR36S-Omori-$VERSION.zip" ports .local )
echo "==> $OUT/FakeR36S-Omori-$VERSION.zip"
ls -lh "$OUT"
