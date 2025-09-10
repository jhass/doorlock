import 'package:pocketbase/pocketbase.dart';
import 'env_config.dart';

class PB {
  static PocketBase? _instance;
  
  static PocketBase get instance {
    return _instance ??= PocketBase(EnvConfig.pocketBaseUrl);
  }
}
