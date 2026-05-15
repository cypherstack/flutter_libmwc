#!/bin/bash
set -e

LIB_ROOT=../..
REPO="cypherstack/flutter_libmwc"
BASE_URL="https://github.com/${REPO}/releases/download"

TAG=$(git -C "$LIB_ROOT" describe --tags --exact-match HEAD 2>/dev/null) || {
    echo "Error: flutter_libmwc is not at a tagged commit."
    echo "Pin the submodule to a release tag to use download mode."
    echo "Current commit: $(git -C "$LIB_ROOT" rev-parse HEAD)"
    exit 1
}

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

curl -fSL "${BASE_URL}/${TAG}/checksums.txt" -o "$TMPDIR/checksums.txt"

download_and_verify() {
    local asset="$1"
    curl -fSL "${BASE_URL}/${TAG}/${asset}" -o "$TMPDIR/${asset}"
    grep "^[0-9a-f]*  ${asset}$" "$TMPDIR/checksums.txt" | (cd "$TMPDIR" && sha256sum -c)
}

WINLIBS="$LIB_ROOT/scripts/windows/build"
mkdir -p "$WINLIBS"

download_and_verify "libmwc_wallet-windows-x86_64.dll"
cp "$TMPDIR/libmwc_wallet-windows-x86_64.dll" "$WINLIBS/libmwc_wallet.dll"

download_and_verify "libstdc++-6.dll"
cp "$TMPDIR/libstdc++-6.dll" "$WINLIBS/libstdc++-6.dll"

download_and_verify "libgcc_s_seh-1.dll"
cp "$TMPDIR/libgcc_s_seh-1.dll" "$WINLIBS/libgcc_s_seh-1.dll"
