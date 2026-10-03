#!/bin/sh
# Strata, ported to run on this PC: NVIDIA Volta (Tesla V100, sm_70) + a CPU without AVX2.
# Clones https://github.com/Niko1221/Strata, applies the port's in-file changes (strata-port.patch),
# reuses the prebuilt engine when it matches, and runs the normal setup.  Everything else (venv,
# llama.cpp, the already-downloaded model in Strata-data) is picked up by setup itself.
#
#   ./install.sh [target-dir] [extra setup.sh args...]     e.g.  ./install.sh ~/Strata --yes
#
# Needs: git, an NVIDIA driver (580+), the CUDA 12.x toolkit only if the engine has to be rebuilt
# (nvcc 12.4 here: /usr/bin/nvcc), ~1 GB of disk for the checkout on top of the model's folder.
set -e

PIN_COMMIT=db4f91a1171d697928b0d2e1f50ef95e25559d4c   # the commit this patch was made against
HERE=$(cd "$(dirname "$0")" && pwd)
DEST=${1:-$HERE/Strata}
[ $# -gt 0 ] && shift

# ---- 1. the checkout, at the pinned commit (the patch does not claim to fit any other)
if [ -d "$DEST/.git" ]; then
  echo "==> using the existing checkout in $DEST"
else
  echo "==> cloning Strata into $DEST ..."
  git clone https://github.com/Niko1221/Strata.git "$DEST"
  git -C "$DEST" checkout --quiet "$PIN_COMMIT"
fi

# ---- 2. the port itself: every changed file, as one patch (applied once, kept if already in)
if git -C "$DEST" apply --reverse --check "$HERE/strata-port.patch" 2>/dev/null; then
  echo "==> the port is already applied"
else
  git -C "$DEST" apply "$HERE/strata-port.patch"
  echo "==> port applied (AVX2-free CPU experts + Volta engine notes)"
fi

# ---- 3. the engine compiled here for sm_70: reused when this checkout is the pinned commit, so
#         setup's own source fingerprint matches; a mismatch is no risk - setup rebuilds it
if [ ! -x "$DEST/engine/strata" ] && [ -f "$HERE/engine/strata" ] &&
   [ "$(git -C "$DEST" rev-parse HEAD)" = "$PIN_COMMIT" ]; then
  mkdir -p "$DEST/engine"
  cp -p "$HERE/engine/strata" "$HERE/engine/BUILD.json" "$DEST/engine/"
  echo "==> the prebuilt V100 engine was copied in (setup double-checks it and compiles if unsure)"
fi

# ---- 4. install and start (the model files in Strata-data, the packs and the MTP layer are found
#         where they already are; --yes answers every question, --no-start only installs)
cd "$DEST"
echo "==> running setup (first time: the Python venv, llama.cpp, the model config; then it starts"
echo "    the server on http://127.0.0.1:8080 - closing this window stops the model) ..."
exec env STRATA_EXPERIMENTAL_SM60=1 ./setup.sh --family unsloth --model UD-Q4_K_XL "$@"
