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
    grep "^[0-9a-f]*  ${asset}$" "$TMPDIR/checksums.txt" | (cd "$TMPDIR" && shasum -a 256 -c)
}

download_and_verify "libmwc_wallet-ios-aarch64.a"
mkdir -p "$LIB_ROOT/ios/libs"
cp "$TMPDIR/libmwc_wallet-ios-aarch64.a" "$LIB_ROOT/ios/libs/libmwc_wallet.a"

download_and_verify "libmwc_wallet.h"
mkdir -p "$LIB_ROOT/ios/include"
cp "$TMPDIR/libmwc_wallet.h" "$LIB_ROOT/ios/include/libmwc_wallet.h"
