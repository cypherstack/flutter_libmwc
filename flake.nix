{
  description = "Reproducible flutter_libmwc native prebuilts";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    baseline.url = "github:NixOS/nixpkgs/nixos-22.11";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = { self, nixpkgs, baseline, rust-overlay }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; overlays = [ (import rust-overlay) ]; };
      # Only the target C/C++ toolchain uses this baseline, to preserve glibc 2.35.
      targetPkgs = import baseline { inherit system; };
      rustVersion = (builtins.fromTOML (builtins.readFile ./rust/rust-toolchain.toml)).toolchain.channel;
      toolchain = pkgs.rust-bin.stable.${rustVersion}.minimal;
      rustPlatform = pkgs.makeRustPlatform {
        cargo = toolchain;
        rustc = toolchain;
        stdenv = pkgs.overrideCC pkgs.stdenv targetPkgs.stdenv.cc;
      };
      native = rustPlatform.buildRustPackage {
        pname = "mwc-wallet-native";
        version = "0.1.0";
        src = pkgs.lib.cleanSource ./rust;
        cargoHash = "sha256-gcdRzH3tlgUOdPi3BCez/EqoEtyLBBwHB7RPi3ep8io=";
        nativeBuildInputs = with pkgs; [ baseline.legacyPackages.${system}.cmake perl pkg-config protobuf_21 nasm patchelf python3 ];
        cargoBuildFlags = [ "--lib" ];
        doCheck = false;
        auditable = false;
        # The stock cargoBuildHook injects nixpkgs' current compiler through
        # rust.envVars even with a custom stdenv. Use the baseline consistently.
        buildPhase = ''
          runHook preBuild
          cargo build --frozen --release --lib --target x86_64-unknown-linux-gnu --jobs "$NIX_BUILD_CORES"
          runHook postBuild
        '';
        # Release artifacts must not acquire Nix runtime paths or host C++ deps.
        dontFixup = true;
        env = {
          PROTOC = "${pkgs.protobuf_21}/bin/protoc";
          CARGO_INCREMENTAL = "0";
          CARGO_PROFILE_RELEASE_DEBUG = "false";
          CXXSTDLIB_x86_64_unknown_linux_gnu = "static=stdc++";
          SOURCE_DATE_EPOCH = "1";
          TZ = "UTC";
        };
        preBuild = ''
          # Fail if a daemon with sandbox-fallback enabled builds in a host temp
          # directory. This recipe requires the canonical Linux sandbox root.
          test "$NIX_BUILD_TOP" = /build || { echo "Nix sandbox at /build required" >&2; exit 1; }
          export PATH="${targetPkgs.stdenv.cc}/bin:$PATH"
          export CC="${targetPkgs.stdenv.cc}/bin/cc"
          export CXX="${targetPkgs.stdenv.cc}/bin/c++"
          export AR="${targetPkgs.stdenv.cc.bintools}/bin/ar"
          export RANLIB="${targetPkgs.stdenv.cc.bintools}/bin/ranlib"
          export NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE -ffile-prefix-map=$NIX_BUILD_TOP=/build -fdebug-prefix-map=$NIX_BUILD_TOP=/build"
          export RUSTFLAGS="-C debuginfo=0 -C link-arg=-Wl,-z,defs --remap-path-prefix=$NIX_BUILD_TOP=/build -Lnative=${targetPkgs.stdenv.cc.cc}/lib"
        '';
        installPhase = ''
          runHook preInstall
          install -Dm644 target/x86_64-unknown-linux-gnu/release/libmwc_wallet.so $out/lib/libmwc_wallet.so
          install -Dm644 target/x86_64-unknown-linux-gnu/release/libmwc_wallet.a $out/lib/libmwc_wallet.a
          patchelf --remove-rpath $out/lib/libmwc_wallet.so
          python3 ${./reproducible/audit_linux.py} $out/lib/libmwc_wallet.so
          runHook postInstall
        '';
      };
    in {
      packages = (pkgs.lib.genAttrs [ "aarch64-darwin" ] (darwinSystem:
        let darwinPkgs = import nixpkgs { system = darwinSystem; overlays = [ (import rust-overlay) ]; };
        in import ./reproducible/macos/package.nix { pkgs = darwinPkgs; }
      )) // { ${system} = {
        default = native;
        native-linux = native;
        cargo-vendor = native.cargoDeps;
        smoke-linux = targetPkgs.runCommandCC "mwc-native-smoke" {
          nativeBuildInputs = [ pkgs.patchelf ];
        } ''
          mkdir -p $out/bin
          $CC -Wall -Wextra -Werror ${./reproducible/smoke.c} -ldl -o $out/bin/mwc-native-smoke
          patchelf --remove-rpath --set-interpreter /lib64/ld-linux-x86-64.so.2 $out/bin/mwc-native-smoke
        '';
      }; };
      checks.${system}.native-linux = native;
    };
}
