import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:overlay_core/overlay_core.dart';
import 'package:path/path.dart' as p;

import 'runtime/cli_runtime.dart';

const _cliVersion = String.fromEnvironment(
  'fpv_overlay_cli_version',
  defaultValue: '1.0.1',
);

Future<int> runCli(List<String> args) async {
  if (args.isEmpty || args.first == 'help' || args.first == '--help') {
    _printGlobalHelp();
    return 0;
  }

  if (args.first == '--version' || args.first == 'version') {
    stdout.writeln('fpv-overlay $_cliVersion');
    return 0;
  }

  final runtime = CliRuntime();
  switch (args.first) {
    case 'render':
      return _runRender(args.sublist(1), runtime);
    case 'batch':
      return _runBatch(args.sublist(1), runtime);
    case 'doctor':
      return _runDoctor(args.sublist(1), runtime);
    default:
      stderr.writeln('Unknown command: ${args.first}');
      _printGlobalHelp();
      return 2;
  }
}

Future<int> _runRender(List<String> args, CliRuntime runtime) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('video')
    ..addOption('srt')
    ..addOption('osd')
    ..addOption('output')
    ..addOption('output-dir')
    ..addFlag('overwrite', negatable: false)
    ..addFlag('dry-run', negatable: false)
    ..addFlag('verbose', negatable: false);

  final results = _parseArgs(parser, args);
  if (results == null) return 2;
  if (results['help'] == true) {
    stdout.writeln(_renderHelp(parser));
    return 0;
  }

  final videoPath = results['video'] as String?;
  final srtPath = results['srt'] as String?;
  final osdPath = results['osd'] as String?;
  final explicitOutput = results['output'] as String?;
  final outputDir = results['output-dir'] as String?;
  final overwrite = results['overwrite'] == true;
  final dryRun = results['dry-run'] == true;

  if (videoPath == null || videoPath.isEmpty) {
    stderr.writeln('Missing required option: --video');
    return 2;
  }
  if ((srtPath == null || srtPath.isEmpty) &&
      (osdPath == null || osdPath.isEmpty)) {
    stderr.writeln('At least one of --srt or --osd is required.');
    return 2;
  }
  if (!File(videoPath).existsSync()) {
    stderr.writeln('Video file not found: $videoPath');
    return 2;
  }
  if (srtPath != null && srtPath.isNotEmpty && !File(srtPath).existsSync()) {
    stderr.writeln('SRT file not found: $srtPath');
    return 2;
  }
  if (osdPath != null && osdPath.isNotEmpty && !File(osdPath).existsSync()) {
    stderr.writeln('OSD file not found: $osdPath');
    return 2;
  }

  final planner = OverlayTaskPlanner();
  final outputPath = _resolveOutputPath(
    planner: planner,
    explicitOutput: explicitOutput,
    outputDir: outputDir,
    videoPath: videoPath,
    overwrite: overwrite,
  );

  final task = OverlayTask(
    id: 'render',
    videoPath: videoPath,
    srtPath: _nullIfEmpty(srtPath),
    osdPath: _nullIfEmpty(osdPath),
    status: TaskStatus.pending,
  );

  stdout.writeln('Mode: ${task.type.name}');
  stdout.writeln('Video: $videoPath');
  if (task.srtPath != null) stdout.writeln('SRT: ${task.srtPath}');
  if (task.osdPath != null) stdout.writeln('OSD: ${task.osdPath}');
  stdout.writeln('Output: $outputPath');

  if (dryRun) {
    stdout.writeln('Dry run complete.');
    return 0;
  }

  return _executeSingleTask(task, runtime, outputPath);
}

Future<int> _runBatch(List<String> args, CliRuntime runtime) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('input-dir')
    ..addOption('output-dir')
    ..addFlag('overwrite', negatable: false)
    ..addFlag('dry-run', negatable: false)
    ..addFlag('verbose', negatable: false);

  final results = _parseArgs(parser, args);
  if (results == null) return 2;
  if (results['help'] == true) {
    stdout.writeln(_batchHelp(parser));
    return 0;
  }

  final inputDir = results['input-dir'] as String?;
  final overwrite = results['overwrite'] == true;
  final dryRun = results['dry-run'] == true;
  if (inputDir == null || inputDir.isEmpty) {
    stderr.writeln('Missing required option: --input-dir');
    return 2;
  }
  if (!Directory(inputDir).existsSync()) {
    stderr.writeln('Input directory not found: $inputDir');
    return 2;
  }

  final resolvedOutputDir =
      (results['output-dir'] as String?) ?? p.join(inputDir, 'renders');
  final engine = EngineService();
  final planner = OverlayTaskPlanner();
  final tasks = await engine.findFilePairs(inputDir);

  final renderable = tasks
      .where(
        (task) =>
            task.status == TaskStatus.pending ||
            task.status == TaskStatus.failed,
      )
      .toList();
  final partial = tasks.length - renderable.length;

  stdout.writeln('Discovered ${tasks.length} task(s).');
  stdout.writeln('Renderable: ${renderable.length}');
  stdout.writeln('Partial: $partial');
  stdout.writeln('Output directory: $resolvedOutputDir');

  for (final task in tasks) {
    stdout.writeln(
      '- ${task.videoFileName} | ${task.status.name} | ${task.type.name}',
    );
  }

  if (dryRun) {
    stdout.writeln('Dry run complete.');
    return 0;
  }

  Directory(resolvedOutputDir).createSync(recursive: true);

  int completed = 0;
  int failed = 0;
  for (final task in renderable) {
    final preferredName =
        '${p.basenameWithoutExtension(task.videoFileName)}_overlay.mp4';
    final outputPath = overwrite
        ? p.join(resolvedOutputDir, preferredName)
        : planner.getUniqueOutputPath(resolvedOutputDir, preferredName);

    stdout.writeln('');
    stdout.writeln('==> ${task.videoFileName}');
    final code = await _executeSingleTask(task, runtime, outputPath);
    if (code == 0) {
      completed++;
    } else {
      failed++;
    }
  }

  stdout.writeln('');
  stdout.writeln('Batch summary');
  stdout.writeln('Completed: $completed');
  stdout.writeln('Failed: $failed');
  stdout.writeln('Partial inputs skipped: $partial');

  return failed > 0 ? 1 : 0;
}

Future<int> _runDoctor(List<String> args, CliRuntime runtime) async {
  final parser = ArgParser()..addFlag('help', abbr: 'h', negatable: false);
  final results = _parseArgs(parser, args);
  if (results == null) return 2;
  if (results['help'] == true) {
    stdout.writeln(_doctorHelp(parser));
    return 0;
  }

  stdout.writeln('fpv-overlay $_cliVersion');
  stdout.writeln('Executable: ${runtime.executablePath}');
  stdout.writeln('Runtime dir: ${runtime.runtimeDirectory ?? 'Not found'}');
  stdout.writeln('FFmpeg: ${runtime.ffmpegPath}');
  stdout.writeln('FFprobe: ${runtime.ffprobePath}');
  stdout.writeln(
    'OSD runtime: ${runtime.bundledOsdExecutablePath ?? runtime.osdScriptPath}',
  );
  stdout.writeln(
    'SRT runtime: ${runtime.bundledSrtExecutablePath ?? runtime.srtScriptPath}',
  );

  final checks = <String, Future<bool>>{
    'ffmpeg': _checkCommand(runtime.ffmpegPath, const ['-version']),
    'ffprobe': _checkCommand(runtime.ffprobePath, const ['-version']),
    'osd-overlay': _checkOverlayInvocation(
      runtime,
      runtime.bundledOsdExecutablePath,
      runtime.osdScriptPath,
    ),
    'srt-overlay': _checkOverlayInvocation(
      runtime,
      runtime.bundledSrtExecutablePath,
      runtime.srtScriptPath,
    ),
    'temp-dir': _checkTempDirectory(),
  };

  bool hasFailure = false;
  for (final entry in checks.entries) {
    final ok = await entry.value;
    stdout.writeln('${ok ? 'OK' : 'FAIL'} ${entry.key}');
    if (!ok) hasFailure = true;
  }

  return hasFailure ? 3 : 0;
}

Future<int> _executeSingleTask(
  OverlayTask task,
  CliRuntime runtime,
  String outputPath,
) async {
  final runner = CommandRunnerService();
  bool success = false;

  await for (final line in runner.executeTask(task, runtime, outputPath)) {
    stdout.writeln(line);
    if (line.contains('✅ Process completed successfully')) {
      success = true;
    }
  }

  return success ? 0 : 1;
}

ArgResults? _parseArgs(ArgParser parser, List<String> args) {
  try {
    return parser.parse(args);
  } on ArgParserException catch (error) {
    stderr.writeln(error.message);
    return null;
  }
}

String _resolveOutputPath({
  required OverlayTaskPlanner planner,
  required String? explicitOutput,
  required String? outputDir,
  required String videoPath,
  required bool overwrite,
}) {
  if (explicitOutput != null && explicitOutput.isNotEmpty) {
    if (overwrite || !File(explicitOutput).existsSync()) {
      return explicitOutput;
    }
    return planner.getUniqueOutputPath(
      p.dirname(explicitOutput),
      p.basename(explicitOutput),
    );
  }

  final directory = outputDir ?? p.dirname(videoPath);
  final preferredName = '${p.basenameWithoutExtension(videoPath)}_overlay.mp4';
  if (overwrite) {
    return p.join(directory, preferredName);
  }
  return planner.getUniqueOutputPath(directory, preferredName);
}

Future<bool> _checkCommand(String executable, List<String> args) async {
  try {
    final result = await Process.run(executable, args);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

Future<bool> _checkOverlayInvocation(
  CliRuntime runtime,
  String? bundledExecutablePath,
  String scriptPath,
) {
  if (bundledExecutablePath != null) {
    return _checkCommand(bundledExecutablePath, const ['--help']);
  }
  return _checkCommand(runtime.pythonPath, [scriptPath, '--help']);
}

Future<bool> _checkTempDirectory() async {
  try {
    final dir = await Directory.systemTemp.createTemp('fpv-overlay-cli-');
    await dir.delete(recursive: true);
    return true;
  } catch (_) {
    return false;
  }
}

String? _nullIfEmpty(String? value) {
  if (value == null || value.isEmpty) return null;
  return value;
}

void _printGlobalHelp() {
  stdout.writeln('fpv-overlay $_cliVersion');
  stdout.writeln('');
  stdout.writeln('Commands:');
  stdout.writeln('  render   Render one video with SRT and/or OSD telemetry');
  stdout.writeln('  batch    Scan one folder and render all valid tasks');
  stdout.writeln('  doctor   Validate the local runtime');
  stdout.writeln('');
  stdout.writeln('Global flags:');
  stdout.writeln('  --help');
  stdout.writeln('  --version');
}

String _renderHelp(ArgParser parser) => '''
Render one video with SRT and/or OSD telemetry.

Usage:
  fpv-overlay render --video clip.mp4 --srt clip.srt [--osd clip.osd]

Options:
${parser.usage}
''';

String _batchHelp(ArgParser parser) => '''
Scan a folder and render all valid tasks.

Usage:
  fpv-overlay batch --input-dir ./flight-pack [--output-dir ./renders]

Options:
${parser.usage}
''';

String _doctorHelp(ArgParser parser) => '''
Validate the local runtime.

Usage:
  fpv-overlay doctor

Options:
${parser.usage}
''';
