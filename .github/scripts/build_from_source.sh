#!/usr/bin/env bash
# Builds the YTLite Pro tweak from this checkout with Theos ($THEOS must be set).
# The sources import ../YouTubeHeader and ../protobuf, so the pinned dependencies are
# cloned next to the checkout. The .deb ends up in packages/.
set -euo pipefail
export GIT_TERMINAL_PROMPT=0

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
deps="$(dirname "$repo")"

# Revisions the code was checked against.
clone_at() { # <url> <directory> <commit>
  [ -d "$deps/$2" ] && return
  git clone --quiet "$1" "$deps/$2"
  git -C "$deps/$2" checkout --quiet "$3"
}

echo "::group::Fetch pinned dependencies"
clone_at https://github.com/PoomSmart/YouTubeHeader.git YouTubeHeader 4b9977e2b243fcb143395e0a20d975a32eaa93e0
if [ ! -d "$deps/protobuf" ]; then
  git clone --quiet --depth=1 --branch v27.3 --filter=blob:none --sparse \
    https://github.com/protocolbuffers/protobuf.git "$deps/protobuf"
  git -C "$deps/protobuf" sparse-checkout set objectivec
fi
clone_at https://github.com/roothide/libroothide.git libroothide 7764c54759009272b4f2f23c18c62b21794fe6dd
# roothide.h falls back to no-op stubs for rootful/rootless builds.
mkdir -p "$THEOS/include/roothide"
cp "$deps/libroothide/roothide-theos.h" "$THEOS/include/roothide.h"
cp "$deps/libroothide/roothide.h" "$deps/libroothide/stub.h" "$THEOS/include/roothide/"
echo "::endgroup::"

cd "$repo"
# messages=yes prints every command, so a failure or stall shows exactly where it happened.
make clean package DEBUG=0 FINALPACKAGE=1 messages=yes
