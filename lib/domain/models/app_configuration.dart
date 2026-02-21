class AppConfiguration {
  final String? lastUsedInputDirectory;
  final String? lastUsedOutputDirectory;
  final String? defaultOutputDirectory;

  const AppConfiguration({
    this.lastUsedInputDirectory,
    this.lastUsedOutputDirectory,
    this.defaultOutputDirectory,
  });

  AppConfiguration copyWith({
    String? lastUsedInputDirectory,
    String? lastUsedOutputDirectory,
    String? defaultOutputDirectory,
  }) {
    return AppConfiguration(
      lastUsedInputDirectory:
          lastUsedInputDirectory ?? this.lastUsedInputDirectory,
      lastUsedOutputDirectory:
          lastUsedOutputDirectory ?? this.lastUsedOutputDirectory,
      defaultOutputDirectory:
          defaultOutputDirectory ?? this.defaultOutputDirectory,
    );
  }
}
