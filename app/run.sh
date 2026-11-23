#!/bin/sh
# FakeR36S-OS entry point for OMORI ReZig (the Ports menu entry's COMMAND).
# Upstream ships a PortMaster launcher; this supplies the few things PortMaster would:
# $ESUDO, a sane HOME, and the CPU profile. The engine and its data preparation are
# unchanged from upstream.  https://github.com/Eeman1113/FakeR36S-Omori
cd "$(dirname "$(readlink -f "$0")")" || exit 1
[ -d /home/player ] && export HOME=/home/player

# PortMaster exports ESUDO for the root it needs for KMS/DRM master. FakeR36S-OS uses doas.
ESUDO=${ESUDO:-doas}; export ESUDO

# Image cache budget. Upstream defaults to 48 MiB. Bigger means fewer re-decodes and smoother
# scrolling, but this board has 512 MB total and swapping costs far more frames than decoding.
# Raise it only if you have measured headroom; lower it to 32 if you see zram churn.
export OMORI_IMAGE_CACHE_MIB=${OMORI_IMAGE_CACHE_MIB:-48}

# RPG Maker content is layout-heavy and this chip has two cores: run flat out, like Reader.
doas /usr/local/bin/cpuprofile max 2>/dev/null
sh ./OMORI.sh "$@"
rc=$?
doas /usr/local/bin/cpuprofile normal 2>/dev/null
exit $rc
