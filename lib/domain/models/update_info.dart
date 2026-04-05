class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.releaseUrl,
    required this.publishedAt,
    required this.artifactUrl,
    required this.sha256,
  });

  final String version;
  final String releaseUrl;
  final String publishedAt;
  final String artifactUrl;
  final String sha256;
}
