/// Load a desktop release library and check its C ABI without creating a wallet.
library;

import 'dart:ffi';
import 'dart:io';

import 'package:args/args.dart';
import 'package:ffi/ffi.dart';

void smoke(File file) {
  final library = DynamicLibrary.open(file.absolute.path);
  try {
    final mnemonic = library
        .lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>(
          'mwc_get_mnemonic',
        )();
    if (mnemonic == nullptr ||
        mnemonic.toDartString().trim().split(RegExp(r'\s+')).length != 24) {
      throw StateError('Mnemonic ABI smoke test failed');
    }
    final openWallet = library
        .lookupFunction<
          Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>),
          Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>)
        >('mwc_rust_open_wallet');
    final freeString = library
        .lookupFunction<
          Void Function(Pointer<Utf8>),
          void Function(Pointer<Utf8>)
        >('mwc_string_free');
    final config = '{}'.toNativeUtf8();
    final password = 'unused'.toNativeUtf8();
    try {
      for (var index = 0; index < 100; index++) {
        final pointer = openWallet(config, password);
        if (pointer == nullptr) {
          throw StateError('Open-wallet ABI returned null');
        }
        try {
          if (!pointer.toDartString().contains('Unable to get wallet config')) {
            throw StateError('Open-wallet error ABI smoke test failed');
          }
        } finally {
          freeString(pointer);
        }
      }
    } finally {
      calloc.free(config);
      calloc.free(password);
    }
    stdout.writeln(
      'Native library loaded; mnemonic and error/free ABI checks passed',
    );
  } finally {
    library.close();
  }
}

void main(List<String> arguments) {
  final parser = ArgParser()..addFlag('help', abbr: 'h', negatable: false);
  try {
    final args = parser.parse(arguments);
    if (args.flag('help')) {
      stdout.writeln('Usage: smoke_prebuilt.dart <library>\n${parser.usage}');
      return;
    }
    if (args.rest.length != 1) {
      throw const FormatException('Supply exactly one native library path');
    }
    smoke(File(args.rest.single));
  } on FormatException catch (error) {
    stderr.writeln('${error.message}\nUsage: smoke_prebuilt.dart <library>');
    exitCode = 64;
  } catch (error) {
    stderr.writeln('Native smoke test failed: $error');
    exitCode = 1;
  }
}
