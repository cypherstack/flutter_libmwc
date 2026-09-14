#!/usr/bin/env python3
"""Fail closed if a native Linux prebuilt cannot meet the release ABI contract."""
import json
import re
import subprocess
import sys


def audit(path):
    def readelf(*flags):
        return subprocess.check_output(["readelf", *flags, path], text=True, env={"PATH": __import__("os").environ["PATH"], "LC_ALL": "C"})

    header = readelf("-h")
    if not re.search(r"Class:\s+ELF64", header) or not re.search(r"Machine:\s+Advanced Micro Devices X86-64", header) or not re.search(r"Type:\s+DYN", header):
        raise ValueError("expected an x86_64 ELF shared library")
    dynamic = readelf("-d")
    needed = sorted(set(re.findall(r"\(NEEDED\).*\[([^\]]+)\]", dynamic)))
    allowed = {"libc.so.6", "libm.so.6", "libdl.so.2", "libpthread.so.0", "librt.so.1", "libgcc_s.so.1", "ld-linux-x86-64.so.2"}
    if not needed or set(needed) - allowed:
        raise ValueError(f"unexpected shared dependencies: {needed}")
    if re.search(r"\((?:RPATH|RUNPATH)\)", dynamic) or "/nix/store/" in dynamic:
        raise ValueError("release library contains a runtime search path")
    versions = readelf("--version-info")
    glibc = sorted({tuple(map(int, v.split("."))) for v in re.findall(r"GLIBC_(\d+\.\d+)", versions)})
    if not glibc or glibc[-1] > (2, 35) or "GLIBC_PRIVATE" in versions:
        raise ValueError(f"glibc requirements exceed the public 2.35 ABI: {glibc}")
    symbols = readelf("--dyn-syms", "--wide")
    for symbol in ("mwc_get_mnemonic", "mwc_rust_open_wallet", "mwc_string_free"):
        if not re.search(rf"GLOBAL\s+DEFAULT\s+\d+\s+{symbol}$", symbols, re.MULTILINE):
            raise ValueError(f"missing C ABI export: {symbol}")
    return {"target": "x86_64-unknown-linux-gnu", "maximum_glibc": ".".join(map(str, glibc[-1])), "needed": needed, "rpath": None}


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: audit_linux.py LIBRARY")
    try:
        print(json.dumps(audit(sys.argv[1]), indent=2, sort_keys=True))
    except (ValueError, subprocess.CalledProcessError) as error:
        sys.exit(f"Linux ABI audit failed: {error}")
