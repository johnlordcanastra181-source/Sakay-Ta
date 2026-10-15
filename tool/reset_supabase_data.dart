/// Safely clears Sakay Ta's user-generated Supabase data.
///
/// This is deliberately a standalone Dart tool. It never runs in Flutter and
/// reads its privileged credential only from the local process environment.
///
/// Dry-run (the default):
///   dart run tool/reset_supabase_data.dart --project-ref=kasgyeaedfbcsrhzcnax --dry-run
///
/// Destructive run (requires an explicit flag):
///   dart run tool/reset_supabase_data.dart --project-ref=kasgyeaedfbcsrhzcnax --confirm-reset
///
/// Required environment variables (do not commit them):
///   SUPABASE_URL=https://kasgyeaedfbcsrhzcnax.supabase.co
///   SUPABASE_SERVICE_ROLE_KEY=`<server-only key>`
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _requiredProjectRef = 'kasgyeaedfbcsrhzcnax';

/// Entries are ordered from dependent records to account records. The filter
/// prevents an accidental unfiltered PostgREST delete request.
const _userDataTables = <_TableTarget>[
  _TableTarget('notifications', 'id=not.is.null'),
  _TableTarget('chat_messages', 'id=not.is.null'),
  _TableTarget('ratings', 'id=not.is.null'),
  _TableTarget('ride_status_history', 'id=not.is.null'),
  _TableTarget('payments', 'id=not.is.null'),
  _TableTarget('wallet_transactions', 'id=not.is.null'),
  _TableTarget('reports', 'id=not.is.null'),
  _TableTarget('driver_earnings', 'id=not.is.null'),
  _TableTarget('withdrawals', 'id=not.is.null'),
  _TableTarget('saved_places', 'id=not.is.null'),
  _TableTarget('bookings', 'id=not.is.null'),
  _TableTarget('driver_documents', 'id=not.is.null'),
  _TableTarget('driver_presence', 'driver_id=not.is.null'),
  _TableTarget('toda_associations', 'id=not.is.null'),
  _TableTarget('rides', 'id=not.is.null'),
  _TableTarget('drivers', 'user_id=not.is.null'),
  _TableTarget('passenger_profiles', 'user_id=not.is.null'),
  _TableTarget('admin_roles', 'user_id=not.is.null'),
  _TableTarget('email_otps', 'id=not.is.null'),
  _TableTarget('magic_links', 'id=not.is.null'),
  _TableTarget('firebase_user_map', 'firebase_uid=not.is.null'),
  _TableTarget('profiles', 'id=not.is.null'),
];

/// These two buckets are created by the Sakay Ta migrations and are reserved
/// for account-owned avatar and driver-verification uploads. Other buckets are
/// reported but never deleted automatically, protecting static assets.
const _userUploadBuckets = <String>{'avatars', 'driver-documents'};

Future<void> main(List<String> arguments) async {
  final options = _ResetOptions.parse(arguments);
  final url = Platform.environment['SUPABASE_URL'];
  final serviceRoleKey = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];

  if (options.projectRef != _requiredProjectRef) {
    _fail('Refusing to run: --project-ref must be $_requiredProjectRef.');
  }
  if (url == null || url.isEmpty) {
    _fail('SUPABASE_URL is required. No network request was made.');
  }
  if (serviceRoleKey == null || serviceRoleKey.isEmpty) {
    _fail(
        'SUPABASE_SERVICE_ROLE_KEY is required. Keep it outside this repository.');
  }

  final baseUrl = Uri.parse(url);
  final actualProjectRef = baseUrl.host.split('.').first;
  if (actualProjectRef != _requiredProjectRef) {
    _fail(
      'Refusing to run: SUPABASE_URL points to "$actualProjectRef", not '
      '$_requiredProjectRef.',
    );
  }

  final api = _SupabaseResetApi(baseUrl, serviceRoleKey);
  try {
    final inventory = await _inventory(api);
    _printInventory(inventory);

    if (!options.confirmReset || options.dryRun) {
      stdout.writeln(
          '\nDRY RUN ONLY: no records, Auth users, buckets, or configuration were changed.');
      stdout.writeln(
          'To execute the irreversible reset, rerun with --confirm-reset.');
      return;
    }

    stdout.writeln(
        '\nRESET STARTED: clearing only the listed user/activity records.');
    stdout.writeln(
        'Preserving tables: fare_config and todas. Preserving all buckets.');

    for (final target in _userDataTables) {
      await api.deleteAllRows(target);
      stdout.writeln('Cleared ${target.table}.');
    }

    for (final bucket in _userUploadBuckets) {
      if (!inventory.bucketObjectCounts.containsKey(bucket)) {
        continue;
      }
      final paths = await api.listAllObjectPaths(bucket);
      await api.deleteObjectPaths(bucket, paths);
      stdout.writeln(
          'Cleared ${paths.length} object(s) from $bucket (bucket retained).');
    }

    final deletedUsers = await api.deleteAllAuthUsers();
    stdout.writeln('Deleted $deletedUsers Supabase Auth user(s).');

    final after = await _inventory(api);
    _printInventory(after, heading: 'POST-RESET INVENTORY');
    final leftovers = after.userDataCounts.entries
        .where((entry) => entry.value != 0)
        .map((entry) => '${entry.key}=${entry.value}')
        .toList();
    if (after.authUsers != 0 || leftovers.isNotEmpty) {
      _fail(
        'Reset stopped: verification found remaining data. '
        'Auth users=${after.authUsers}; tables=${leftovers.join(', ')}.',
      );
    }
    stdout.writeln(
        '\nRESET COMPLETE: all targeted user/activity data and Auth users are zero.');
  } finally {
    api.close();
  }
}

Future<_Inventory> _inventory(_SupabaseResetApi api) async {
  final counts = <String, int>{};
  for (final target in _userDataTables) {
    counts[target.table] = await api.countTableRows(target.table);
  }
  final configCounts = <String, int>{
    'fare_config': await api.countTableRows('fare_config'),
    'todas': await api.countTableRows('todas'),
  };
  final bucketObjectCounts = <String, int>{};
  for (final bucket in await api.listBucketIds()) {
    bucketObjectCounts[bucket] = (await api.listAllObjectPaths(bucket)).length;
  }
  return _Inventory(
    userDataCounts: counts,
    configCounts: configCounts,
    authUsers: (await api.listAuthUsers()).length,
    bucketObjectCounts: bucketObjectCounts,
  );
}

void _printInventory(_Inventory inventory,
    {String heading = 'PRE-RESET INVENTORY'}) {
  stdout.writeln('\n$heading');
  stdout.writeln('Project ref: $_requiredProjectRef');
  stdout.writeln('Auth users: ${inventory.authUsers}');
  stdout.writeln('User/activity tables:');
  for (final entry in inventory.userDataCounts.entries) {
    stdout.writeln('  ${entry.key}: ${entry.value}');
  }
  stdout.writeln('Preserved configuration:');
  for (final entry in inventory.configCounts.entries) {
    stdout.writeln('  ${entry.key}: ${entry.value}');
  }
  stdout.writeln('Storage objects per bucket:');
  if (inventory.bucketObjectCounts.isEmpty) {
    stdout.writeln('  (no buckets found)');
  } else {
    for (final entry in inventory.bucketObjectCounts.entries) {
      final classification = _userUploadBuckets.contains(entry.key)
          ? 'user-upload bucket; objects will be cleared on reset'
          : 'preserved; never cleared automatically';
      stdout.writeln('  ${entry.key}: ${entry.value} ($classification)');
    }
  }
}

class _ResetOptions {
  const _ResetOptions({
    required this.projectRef,
    required this.confirmReset,
    required this.dryRun,
  });

  final String? projectRef;
  final bool confirmReset;
  final bool dryRun;

  static _ResetOptions parse(List<String> args) {
    String? projectRef;
    var confirmReset = false;
    var dryRun = false;
    for (final argument in args) {
      if (argument.startsWith('--project-ref=')) {
        projectRef = argument.substring('--project-ref='.length);
      } else if (argument == '--confirm-reset') {
        confirmReset = true;
      } else if (argument == '--dry-run') {
        dryRun = true;
      } else {
        _fail('Unknown argument: $argument');
      }
    }
    return _ResetOptions(
      projectRef: projectRef,
      confirmReset: confirmReset,
      dryRun: dryRun,
    );
  }
}

class _TableTarget {
  const _TableTarget(this.table, this.nonEmptyFilter);

  final String table;
  final String nonEmptyFilter;
}

class _Inventory {
  const _Inventory({
    required this.userDataCounts,
    required this.configCounts,
    required this.authUsers,
    required this.bucketObjectCounts,
  });

  final Map<String, int> userDataCounts;
  final Map<String, int> configCounts;
  final int authUsers;
  final Map<String, int> bucketObjectCounts;
}

class _SupabaseResetApi {
  _SupabaseResetApi(this._baseUrl, this._serviceRoleKey);

  final Uri _baseUrl;
  final String _serviceRoleKey;
  final HttpClient _client = HttpClient();

  void close() => _client.close(force: true);

  Map<String, String> get _headers => <String, String>{
        'apikey': _serviceRoleKey,
        'authorization': 'Bearer $_serviceRoleKey',
      };

  Future<int> countTableRows(String table) async {
    final response = await _request(
      'HEAD',
      _uri('/rest/v1/$table', <String, String>{'select': '*', 'limit': '1'}),
      headers: <String, String>{..._headers, 'prefer': 'count=exact'},
    );
    final contentRange = response.headers.value('content-range');
    final match = RegExp(r'/(\d+)$').firstMatch(contentRange ?? '');
    if (match == null) {
      throw StateError('Could not read row count for $table.');
    }
    return int.parse(match.group(1)!);
  }

  Future<void> deleteAllRows(_TableTarget target) async {
    await _request(
      'DELETE',
      _uri('/rest/v1/${target.table}', <String, String>{
        target.nonEmptyFilter.split('=').first: target.nonEmptyFilter
            .substring(target.nonEmptyFilter.indexOf('=') + 1)
      }),
      headers: <String, String>{..._headers, 'prefer': 'return=minimal'},
    );
  }

  Future<List<String>> listBucketIds() async {
    final response =
        await _request('GET', _uri('/storage/v1/bucket'), headers: _headers);
    final decoded = _decodeList(response.body, 'storage buckets');
    return decoded
        .map((item) => item['id'])
        .whereType<String>()
        .toList(growable: false);
  }

  Future<List<String>> listAllObjectPaths(String bucket) async {
    final result = <String>[];
    final visitedPrefixes = <String>{};

    Future<void> visit(String prefix) async {
      if (!visitedPrefixes.add(prefix)) return;
      var offset = 0;
      const pageSize = 1000;
      while (true) {
        final response = await _request(
          'POST',
          _uri('/storage/v1/object/list/$bucket'),
          headers: <String, String>{
            ..._headers,
            'content-type': 'application/json'
          },
          body: jsonEncode(<String, Object>{
            'prefix': prefix,
            'limit': pageSize,
            'offset': offset,
            'sortBy': <String, String>{'column': 'name', 'order': 'asc'},
          }),
        );
        final page = _decodeList(response.body, 'objects in $bucket');
        for (final item in page) {
          final name = item['name'];
          if (name is! String || name.isEmpty) continue;
          final path = prefix.isEmpty ? name : '$prefix/$name';
          if (item['id'] is String) {
            result.add(path);
          } else {
            await visit(path);
          }
        }
        if (page.length < pageSize) return;
        offset += page.length;
      }
    }

    await visit('');
    return result;
  }

  Future<void> deleteObjectPaths(String bucket, List<String> paths) async {
    const chunkSize = 1000;
    for (var start = 0; start < paths.length; start += chunkSize) {
      final end =
          (start + chunkSize < paths.length) ? start + chunkSize : paths.length;
      await _request(
        'DELETE',
        _uri('/storage/v1/object/$bucket'),
        headers: <String, String>{
          ..._headers,
          'content-type': 'application/json'
        },
        body:
            jsonEncode(<String, Object>{'prefixes': paths.sublist(start, end)}),
      );
    }
  }

  Future<List<Map<String, dynamic>>> listAuthUsers() async {
    final users = <Map<String, dynamic>>[];
    var page = 1;
    while (true) {
      final response = await _request(
        'GET',
        _uri('/auth/v1/admin/users',
            <String, String>{'page': '$page', 'per_page': '1000'}),
        headers: _headers,
      );
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic> || body['users'] is! List) {
        throw StateError(
            'Supabase Auth returned an unexpected users response.');
      }
      final currentPage = (body['users'] as List)
          .whereType<Map>()
          .map((user) => Map<String, dynamic>.from(user))
          .toList(growable: false);
      users.addAll(currentPage);
      if (currentPage.length < 1000) return users;
      page++;
    }
  }

  Future<int> deleteAllAuthUsers() async {
    final users = await listAuthUsers();
    for (final user in users) {
      final id = user['id'];
      if (id is! String || id.isEmpty) {
        throw StateError('Supabase Auth returned a user without an id.');
      }
      await _request('DELETE', _uri('/auth/v1/admin/users/$id'),
          headers: _headers);
    }
    return users.length;
  }

  Uri _uri(String path, [Map<String, String>? query]) => _baseUrl.replace(
        path: path,
        queryParameters: query,
      );

  Future<_HttpResponse> _request(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    String? body,
  }) async {
    final request = await _client.openUrl(method, uri);
    headers.forEach(request.headers.set);
    if (body != null) request.write(body);
    final response = await request.close();
    final responseBody = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final trimmed = responseBody.replaceAll(RegExp(r'\s+'), ' ').trim();
      throw HttpException(
        '$method ${uri.path} failed with HTTP ${response.statusCode}'
        '${trimmed.isEmpty ? '' : ': $trimmed'}',
        uri: uri,
      );
    }
    return _HttpResponse(response.headers, responseBody);
  }
}

class _HttpResponse {
  const _HttpResponse(this.headers, this.body);

  final HttpHeaders headers;
  final String body;
}

List<Map<String, dynamic>> _decodeList(String body, String description) {
  final decoded = jsonDecode(body);
  if (decoded is! List) {
    throw StateError('Expected a list for $description.');
  }
  return decoded
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(64);
}
