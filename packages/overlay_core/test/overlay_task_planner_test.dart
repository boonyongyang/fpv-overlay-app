import 'package:file/memory.dart';
import 'package:overlay_core/overlay_core.dart';
import 'package:test/test.dart';

void main() {
  late MemoryFileSystem fs;
  late OverlayTaskPlanner planner;

  setUp(() {
    fs = MemoryFileSystem();
    planner = OverlayTaskPlanner(fileSystem: fs);
  });

  test('merges missing telemetry task with incoming SRT task', () {
    final tasks = <OverlayTask>[
      OverlayTask(
        id: 'video',
        videoPath: '/data/flight01.mp4',
        status: TaskStatus.missingTelemetry,
      ),
    ];

    final result = planner.mergeIncoming(tasks, <OverlayTask>[
      OverlayTask(
        id: 'srt',
        srtPath: '/data/flight01.srt',
        status: TaskStatus.missingVideo,
      ),
    ]);

    expect(result.addedCount, 1);
    expect(tasks.single.status, TaskStatus.pending);
    expect(tasks.single.srtPath, '/data/flight01.srt');
  });

  test('creates unique output paths when the preferred one already exists', () {
    fs.file('/out/clip_overlay.mp4').createSync(recursive: true);

    final resolved = planner.getUniqueOutputPath('/out', 'clip_overlay.mp4');

    expect(resolved, '/out/clip_overlay_1.mp4');
  });
}
