import 'package:fpv_overlay_app/domain/models/update_info.dart';

abstract class UpdateService {
  Future<UpdateInfo?> checkForUpdate(String currentVersion);
}
