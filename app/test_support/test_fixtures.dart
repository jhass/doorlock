import 'package:pocketbase/pocketbase.dart';

import 'mock_ha_server.dart';

/// Seed helpers for test data. All methods use [adminClient] so they bypass
/// PocketBase collection access rules.
class TestFixtures {
  final PocketBase adminClient;
  final MockHomeAssistantServer mockHa;

  TestFixtures({required this.adminClient, required this.mockHa});

  /// Creates a user in [doorlock_users] and returns their ID.
  Future<String> createUser({
    String email = 'testuser@test.local',
    String password = 'testpassword',
  }) async {
    final record = await adminClient.collection('doorlock_users').create(body: {
      'email': email,
      'password': password,
      'passwordConfirm': password,
    });
    return record.id;
  }

  /// Returns a [PocketBase] client authenticated as the given user.
  Future<PocketBase> userClient({
    String email = 'testuser@test.local',
    String password = 'testpassword',
  }) async {
    final pb = PocketBase(adminClient.baseUrl);
    await pb.collection('doorlock_users').authWithPassword(email, password);
    return pb;
  }

  /// Creates a [doorlock_homeassistants] record pointing at [mockHa],
  /// with a valid access token that won't expire for a year.
  /// Returns the record ID.
  Future<String> createHomeAssistant(String userId) async {
    final record =
        await adminClient.collection('doorlock_homeassistants').create(body: {
      'url': mockHa.baseUrl,
      'owner': userId,
      'access_token': 'test-token',
      'access_token_expires_at': '2099-01-01 00:00:00.000Z',
      'refresh_token': 'test-refresh',
    });
    return record.id;
  }

  /// Creates a [doorlock_locks] record and returns the full record JSON
  /// (including the auto-generated [identification_token]).
  Future<Map<String, dynamic>> createLock(String haId) async {
    final record = await adminClient.collection('doorlock_locks').create(body: {
      'homeassistant': haId,
      'entity_id': 'lock.front_door',
      'name': 'Front Door',
    });
    return record.toJson();
  }

  /// Creates a [doorlock_grants] record valid by default (now-1h to now+24h,
  /// unlimited usage). Returns the full record JSON including [token].
  Future<Map<String, dynamic>> createGrant(
    String lockId, {
    DateTime? notBefore,
    DateTime? notAfter,
    int usageLimit = -1,
    String name = 'Test Grant',
  }) async {
    final nb = (notBefore ?? DateTime.now().subtract(const Duration(hours: 1)))
        .toUtc();
    final na =
        (notAfter ?? DateTime.now().add(const Duration(hours: 24))).toUtc();
    final record = await adminClient.collection('doorlock_grants').create(body: {
      'lock': lockId,
      'name': name,
      'not_before': _pbDate(nb),
      'not_after': _pbDate(na),
      'usage_limit': usageLimit,
    });
    return record.toJson();
  }

  /// Formats a [DateTime] as PocketBase's expected date string.
  static String _pbDate(DateTime dt) {
    final u = dt.toUtc();
    return '${u.year.toString().padLeft(4, '0')}-'
        '${u.month.toString().padLeft(2, '0')}-'
        '${u.day.toString().padLeft(2, '0')} '
        '${u.hour.toString().padLeft(2, '0')}:'
        '${u.minute.toString().padLeft(2, '0')}:'
        '${u.second.toString().padLeft(2, '0')}.000Z';
  }
}
