import 'dart:io';

import 'package:test/test.dart';

void main() async {
  if (Platform.isWindows) {
    group('build_windows', () {
      test('make dll + execute', () async {
        await Process.run('cmd', ['./make_clean.bat']);
        // "C:\Program Files\CMake\bin\cmake.exe" -G Ninja -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc -DTARGET_PLATFORM=WINDOWS -DTARGET_ARCH=x86_64 .
        var cmake = await Process.run(
          'cmake',
          [
            '-G',
            'Ninja',
            //'-DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc',
            '-DTARGET_PLATFORM=WINDOWS',
            '-DTARGET_ARCH=x86_64',
            '-DDART_SDK_PATH=D:/dev_tools/flutter/bin/cache/dart-sdk',
            '.',
          ],
        );
        expect(cmake.exitCode, 0);

        // run 'ninja'
        var make = await Process.run(
          'ninja',
          [],
        );
        expect(make.exitCode, 0);
        Process.run('cmd', ['./make_clean.bat']);
      });
    });
  }
  if (Platform.isMacOS) {
    group('build_macos', () {
      test('make dylib arm64', () async {
        await Process.run('sh', ['./make_clean.sh']);
        // run 'cmake .'
        // cmake -DTARGET_PLATFORM=NATIVE -DTARGET_ARCH=arm64
        var cmake = await Process.run(
          'cmake',
          [
            '-DTARGET_PLATFORM=NATIVE',
            '-DTARGET_ARCH=arm64',
            '.',
          ],
        );
        expect(cmake.exitCode, 0);

        // run 'make'
        var make = await Process.run(
          'make',
          [],
        );
        expect(make.exitCode, 0);
      });
      test('make dylib arm64', () async {
        await Process.run('sh', ['./make_clean.sh']);
        // run 'cmake .'
        // cmake -DTARGET_PLATFORM=NATIVE -DTARGET_ARCH=arm64
        var cmake = await Process.run(
          'cmake',
          [
            '-DTARGET_PLATFORM=NATIVE',
            '-DTARGET_ARCH=x86_64',
            '.',
          ],
        );
        expect(cmake.exitCode, 0);

        // run 'make'
        var make = await Process.run(
          'make',
          [],
        );
        expect(make.exitCode, 0);
        Process.run('sh', ['./make_clean.sh']);
      });
    });
  }
  if (Platform.isLinux) {
    group('build_linux', () {
      test('make dylib + execute', () async {
        await Process.run('sh', ['./make_clean.sh']);
        // run 'cmake .'
        // cmake -DTARGET_PLATFORM=NATIVE -DTARGET_ARCH=arm64
        var cmake = await Process.run(
          'cmake',
          [
            '-DTARGET_PLATFORM=LINUX',
            '-DTARGET_ARCH=x86_64',
            '.',
          ],
        );
        expect(cmake.exitCode, 0);

        // run 'make'
        var make = await Process.run(
          'make',
          [],
        );
        expect(make.exitCode, 0);
        Process.run('sh', ['./make_clean.sh']);
      });
    });
  }
}
