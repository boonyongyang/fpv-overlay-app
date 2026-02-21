import 'package:file_selector/file_selector.dart';

class PickerService {
  Future<String?> pickDirectory({String? initialDirectory}) async {
    return await getDirectoryPath(
      initialDirectory: initialDirectory,
      confirmButtonText: 'Select Folder',
    );
  }

  Future<List<String>> pickFiles({
    String? initialDirectory,
    List<String>? extensions,
    String? label,
    bool allowMultiple = false,
  }) async {
    final typeGroup = extensions != null
        ? XTypeGroup(label: label ?? 'Files', extensions: extensions)
        : null;

    if (allowMultiple) {
      final files = await openFiles(
        initialDirectory: initialDirectory,
        acceptedTypeGroups: typeGroup != null ? [typeGroup] : [],
      );
      return files.map((f) => f.path).toList();
    } else {
      final file = await openFile(
        initialDirectory: initialDirectory,
        acceptedTypeGroups: typeGroup != null ? [typeGroup] : [],
      );
      return file != null ? [file.path] : [];
    }
  }
}
