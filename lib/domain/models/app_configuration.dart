/// Sentinel value used to distinguish "not passed" from "passed null" in
/// [AppConfiguration.copyWith].
const _absent = Object();

class AppConfiguration {
  final String? lastUsedInputDirectory;
  final String? lastUsedOutputDirectory;
  final String? defaultOutputDirectory;
  final String? o3OverlayToolPath;
  final bool analyticsEnabled;

  const AppConfiguration({
    this.lastUsedInputDirectory,
    this.lastUsedOutputDirectory,
    this.defaultOutputDirectory,
    this.o3OverlayToolPath,
    this.analyticsEnabled = true,
  });

  AppConfiguration copyWith({
    Object? lastUsedInputDirectory = _absent,
    Object? lastUsedOutputDirectory = _absent,
    Object? defaultOutputDirectory = _absent,
    Object? o3OverlayToolPath = _absent,
    bool? analyticsEnabled,
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
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
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
        other.analyticsEnabled == analyticsEnabled;
  }

  @override
  int get hashCode => Object.hash(
        lastUsedInputDirectory,
        lastUsedOutputDirectory,
        defaultOutputDirectory,
        o3OverlayToolPath,
        analyticsEnabled,
      );

  @override
  String toString() => 'AppConfiguration('
      'lastUsedInputDirectory: $lastUsedInputDirectory, '
      'lastUsedOutputDirectory: $lastUsedOutputDirectory, '
      'defaultOutputDirectory: $defaultOutputDirectory, '
      'o3OverlayToolPath: $o3OverlayToolPath, '
      'analyticsEnabled: $analyticsEnabled)';
}
