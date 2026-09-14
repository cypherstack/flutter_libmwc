{ pkgs }:
let
  target = if pkgs.stdenv.hostPlatform.isAarch64 then "aarch64-apple-darwin" else "x86_64-apple-darwin";
  rustVersion = (builtins.fromTOML (builtins.readFile ../../rust/rust-toolchain.toml)).toolchain.channel;
  toolchain = pkgs.rust-bin.stable.${rustVersion}.minimal;
  sdk = pkgs.apple-sdk_14;
  libcxxHeaders = (pkgs.darwin.libcxx.override { apple-sdk_26 = sdk; }).overrideAttrs {
    version = "apple-sdk-${sdk.version}";
  };
  llvm = pkgs.llvmPackages;
  # Use the SDK's system libc++, not nixpkgs' macOS-14 runtime. All tools
  # themselves may require a newer build host; the payload's floor stays 11.
  compiler = name: executable: pkgs.writeShellScriptBin name ''
    exec ${llvm.clang-unwrapped}/bin/${executable} \
      -isysroot ${sdk.sdkroot} -mmacosx-version-min=11.0 \
      ${pkgs.lib.optionalString (executable == "clang++") "-nostdinc++ -isystem ${libcxxHeaders}/include/c++/v1"} \
      -fuse-ld=${llvm.lld}/bin/ld64.lld "$@"
  '';
  cc = compiler "mwc-cc" "clang";
  cxx = compiler "mwc-cxx" "clang++";
  rustPlatform = pkgs.makeRustPlatform { cargo = toolchain; rustc = toolchain; };
  native = rustPlatform.buildRustPackage {
    pname = "mwc-wallet-native-macos";
    version = "0.1.0";
    src = pkgs.lib.cleanSource ../../rust;
    cargoHash = "sha256-gcdRzH3tlgUOdPi3BCez/EqoEtyLBBwHB7RPi3ep8io=";
    nativeBuildInputs = with pkgs; [ cmake perl pkg-config protobuf_21 nasm python3 ];
    buildInputs = [ sdk ];
    doCheck = false;
    auditable = false;
    dontFixup = true;
    passthru.pinnedInputs = {
      rust = { version = rustVersion; path = toString toolchain; };
      sdk = { version = sdk.version; path = toString sdk; };
      libcxxHeaders = { version = libcxxHeaders.version; path = toString libcxxHeaders; };
      clang = { version = llvm.clang-unwrapped.version; path = toString llvm.clang-unwrapped; };
      linker = { version = llvm.lld.version; path = toString llvm.lld; };
      archiver = { version = llvm.llvm.version; path = toString llvm.llvm; };
      cmake = { version = pkgs.cmake.version; path = toString pkgs.cmake; };
      protoc = { version = pkgs.protobuf_21.version; path = toString pkgs.protobuf_21; };
      perl = { version = pkgs.perl.version; path = toString pkgs.perl; };
      nasm = { version = pkgs.nasm.version; path = toString pkgs.nasm; };
      inherit target;
      deploymentTarget = "11.0";
      cargoHash = "sha256-gcdRzH3tlgUOdPi3BCez/EqoEtyLBBwHB7RPi3ep8io=";
    };
    env = {
      PROTOC = "${pkgs.protobuf_21}/bin/protoc";
      LIBCLANG_PATH = "${llvm.libclang.lib}/lib";
      CARGO_INCREMENTAL = "0";
      CARGO_PROFILE_RELEASE_DEBUG = "false";
      SOURCE_DATE_EPOCH = "1";
      ZERO_AR_DATE = "1";
      TZ = "UTC";
    };
    buildPhase = ''
      runHook preBuild
      export MACOSX_DEPLOYMENT_TARGET=11.0
      export SDKROOT=${sdk.sdkroot}
      export CC=${cc}/bin/mwc-cc CXX=${cxx}/bin/mwc-cxx
      export AR=${llvm.llvm}/bin/llvm-ar RANLIB=${llvm.llvm}/bin/llvm-ranlib
      export CFLAGS="-DMDB_USE_POSIX_MUTEX=1 -DMDB_USE_ROBUST=0 -ffile-prefix-map=$NIX_BUILD_TOP=/build -fdebug-prefix-map=$NIX_BUILD_TOP=/build -fmacro-prefix-map=$NIX_BUILD_TOP=/build"
      export CXXFLAGS="$CFLAGS -stdlib=libc++"
      export RUSTFLAGS="-C debuginfo=0 -C linker=$CC -C link-arg=-Wl,-install_name,@rpath/libmwc_wallet.dylib -C link-arg=-Wl,-no_uuid --remap-path-prefix=$NIX_BUILD_TOP=/build"
      cargo build --frozen --release --lib --target ${target} --jobs "$NIX_BUILD_CORES"
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib
      cp target/${target}/release/libmwc_wallet.{a,dylib} $out/lib/
      python3 ${./audit.py} $out/lib --target ${target}
      runHook postInstall
    '';
  };
in {
  default = native;
  native-macos = native;
  cargo-vendor = native.cargoDeps;
}
