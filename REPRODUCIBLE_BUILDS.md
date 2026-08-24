# Reproducible native builds

The Nix build produces the Linux `libmwc_wallet.so` with Rust 1.85.1,
matching Stack Wallet's toolchain selection. `flake.lock` pins nixpkgs and the
Rust overlay; the fixed Cargo vendor hash pins crates.io and all Git sources
resolved by `rust/Cargo.lock`, including dependencies whose manifests still
refer to branch names.

```sh
nix build .#mwc-wallet
./nix/verify-reproducible.sh
```

Debug paths are removed, sandbox paths are remapped, and
`SOURCE_DATE_EPOCH` is fixed. The verifier requests a clean rebuild and fails
if its output differs.

Only Linux is covered. Android, Windows, and Apple SDK inputs need separate
pinned cross-compilation derivations.
