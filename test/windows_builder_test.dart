import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:test/test.dart';

import '../hook/src/windows_builder.dart';

void main() {
  test(
    'locked staging does not turn a verified build into a failure',
    () async {
      final directory = await Directory.systemTemp.createTemp('mwc-cleanup-');
      final file = await File.fromUri(directory.uri.resolve('held.txt'))
          .writeAsString('held');
      final kernel = DynamicLibrary.open('kernel32.dll');
      final open = kernel
          .lookupFunction<
            IntPtr Function(
              Pointer<Utf16>,
              Uint32,
              Uint32,
              Pointer<Void>,
              Uint32,
              Uint32,
              IntPtr,
            ),
            int Function(Pointer<Utf16>, int, int, Pointer<Void>, int, int, int)
          >('CreateFileW');
      final close = kernel
          .lookupFunction<Int32 Function(IntPtr), int Function(int)>(
            'CloseHandle',
          );
      final path = file.path.toNativeUtf16();
      final handle = open(path, 0x80000000, 1, nullptr, 3, 0, 0);
      calloc.free(path);
      expect(handle, isNot(-1));
      try {
        // FILE_SHARE_READ deliberately excludes FILE_SHARE_DELETE.
        expect(await cleanupWindowsStaging(directory), isFalse);
        expect(await file.readAsString(), 'held');
      } finally {
        close(handle);
      }
      expect(await cleanupWindowsStaging(directory), isTrue);
      expect(await directory.exists(), isFalse);
    },
    skip: !Platform.isWindows,
  );
}
