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

download_and_verify "MWCWallet.xcframework.zip"

mkdir -p "$LIB_ROOT/macos/framework"
rm -rf "$LIB_ROOT/macos/framework/MWCWallet.xcframework"
unzip -q "$TMPDIR/MWCWallet.xcframework.zip" -d "$TMPDIR/xcfw"
cp -r "$TMPDIR/xcfw/MWCWallet.xcframework" "$LIB_ROOT/macos/framework/MWCWallet.xcframework"
