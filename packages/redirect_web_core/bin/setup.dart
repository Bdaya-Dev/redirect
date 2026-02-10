// CLI tool to copy redirect web assets into the consumer's web/ directory.
//
// Usage:
//   dart run redirect_web_core:setup [--out web] [--with-callback]
//
// This writes (by default):
//   web/redirect_sw.js       -- Service Worker for callback interception
//
// Optionally (--with-callback):
//   web/redirect_callback.js -- BroadcastChannel relay (fallback if SW is not used)
//
// Service Workers CANNOT be created from Blob/data URLs -- they must be served
// from a real same-origin path. This is why the files must be placed in the
// consumer's web/ directory and cannot be auto-injected at runtime.

import 'dart:io';

import 'package:redirect_web_core/redirect_web_core.dart';

void main(List<String> args) {
  final help = args.contains('--help') || args.contains('-h');
  if (help) {
    stdout
      ..writeln('Usage: dart run redirect_web_core:setup [options]')
      ..writeln()
      ..writeln('Copies redirect web assets to your web/ directory.')
      ..writeln()
      ..writeln('Options:')
      ..writeln('  --out <dir>        Output directory (default: web)')
      ..writeln('  --no-sw            Skip redirect_sw.js')
      ..writeln(
        '  --with-callback    Also write redirect_callback.js (fallback)',
      )
      ..writeln('  --force            Overwrite existing files')
      ..writeln('  -h, --help         Show this help');
    return;
  }

  final outIndex = args.indexOf('--out');
  final outDir = (outIndex >= 0 && outIndex + 1 < args.length)
      ? args[outIndex + 1]
      : 'web';
  final noSw = args.contains('--no-sw');
  final withCallback = args.contains('--with-callback');
  final force = args.contains('--force');

  final dir = Directory(outDir);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
    stdout.writeln('Created $outDir/');
  }

  var count = 0;

  void writeFile(String name, String content) {
    final file = File('$outDir/$name');
    if (file.existsSync() && !force) {
      stdout.writeln(
        '  SKIP  $outDir/$name (exists, use --force to overwrite)',
      );
      return;
    }
    file.writeAsStringSync(content);
    stdout.writeln('  WROTE $outDir/$name');
    count++;
  }

  stdout.writeln('redirect_web_core: setting up web assets...');
  stdout.writeln();

  if (!noSw) {
    writeFile('redirect_sw.js', RedirectWebAssets.serviceWorkerJs);
  }
  if (withCallback) {
    writeFile('redirect_callback.js', RedirectWebAssets.callbackJs);
  }

  stdout.writeln();
  if (count > 0) {
    stdout.writeln('Done! $count file(s) written to $outDir/.');
    stdout.writeln();
    stdout.writeln('Next steps:');
    stdout.writeln('  1. Enable auto-registration in your WebRedirectOptions:');
    stdout.writeln(
      '       autoRegisterServiceWorker: true,',
    );
    stdout.writeln(
      '       callbackPath: \'/callback.html\',',
    );
    stdout.writeln(
      '  2. Set your OAuth redirect URI to point to callback.html',
    );
    stdout.writeln(
      '  3. Commit the generated files to version control',
    );
  } else {
    stdout.writeln('No files written. All assets already exist.');
  }
}
