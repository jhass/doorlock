import 'package:pocketbase/pocketbase.dart';
import 'env_config.dart';

class PB {
  static final PocketBase instance = PocketBase(EnvConfig.pocketBaseUrl);
}
