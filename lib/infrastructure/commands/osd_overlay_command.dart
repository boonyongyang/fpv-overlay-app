import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fpv_overlay_app/domain/commands/overlay_command.dart';
import 'package:fpv_overlay_app/domain/models/app_configuration.dart';
import 'package:fpv_overlay_app/domain/models/overlay_task.dart';
import 'package:fpv_overlay_app/core/utils/path_resolver.dart';

class OsdOverlayCommand implements OverlayCommand {
  @override
  Stream<String> execute(
    OverlayTask task,
    AppConfiguration config,
    String outputPath,
  ) async* {
    final o3ToolPath = PathResolver.o3OverlayToolPath;
    if (o3ToolPath == null || o3ToolPath.isEmpty) {
      yield 'Error: O3_OverlayTool path is not configured.';
      return;
    }

    yield 'Starting OSD Rendering via O3_OverlayTool...';

    final script = '''
import sys
sys.path.insert(0, '$o3ToolPath')
from VideoMaker import VideoMaker
from TransparentVideoMaker import TransparentVideoMaker
from OsdFileReader import OsdFileReader
from pathlib import Path

def main():
    print("Loading OSD...")
    osd_reader = OsdFileReader('${task.overlayPath}', framerate=60)
    
    tool_path = Path('$o3ToolPath')
    font_path = tool_path / 'fonts/WS_BFx4_Nexus_Moonlight_2160p.png'
    if not font_path.exists():
        font_path = tool_path / 'fonts/WS_BTFL_Conthrax_Moonlight_1440p.png'
    
    print("Initializing TransparentVideoMaker...")
    video_maker = TransparentVideoMaker(osd_reader, str(font_path), fps=60)
    
    print("Creating video...")
    video_maker.create_video('$outputPath', '${task.videoPath}')
    print("Done")

if __name__ == '__main__':
    main()
''';

    yield* _streamProcess(PathResolver.pythonPath, ['-c', script]);
  }

  Stream<String> _streamProcess(String executable, List<String> args) async* {
    try {
      yield '\$ $executable ${args.join(' ')}';
      final process = await Process.start(executable, args);
      final controller = StreamController<String>();

      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => controller.add(line));
      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => controller.add('STDERR: $line'));

      process.exitCode.then((code) {
        if (code == 0) {
          controller.add('✅ Process completed successfully.');
        } else {
          controller.add('❌ Process failed with exit code $code.');
        }
        controller.close();
      });

      yield* controller.stream;
    } catch (e) {
      yield '❌ Exception: $e';
    }
  }
}
