import 'package:overlay_core/overlay_core.dart';

import 'package:fpv_overlay_app/core/utils/path_resolver.dart';

class PathResolverRuntime implements OverlayRuntime {
  const PathResolverRuntime();

  @override
  String get ffmpegPath => PathResolver.ffmpegPath;

  @override
  String get osdScriptPath => PathResolver.osdScriptPath;

  @override
  String get pythonPath => PathResolver.pythonPath;

  @override
  String get srtScriptPath => PathResolver.srtScriptPath;

  @override
  String? get bundledOsdExecutablePath => PathResolver.bundledOsdExecutablePath;

  @override
  String? get bundledSrtExecutablePath => PathResolver.bundledSrtExecutablePath;

  @override
  String? get o3OverlayToolPath => PathResolver.o3OverlayToolPath;
}
