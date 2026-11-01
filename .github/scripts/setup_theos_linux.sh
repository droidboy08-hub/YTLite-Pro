#!/usr/bin/env bash
# Prepares a Theos checkout at $THEOS for building iOS tweaks on x86_64 Linux: installs the
# iOS toolchain, the iPhoneOS 16.5 SDK and the @available runtime helper (see
# os_version_check.m). Needs the packages listed in the Theos docs for Debian/Ubuntu:
#   build-essential fakeroot rsync curl perl zip git libxml2 libtinfo6
set -euo pipefail

scripts="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
toolchain="$THEOS/toolchain/linux/iphone/bin"
sdk="$THEOS/sdks/iPhoneOS16.5.sdk"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

if [ ! -x "$toolchain/clang" ]; then
  echo "Installing the iOS toolchain"
  curl -fsSL https://github.com/L1ghtmann/llvm-project/releases/latest/download/iOSToolchain-x86_64.tar.xz \
    | tar -xJf - -C "$THEOS/toolchain/"
fi

if [ ! -d "$sdk" ]; then
  echo "Installing the iPhoneOS 16.5 SDK"
  git clone --quiet -n --depth=1 --filter=tree:0 https://github.com/theos/sdks/ "$work/sdks"
  git -C "$work/sdks" sparse-checkout set --no-cone iPhoneOS16.5.sdk
  git -C "$work/sdks" checkout --quiet
  mv "$work/sdks/iPhoneOS16.5.sdk" "$THEOS/sdks/"
fi

runtime="$("$toolchain/clang" -print-resource-dir)/lib/darwin/libclang_rt.ios.a"
if [ ! -f "$runtime" ]; then
  echo "Installing the @available runtime helper"
  mkdir -p "$(dirname "$runtime")"
  slices=()
  for arch in arm64 arm64e; do
    if "$toolchain/clang" -c -Os -x objective-c -target "$arch-apple-ios13.0" -isysroot "$sdk" \
        "$scripts/os_version_check.m" -o "$work/os_version_check_$arch.o"; then
      "$toolchain/libtool" -static -o "$work/libclang_rt.ios_$arch.a" "$work/os_version_check_$arch.o"
      slices+=("$work/libclang_rt.ios_$arch.a")
    elif [ "$arch" = arm64 ]; then
      exit 1
    fi
  done
  if [ "${#slices[@]}" -gt 1 ]; then
    "$toolchain/lipo" -create "${slices[@]}" -output "$runtime"
  else
    cp "${slices[0]}" "$runtime"
  fi
fi

echo "Theos is ready for Linux builds: $("$toolchain/clang" --version | head -n 1)"
