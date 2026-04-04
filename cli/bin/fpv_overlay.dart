import 'dart:io';

import 'package:fpv_overlay_cli/src/app.dart';

Future<void> main(List<String> args) async {
  exitCode = await runCli(args);
}
