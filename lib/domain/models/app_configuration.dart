/// Sentinel value used to distinguish "not passed" from "passed null" in
/// [AppConfiguration.copyWith].
const _absent = Object();

class AppConfiguration {
  final String? lastUsedInputDirectory;
  final String? lastUsedOutputDirectory;
  final String? defaultOutputDirectory;
  final String? o3OverlayToolPath;
  final bool hasCompletedOnboarding;
  final List<String> recentInputDirectories;
  final List<String> recentOutputDirectories;

  const AppConfiguration({
    this.lastUsedInputDirectory,
    this.lastUsedOutputDirectory,
    this.defaultOutputDirectory,
    this.o3OverlayToolPath,
    this.hasCompletedOnboarding = false,
    this.recentInputDirectories = const [],
    this.recentOutputDirectories = const [],
  });

  AppConfiguration copyWith({
    Object? lastUsedInputDirectory = _absent,
    Object? lastUsedOutputDirectory = _absent,
    Object? defaultOutputDirectory = _absent,
    Object? o3OverlayToolPath = _absent,
    Object? hasCompletedOnboarding = _absent,
    Object? recentInputDirectories = _absent,
    Object? recentOutputDirectories = _absent,
  }) {
    return AppConfiguration(
      lastUsedInputDirectory: identical(lastUsedInputDirectory, _absent)
          ? this.lastUsedInputDirectory
          : lastUsedInputDirectory as String?,
      lastUsedOutputDirectory: identical(lastUsedOutputDirectory, _absent)
          ? this.lastUsedOutputDirectory
          : lastUsedOutputDirectory as String?,
      defaultOutputDirectory: identical(defaultOutputDirectory, _absent)
          ? this.defaultOutputDirectory
          : defaultOutputDirectory as String?,
      o3OverlayToolPath: identical(o3OverlayToolPath, _absent)
          ? this.o3OverlayToolPath
          : o3OverlayToolPath as String?,
      hasCompletedOnboarding: identical(hasCompletedOnboarding, _absent)
          ? this.hasCompletedOnboarding
          : hasCompletedOnboarding as bool,
      recentInputDirectories: identical(recentInputDirectories, _absent)
          ? this.recentInputDirectories
          : List<String>.unmodifiable(
              recentInputDirectories as List<String>,
            ),
      recentOutputDirectories: identical(recentOutputDirectories, _absent)
          ? this.recentOutputDirectories
          : List<String>.unmodifiable(
              recentOutputDirectories as List<String>,
            ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppConfiguration &&
        other.lastUsedInputDirectory == lastUsedInputDirectory &&
        other.lastUsedOutputDirectory == lastUsedOutputDirectory &&
        other.defaultOutputDirectory == defaultOutputDirectory &&
        other.o3OverlayToolPath == o3OverlayToolPath &&
        other.hasCompletedOnboarding == hasCompletedOnboarding &&
        _listsEqual(
          other.recentInputDirectories,
          recentInputDirectories,
        ) &&
        _listsEqual(
          other.recentOutputDirectories,
          recentOutputDirectories,
        );
  }

  @override
  int get hashCode => Object.hash(
        lastUsedInputDirectory,
        lastUsedOutputDirectory,
        defaultOutputDirectory,
        o3OverlayToolPath,
        hasCompletedOnboarding,
        Object.hashAll(recentInputDirectories),
        Object.hashAll(recentOutputDirectories),
      );

  @override
  String toString() => 'AppConfiguration('
      'lastUsedInputDirectory: $lastUsedInputDirectory, '
      'lastUsedOutputDirectory: $lastUsedOutputDirectory, '
      'defaultOutputDirectory: $defaultOutputDirectory, '
      'o3OverlayToolPath: $o3OverlayToolPath, '
      'hasCompletedOnboarding: $hasCompletedOnboarding, '
      'recentInputDirectories: $recentInputDirectories, '
      'recentOutputDirectories: $recentOutputDirectories)';
}

bool _listsEqual(List<String> left, List<String> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (int index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
