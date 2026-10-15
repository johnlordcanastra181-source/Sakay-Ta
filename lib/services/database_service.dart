import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common/sqlite_api.dart';
import '../core/constants.dart';
import '../models/admin_account.dart';
import '../models/report_model.dart';
import '../models/firestore_models.dart';
import 'db_factory/db_factory.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static bool? allowTestAccountsOverride;

  /// Returns true only when running Flutter Web on localhost / 127.0.0.1.
  static bool get isLocalhostWeb {
    if (!kIsWeb) return false;
    try {
      final host = Uri.base.host.toLowerCase();
      return host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0';
    } catch (_) {
      return false;
    }
  }

  /// Whether test/demo accounts are allowed.
  /// Enabled by default on both Web and Android/iOS APK builds for demo & checking purposes.
  /// Can be overridden dynamically via [allowTestAccountsOverride].
  static bool get allowTestAccounts {
    if (allowTestAccountsOverride != null) return allowTestAccountsOverride!;
    return false;
  }

  Database? _db;
  Future<Database>? _opening;

  Future<Database> get database {
    if (_db != null) return Future.value(_db!);
    return _opening ??= _openOnce();
  }

  Future<Database> _openOnce() async {
    try {
      // onOpen completes schema repair before any caller receives the handle.
      return _db = await _open();
    } finally {
      _opening = null;
    }
  }

  Future<Database> _open() async {
    return openAppDatabase(
      'sakay_ta.db',
      version: 11,
      // SQLite is intentionally used as a cache/offline mirror. Firebase is
      // the source of truth, so local writes must not fail because a related
      // record has not been cached yet.
      onConfigure: (db) async {
        try {
          await db.execute('PRAGMA foreign_keys = OFF');
        } catch (_) {}
      },
      onCreate: (db, version) => _createTables(db),
      onUpgrade: (db, oldVersion, newVersion) =>
          _upgrade(db, oldVersion, newVersion),
      onOpen: (db) => _ensureSchemaIntegrity(db),
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        full_name TEXT NOT NULL,
        mobile TEXT,
        email TEXT,
        email_verified INTEGER NOT NULL DEFAULT 0,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'approved',
        rejection_reason TEXT,
        is_online INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        rating REAL NOT NULL DEFAULT 5.0,
        rating_count INTEGER NOT NULL DEFAULT 0,
        acceptance_count INTEGER NOT NULL DEFAULT 0,
        acceptance_total INTEGER NOT NULL DEFAULT 0,
        on_time_count INTEGER NOT NULL DEFAULT 0,
        total_trips INTEGER NOT NULL DEFAULT 0,
        lifetime_earnings REAL NOT NULL DEFAULT 0,
        verified_at INTEGER,
        address TEXT,
        latitude REAL,
        longitude REAL,
        location_updated_at INTEGER,
        profile_photo_url TEXT,
        avatar_color INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_users_mobile ON users(mobile) WHERE mobile IS NOT NULL AND mobile != \'\'',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email ON users(email) WHERE email IS NOT NULL AND email != \'\'',
    );

    await db.execute('''
      CREATE TABLE drivers (
        user_id TEXT PRIMARY KEY,
        dob TEXT NOT NULL DEFAULT '',
        gender TEXT NOT NULL DEFAULT 'male',
        sex TEXT NOT NULL DEFAULT '',
        address TEXT NOT NULL DEFAULT '',
        license_type TEXT NOT NULL DEFAULT 'professional',
        vehicle_type TEXT NOT NULL,
        plate_number TEXT NOT NULL,
        license_number TEXT NOT NULL DEFAULT '',
        license_expiry TEXT NOT NULL DEFAULT '',
        dl_codes TEXT NOT NULL DEFAULT 'A',
        condition_codes TEXT NOT NULL DEFAULT 'NONE',
        make TEXT NOT NULL DEFAULT '',
        model TEXT NOT NULL DEFAULT '',
        year INTEGER NOT NULL DEFAULT 0,
        color TEXT NOT NULL DEFAULT '',
        toda_name TEXT,
        barangay TEXT NOT NULL DEFAULT '',
        municipality TEXT NOT NULL DEFAULT '',
        province TEXT NOT NULL DEFAULT '',
        doc_license_front TEXT,
        doc_license_back TEXT,
        doc_or_cr TEXT,
        doc_profile TEXT,
        profilePhotoUrl TEXT,
        profile_photo_url TEXT,
        driver_license_front TEXT,
        driver_license_back TEXT,
        driver_license_selfie TEXT,
        vehicle_front TEXT,
        vehicle_side TEXT,
        vehicle_back TEXT,
        or_cr_doc TEXT,
        barangay_clearance TEXT,
        police_clearance TEXT,
        mayors_permit TEXT,
        toda_id TEXT,
        submitted_at INTEGER NOT NULL,
        reviewed_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE emergency_contacts (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        relationship TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE driver_documents (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        document_type TEXT NOT NULL,
        file_path TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        uploaded_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE trip (
        id TEXT PRIMARY KEY,
        driver_id TEXT,
        passenger_id TEXT NOT NULL,
        passenger_name TEXT NOT NULL DEFAULT '',
        passenger_phone TEXT NOT NULL DEFAULT '',
        vehicle_type TEXT NOT NULL DEFAULT 'tricycle',
        pickup_address TEXT NOT NULL,
        dropoff_address TEXT NOT NULL,
        pickup_lat REAL NOT NULL,
        pickup_lng REAL NOT NULL,
        dropoff_lat REAL NOT NULL,
        dropoff_lng REAL NOT NULL,
        distance_km REAL NOT NULL,
        duration_min INTEGER NOT NULL DEFAULT 0,
        fare REAL NOT NULL,
        commission REAL NOT NULL DEFAULT 0,
        net REAL NOT NULL DEFAULT 0,
        base_fare REAL NOT NULL DEFAULT 0,
        distance_fare REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL,
        payment_method TEXT NOT NULL DEFAULT 'cash',
        payment_status TEXT NOT NULL DEFAULT 'unpaid',
        created_at INTEGER NOT NULL,
        accepted_at INTEGER,
        arrived_at INTEGER,
        started_at INTEGER,
        completed_at INTEGER,
        cancelled_at INTEGER,
        cancellation_reason TEXT,
        rating INTEGER,
        rating_comment TEXT,
        driver_rating REAL,
        passenger_rating REAL,
        queued INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS booking (
        id TEXT PRIMARY KEY,
        passenger_id TEXT NOT NULL,
        vehicle_type TEXT NOT NULL,
        pickup_address TEXT NOT NULL,
        dropoff_address TEXT NOT NULL,
        pickup_lat REAL NOT NULL,
        pickup_lng REAL NOT NULL,
        dropoff_lat REAL NOT NULL,
        dropoff_lng REAL NOT NULL,
        payment_method TEXT NOT NULL DEFAULT 'cash',
        status TEXT NOT NULL DEFAULT 'requested',
        queued INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ratings (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        from_user_id TEXT NOT NULL,
        to_user_id TEXT NOT NULL,
        rating REAL NOT NULL,
        review TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE payment_transactions (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        amount REAL NOT NULL,
        method TEXT NOT NULL,
        reference_number TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_messages (
        id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        sender_role TEXT NOT NULL,
        text TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE notifications (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        type TEXT NOT NULL,
        payload TEXT,
        is_read INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE toda_associations (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        code TEXT NOT NULL,
        city TEXT NOT NULL,
        president TEXT,
        contact_number TEXT,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE fare_matrix (
        id TEXT PRIMARY KEY,
        vehicle_type TEXT NOT NULL UNIQUE,
        base_fare REAL NOT NULL,
        base_km REAL NOT NULL DEFAULT 1.0,
        per_km_rate REAL NOT NULL,
        night_diff_percent REAL NOT NULL DEFAULT 0,
        senior_discount_percent REAL NOT NULL DEFAULT 20,
        student_discount_percent REAL NOT NULL DEFAULT 20,
        pwd_discount_percent REAL NOT NULL DEFAULT 20,
        effective_date INTEGER NOT NULL
      )
    ''');

    await _seedDefaults(db);
    await _createAdminTables(db);
    if (allowTestAccounts) {
      await _seedDefaultAccounts(db);
    }
    await _createMagicLinkTables(db);
    await _createOtpTables(db);
    await _createSyncAndCacheTables(db);
  }

  static String hashPassword(String password) {
    var hash = 0x811c9dc5;
    final bytes = ('sakay_ta::$password').codeUnits;
    for (final b in bytes) {
      hash ^= b;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  int _firstIntValue(List<Map<String, Object?>> list) {
    if (list.isNotEmpty && list.first.isNotEmpty) {
      final val = list.first.values.first;
      if (val is int) return val;
      if (val is num) return val.toInt();
    }
    return 0;
  }

  Future<void> _seedDefaults(Database db) async {
    if (!allowTestAccounts) return;
    final todaCount = _firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM toda_associations'),
    );
    if (todaCount == 0) {
      await db.insert('toda_associations', {
        'id': 'toda-1',
        'name': 'Cebu Central Tricycle TODA',
        'code': 'CCT-01',
        'city': 'Cebu City',
        'president': 'Juan Santos',
        'contact_number': '+639171234567',
        'is_active': 1,
      });
      await db.insert('toda_associations', {
        'id': 'toda-2',
        'name': 'Mandaue TODA Operators Assn.',
        'code': 'MTOA-02',
        'city': 'Mandaue City',
        'president': 'Pedro Reyes',
        'contact_number': '+639181234567',
        'is_active': 1,
      });
    }

    final fareCount = _firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM fare_matrix'),
    );
    if (fareCount == 0) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('fare_matrix', {
        'id': 'fm-1',
        'vehicle_type': 'tricycle',
        'base_fare': 15.0,
        'base_km': 1.0,
        'per_km_rate': 3.0,
        'night_diff_percent': 10.0,
        'senior_discount_percent': 20.0,
        'student_discount_percent': 20.0,
        'pwd_discount_percent': 20.0,
        'effective_date': now,
      });
      await db.insert('fare_matrix', {
        'id': 'fm-2',
        'vehicle_type': 'habal_habal',
        'base_fare': 20.0,
        'base_km': 1.0,
        'per_km_rate': 4.0,
        'night_diff_percent': 15.0,
        'senior_discount_percent': 20.0,
        'student_discount_percent': 20.0,
        'pwd_discount_percent': 20.0,
        'effective_date': now,
      });
    }
  }

  /// Seeds default test/demo accounts into SQLite for web & localhost testing.
  Future<void> seedTestAccounts(
      [Database? customDb, bool force = false]) async {
    if (!force && !allowTestAccounts) {
      return;
    }
    final db = customDb ?? await database;
    await _seedDefaultAccounts(db);
  }

  /// Purges built-in localhost test accounts from SQLite on actual APK / production.
  Future<void> purgeTestAccounts([Database? customDb]) async {
    final db = customDb ?? await database;
    await _purgeTestAccounts(db);
  }

  Future<void> _purgeTestAccounts(Database db) async {
    try {
      final testIds = [
        'test-passenger-1',
        'test-driver-1',
        'test-driver-2',
        'test-admin-1',
      ];
      final testEmails = [
        'passenger@sakayta.ph',
        'driver@sakayta.ph',
        'driver2@sakayta.ph',
        'admin@sakayta.ph',
      ];
      for (final id in testIds) {
        await db.delete('users', where: 'id = ?', whereArgs: [id]);
        await db.delete('drivers', where: 'user_id = ?', whereArgs: [id]);
        await db.delete('admin_accounts', where: 'id = ?', whereArgs: [id]);
      }
      for (final email in testEmails) {
        await db.delete('users', where: 'email = ?', whereArgs: [email]);
        await db
            .delete('admin_accounts', where: 'email = ?', whereArgs: [email]);
      }
      try {
        await db.delete(
          'reports',
          where:
              'reporter_id IN (?, ?, ?, ?) OR reported_user_id IN (?, ?, ?, ?)',
          whereArgs: [...testIds, ...testIds],
        );
      } catch (_) {}
      try {
        await db.delete('toda_associations',
            where: 'id LIKE ?', whereArgs: ['toda-%']);
      } catch (_) {}
    } catch (e) {
      debugPrint('DatabaseService: _purgeTestAccounts note ($e)');
    }
  }

  Future<void> _seedDefaultAccounts(Database db) async {
    if (!allowTestAccounts) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final defaultPasswordHash = hashPassword('password123');
    final adminPasswordHash = hashPassword('admin123');

    final testUsers = <Map<String, Object?>>[
      // 1. Test Passenger
      {
        'id': 'test-passenger-1',
        'full_name': 'Juan Dela Cruz (Passenger)',
        'mobile': '09123456789',
        'email': 'passenger@sakayta.ph',
        'email_verified': 1,
        'password_hash': defaultPasswordHash,
        'role': 'passenger',
        'status': 'approved',
        'is_online': 0,
        'created_at': 1704067200000,
        'rating': 5.0,
        'rating_count': 12,
        'acceptance_count': 0,
        'acceptance_total': 0,
        'on_time_count': 0,
        'total_trips': 15,
        'lifetime_earnings': 0.0,
        'address': 'Purok 2, Bonbon, Clarin, Bohol',
        'latitude': 10.3157,
        'longitude': 123.8854,
      },
      // 2. Test Driver (Tricycle)
      {
        'id': 'test-driver-1',
        'full_name': 'Pedro Reyes (Driver)',
        'mobile': '09987654321',
        'email': 'driver@sakayta.ph',
        'email_verified': 1,
        'password_hash': defaultPasswordHash,
        'role': 'driver',
        'status': 'approved',
        'is_online': 1,
        'created_at': 1704067200000,
        'rating': 4.9,
        'rating_count': 48,
        'acceptance_count': 45,
        'acceptance_total': 46,
        'on_time_count': 44,
        'total_trips': 48,
        'lifetime_earnings': 3650.0,
        'address': 'Cebu Central, Cebu City',
        'latitude': 10.3160,
        'longitude': 123.8900,
      },
      // 3. Test Driver (Habal-Habal Motorcycle)
      {
        'id': 'test-driver-2',
        'full_name': 'Mario Santos (Habal Driver)',
        'mobile': '09981112233',
        'email': 'habal@sakayta.ph',
        'email_verified': 1,
        'password_hash': defaultPasswordHash,
        'role': 'driver',
        'status': 'approved',
        'is_online': 1,
        'created_at': 1704067200000,
        'rating': 4.8,
        'rating_count': 30,
        'acceptance_count': 29,
        'acceptance_total': 30,
        'on_time_count': 28,
        'total_trips': 32,
        'lifetime_earnings': 2800.0,
        'address': 'Mandaue City, Cebu',
        'latitude': 10.3200,
        'longitude': 123.9060,
      },
      // 4. Test Admin
      {
        'id': 'test-admin-1',
        'full_name': 'System Administrator',
        'mobile': '09000000000',
        'email': 'admin@sakayta.ph',
        'email_verified': 1,
        'password_hash': adminPasswordHash,
        'role': 'admin',
        'status': 'approved',
        'is_online': 0,
        'created_at': 1704067200000,
        'rating': 5.0,
        'rating_count': 0,
        'acceptance_count': 0,
        'acceptance_total': 0,
        'on_time_count': 0,
        'total_trips': 0,
        'lifetime_earnings': 0.0,
        'address': 'HQ Admin Office, Cebu City',
        'latitude': 10.3157,
        'longitude': 123.8854,
      },
    ];

    final existingUserCols = await _getTableColumns(db, 'users');
    for (final user in testUsers) {
      try {
        final filteredUser = Map<String, Object?>.fromEntries(
          user.entries.where(
            (e) =>
                existingUserCols.isEmpty ||
                existingUserCols.contains(e.key.toLowerCase()),
          ),
        );
        final existing = await db.query(
          'users',
          where: 'id = ? OR email = ? OR (mobile = ? AND mobile != \'\')',
          whereArgs: [user['id'], user['email'], user['mobile']],
          limit: 1,
        );
        if (existing.isEmpty) {
          await db.insert('users', filteredUser);
        } else {
          await db.update(
            'users',
            filteredUser,
            where: 'id = ?',
            whereArgs: [existing.first['id']],
          );
        }
      } catch (e) {
        debugPrint('DatabaseService: _seedDefaultAccounts user note ($e)');
      }
    }

    final driverProfiles = <Map<String, Object?>>[
      {
        'user_id': 'test-driver-1',
        'dob': '1990-01-15',
        'sex': 'male',
        'gender': 'male',
        'address': 'Cebu Central, Cebu City',
        'license_type': 'professional',
        'license_number': 'N01-12-345678',
        'license_expiry': '2028-12-31',
        'dl_codes': 'A,A1',
        'condition_codes': 'NONE',
        'vehicle_type': 'tricycle',
        'plate_number': 'CEB-1234',
        'make': 'Bajaj',
        'model': 'RE',
        'year': 2024,
        'color': 'Blue',
        'toda_id': 'toda-1',
        'toda_name': 'Cebu Central Tricycle TODA',
        'barangay': 'Central',
        'municipality': 'Cebu City',
        'province': 'Cebu',
        'submitted_at': 1704067200000,
        'reviewed_at': now,
      },
      {
        'user_id': 'test-driver-2',
        'dob': '1992-05-20',
        'sex': 'male',
        'gender': 'male',
        'address': 'Mandaue City, Cebu',
        'license_type': 'professional',
        'license_number': 'N02-98-765432',
        'license_expiry': '2028-12-31',
        'dl_codes': 'A',
        'condition_codes': 'NONE',
        'vehicle_type': 'habal',
        'plate_number': 'MC-5678',
        'make': 'Honda',
        'model': 'TMX 125',
        'year': 2023,
        'color': 'Red',
        'toda_id': 'toda-2',
        'toda_name': 'Mandaue TODA Operators Assn.',
        'barangay': 'Centro',
        'municipality': 'Mandaue City',
        'province': 'Cebu',
        'submitted_at': 1704067200000,
        'reviewed_at': now,
      },
    ];

    final existingDriverCols = await _getTableColumns(db, 'drivers');
    for (final profile in driverProfiles) {
      try {
        final filteredProfile = Map<String, Object?>.fromEntries(
          profile.entries.where(
            (e) =>
                existingDriverCols.isEmpty ||
                existingDriverCols.contains(e.key.toLowerCase()),
          ),
        );
        final existing = await db.query(
          'drivers',
          where: 'user_id = ?',
          whereArgs: [profile['user_id']],
          limit: 1,
        );
        if (existing.isEmpty) {
          await db.insert('drivers', filteredProfile);
        } else {
          await db.update(
            'drivers',
            filteredProfile,
            where: 'user_id = ?',
            whereArgs: [profile['user_id']],
          );
        }
      } catch (e) {
        debugPrint('DatabaseService: _seedDefaultAccounts driver note ($e)');
      }
    }

    // Seed default admin account into admin_accounts table
    try {
      final existingAdmin = await db.query(
        'admin_accounts',
        where: 'id = ? OR email = ?',
        whereArgs: ['super-admin-root', 'johnlordcanastra@sakayta.app'],
        limit: 1,
      );
      if (existingAdmin.isEmpty) {
        await db.insert('admin_accounts', {
          'id': 'super-admin-root',
          'full_name': 'John Lord Canastra',
          'email': 'johnlordcanastra@sakayta.app',
          'mobile': '09000000000',
          'password_hash': hashPassword('admin09876'),
          'role': 'super_admin',
          'status': 'active',
          'permissions': 'all',
          'department': 'HQ Management',
          'created_at': 1704067200000,
        });
      } else {
        // Update password and role to super_admin
        await db.update(
          'admin_accounts',
          {
            'password_hash': hashPassword('admin09876'),
            'role': 'super_admin',
            'full_name': 'John Lord Canastra',
          },
          where: 'id = ? OR email = ?',
          whereArgs: ['super-admin-root', 'johnlordcanastra@sakayta.app'],
        );
      }
    } catch (e) {
      debugPrint('DatabaseService: _seedDefaultAccounts admin note ($e)');
    }
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createMagicLinkTables(db);
    }
    if (oldVersion < 3) {
      await _createOtpTables(db);
    }
    if (oldVersion < 4) {
      // Driver profile details introduced in v4.
      await db.execute(
        "ALTER TABLE drivers ADD COLUMN dob TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE drivers ADD COLUMN gender TEXT NOT NULL DEFAULT 'male'",
      );
      await db.execute(
        "ALTER TABLE drivers ADD COLUMN license_number TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE drivers ADD COLUMN license_expiry TEXT NOT NULL DEFAULT ''",
      );
      await db
          .execute('ALTER TABLE drivers ADD COLUMN driver_license_selfie TEXT');
      await db.execute('ALTER TABLE drivers ADD COLUMN vehicle_side TEXT');
      await db.execute('ALTER TABLE drivers ADD COLUMN vehicle_back TEXT');
      await db.execute('ALTER TABLE drivers ADD COLUMN or_cr_doc TEXT');
      await db
          .execute('ALTER TABLE drivers ADD COLUMN barangay_clearance TEXT');
      await db.execute('ALTER TABLE drivers ADD COLUMN police_clearance TEXT');
      await db.execute('ALTER TABLE drivers ADD COLUMN mayors_permit TEXT');
      await db.execute('ALTER TABLE drivers ADD COLUMN toda_id TEXT');
      await db.execute('ALTER TABLE drivers ADD COLUMN reviewed_at INTEGER');
    }
    if (oldVersion < 5) {
      // Driver live GPS coordinates (used by the nearby-drivers search).
      try {
        await db.execute('ALTER TABLE users ADD COLUMN latitude REAL');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE users ADD COLUMN longitude REAL');
      } catch (_) {}
    }
    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN email TEXT');
        await db.execute(
          'ALTER TABLE users ADD COLUMN email_verified INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {}
    }
    if (oldVersion < 7) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN email TEXT');
        await db.execute(
          'ALTER TABLE users ADD COLUMN email_verified INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {}
    }
    if (oldVersion < 8) {
      // Migrate users table to remove rigid NOT NULL UNIQUE from mobile and enable partial unique indexes
      try {
        await db.execute('ALTER TABLE users RENAME TO users_old');
        await db.execute('''
          CREATE TABLE users (
            id TEXT PRIMARY KEY,
            full_name TEXT NOT NULL,
            mobile TEXT,
            email TEXT,
            email_verified INTEGER NOT NULL DEFAULT 0,
            password_hash TEXT NOT NULL,
            role TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'approved',
            rejection_reason TEXT,
            is_online INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            rating REAL NOT NULL DEFAULT 5.0,
            rating_count INTEGER NOT NULL DEFAULT 0,
            acceptance_count INTEGER NOT NULL DEFAULT 0,
            acceptance_total INTEGER NOT NULL DEFAULT 0,
            on_time_count INTEGER NOT NULL DEFAULT 0,
            total_trips INTEGER NOT NULL DEFAULT 0,
            lifetime_earnings REAL NOT NULL DEFAULT 0,
            verified_at INTEGER,
            address TEXT,
            latitude REAL,
            longitude REAL
          )
        ''');
        await db.execute('''
          INSERT OR IGNORE INTO users (
            id, full_name, mobile, email, email_verified, password_hash, role, status,
            rejection_reason, is_online, created_at, rating, rating_count, acceptance_count,
            acceptance_total, on_time_count, total_trips, lifetime_earnings, verified_at,
            latitude, longitude
          )
          SELECT 
            id, full_name, mobile, email, email_verified, password_hash, role, status,
            rejection_reason, is_online, created_at, rating, rating_count, acceptance_count,
            acceptance_total, on_time_count, total_trips, lifetime_earnings, verified_at,
            latitude, longitude
          FROM users_old
        ''');
        await db.execute('DROP TABLE users_old');
        await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_users_mobile ON users(mobile) WHERE mobile IS NOT NULL AND mobile != \'\'',
        );
        await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email ON users(email) WHERE email IS NOT NULL AND email != \'\'',
        );
      } catch (e) {
        debugPrint('DatabaseService: v8 migration note ($e)');
      }
    }
    if (oldVersion < 9) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN address TEXT');
      } catch (_) {}
      try {
        await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_users_mobile ON users(mobile) WHERE mobile IS NOT NULL AND mobile != \'\'',
        );
        await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email ON users(email) WHERE email IS NOT NULL AND email != \'\'',
        );
      } catch (e) {
        debugPrint('DatabaseService: v9 migration note ($e)');
      }
    }
    if (oldVersion < 10) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN address TEXT');
      } catch (_) {}
      try {
        await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_users_mobile ON users(mobile) WHERE mobile IS NOT NULL AND mobile != \'\'',
        );
        await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email ON users(email) WHERE email IS NOT NULL AND email != \'\'',
        );
      } catch (e) {
        debugPrint('DatabaseService: v10 migration note ($e)');
      }
    }
  }

  /// Self-healing schema validation executed every time the database opens.
  /// Ensures all essential columns and indexes exist regardless of interrupted migrations.
  Future<void> _ensureSchemaIntegrity(Database db) async {
    try {
      final userCols = await _getTableColumns(db, 'users');
      if (userCols.isNotEmpty) {
        if (!userCols.contains('address')) {
          try {
            await db.execute('ALTER TABLE users ADD COLUMN address TEXT');
          } catch (_) {}
        }
        if (!userCols.contains('email')) {
          try {
            await db.execute('ALTER TABLE users ADD COLUMN email TEXT');
          } catch (_) {}
        }
        if (!userCols.contains('email_verified')) {
          try {
            await db.execute(
              'ALTER TABLE users ADD COLUMN email_verified INTEGER NOT NULL DEFAULT 0',
            );
          } catch (_) {}
        }
        if (!userCols.contains('latitude')) {
          try {
            await db.execute('ALTER TABLE users ADD COLUMN latitude REAL');
          } catch (_) {}
        }
        if (!userCols.contains('longitude')) {
          try {
            await db.execute('ALTER TABLE users ADD COLUMN longitude REAL');
          } catch (_) {}
        }
        if (!userCols.contains('rejection_reason')) {
          try {
            await db
                .execute('ALTER TABLE users ADD COLUMN rejection_reason TEXT');
          } catch (_) {}
        }
        if (!userCols.contains('verified_at')) {
          try {
            await db
                .execute('ALTER TABLE users ADD COLUMN verified_at INTEGER');
          } catch (_) {}
        }
        if (!userCols.contains('profile_photo_url')) {
          try {
            await db
                .execute('ALTER TABLE users ADD COLUMN profile_photo_url TEXT');
          } catch (_) {}
        }
        if (!userCols.contains('location_updated_at')) {
          try {
            await db.execute(
              'ALTER TABLE users ADD COLUMN location_updated_at INTEGER',
            );
          } catch (_) {}
        }
        if (!userCols.contains('avatar_color')) {
          try {
            await db.execute(
              'ALTER TABLE users ADD COLUMN avatar_color INTEGER NOT NULL DEFAULT 0',
            );
          } catch (_) {}
        }

        try {
          await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_users_mobile ON users(mobile) WHERE mobile IS NOT NULL AND mobile != \'\'',
          );
          await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email ON users(email) WHERE email IS NOT NULL AND email != \'\'',
          );
        } catch (_) {}
      }

      final driverCols = await _getTableColumns(db, 'drivers');
      if (driverCols.isNotEmpty) {
        final expectedDriverCols = <String, String>{
          'dob': "TEXT NOT NULL DEFAULT ''",
          'gender': "TEXT NOT NULL DEFAULT 'male'",
          'sex': "TEXT NOT NULL DEFAULT 'male'",
          'address': "TEXT NOT NULL DEFAULT ''",
          'license_type': "TEXT NOT NULL DEFAULT 'professional'",
          'license_number': "TEXT NOT NULL DEFAULT ''",
          'license_expiry': "TEXT NOT NULL DEFAULT ''",
          'dl_codes': "TEXT NOT NULL DEFAULT 'A'",
          'condition_codes': "TEXT NOT NULL DEFAULT 'NONE'",
          'vehicle_type': "TEXT NOT NULL DEFAULT 'tricycle'",
          'plate_number': "TEXT NOT NULL DEFAULT ''",
          'make': "TEXT NOT NULL DEFAULT ''",
          'model': "TEXT NOT NULL DEFAULT ''",
          'year': "INTEGER NOT NULL DEFAULT 2026",
          'color': "TEXT NOT NULL DEFAULT ''",
          'toda_id': "TEXT",
          'toda_name': "TEXT",
          'barangay': "TEXT",
          'municipality': "TEXT",
          'province': "TEXT",
          'doc_license_front': "TEXT",
          'doc_license_back': "TEXT",
          'doc_or_cr': "TEXT",
          'doc_profile': "TEXT",
          'profilePhotoUrl': "TEXT",
          'profile_photo_url': "TEXT",
          'driver_license_front': "TEXT",
          'driver_license_back': "TEXT",
          'driver_license_selfie': "TEXT",
          'vehicle_front': "TEXT",
          'vehicle_side': "TEXT",
          'vehicle_back': "TEXT",
          'or_cr_doc': "TEXT",
          'barangay_clearance': "TEXT",
          'police_clearance': "TEXT",
          'mayors_permit': "TEXT",
          'submitted_at': "INTEGER",
          'reviewed_at': "INTEGER",
        };

        for (final entry in expectedDriverCols.entries) {
          if (!driverCols.contains(entry.key.toLowerCase())) {
            try {
              await db.execute(
                  'ALTER TABLE drivers ADD COLUMN ${entry.key} ${entry.value}');
            } catch (_) {}
          }
        }
      }

      final tripCols = await _getTableColumns(db, 'trip');
      if (tripCols.isNotEmpty) {
        final expectedTripCols = <String, String>{
          'vehicle_type': "TEXT NOT NULL DEFAULT 'tricycle'",
          'duration_min': "INTEGER NOT NULL DEFAULT 0",
          'commission': "REAL NOT NULL DEFAULT 0",
          'net': "REAL NOT NULL DEFAULT 0",
          'payment_status': "TEXT NOT NULL DEFAULT 'unpaid'",
          'arrived_at': "INTEGER",
          'rating': "INTEGER",
          'rating_comment': "TEXT",
          'queued': "INTEGER NOT NULL DEFAULT 0",
        };
        for (final entry in expectedTripCols.entries) {
          if (!tripCols.contains(entry.key.toLowerCase())) {
            try {
              await db.execute(
                  'ALTER TABLE trip ADD COLUMN ${entry.key} ${entry.value}');
            } catch (_) {}
          }
        }
      }

      await db.execute('''
        CREATE TABLE IF NOT EXISTS ratings (
          id TEXT PRIMARY KEY,
          trip_id TEXT NOT NULL,
          from_user_id TEXT NOT NULL,
          to_user_id TEXT NOT NULL,
          rating REAL NOT NULL,
          review TEXT,
          created_at INTEGER NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS booking (
          id TEXT PRIMARY KEY,
          passenger_id TEXT NOT NULL,
          vehicle_type TEXT NOT NULL,
          pickup_address TEXT NOT NULL,
          dropoff_address TEXT NOT NULL,
          pickup_lat REAL NOT NULL,
          pickup_lng REAL NOT NULL,
          dropoff_lat REAL NOT NULL,
          dropoff_lng REAL NOT NULL,
          payment_method TEXT NOT NULL DEFAULT 'cash',
          status TEXT NOT NULL DEFAULT 'requested',
          queued INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL
        )
      ''');

      await _createAdminTables(db);
      await db.execute('''CREATE TABLE IF NOT EXISTS admin_refunds (
        ride_id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        reason TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )''');
      await _createSyncAndCacheTables(db);
      await _createReportsTable(db);
      if (allowTestAccounts) {
        await _seedDefaultReports(db);
        await _seedDefaultAccounts(db);
      } else {
        await _purgeTestAccounts(db);
      }
    } catch (e) {
      debugPrint('DatabaseService: _ensureSchemaIntegrity note ($e)');
    }
  }

  Future<Set<String>> _getTableColumns(Database db, String table) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info($table)');
      return info
          .map((row) => (row['name'] as String?)?.toLowerCase() ?? '')
          .where((s) => s.isNotEmpty)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> _createSyncAndCacheTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        payload TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');
    try {
      final syncCols = await _getTableColumns(db, 'sync_queue');
      if (syncCols.isNotEmpty && !syncCols.contains('retry_count')) {
        await db.execute(
          'ALTER TABLE sync_queue ADD COLUMN retry_count INTEGER NOT NULL DEFAULT 0',
        );
      }
    } catch (_) {}
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_created ON sync_queue(created_at ASC)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS map_cache (
        cache_key TEXT PRIMARY KEY,
        data_type TEXT NOT NULL,
        response_json TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_map_cache_expires ON map_cache(expires_at)',
    );
  }

  Future<void> _createMagicLinkTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS magic_links (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mobile TEXT NOT NULL,
        token TEXT NOT NULL UNIQUE,
        purpose TEXT NOT NULL DEFAULT 'signup',
        is_used INTEGER NOT NULL DEFAULT 0,
        expires_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_magic_links_mobile ON magic_links(mobile)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_magic_links_token ON magic_links(token)',
    );
  }

  Future<void> _createOtpTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS otp_codes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mobile TEXT NOT NULL,
        code TEXT NOT NULL,
        expires_at INTEGER NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        used INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_otp_mobile ON otp_codes(mobile)',
    );
  }

  Future<void> _createAdminTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS admin_accounts (
        id TEXT PRIMARY KEY,
        full_name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        mobile TEXT,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'admin',
        status TEXT NOT NULL DEFAULT 'active',
        permissions TEXT NOT NULL DEFAULT 'all',
        department TEXT NOT NULL DEFAULT 'Operations',
        created_at INTEGER NOT NULL,
        last_login INTEGER
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_admin_email ON admin_accounts(email)',
    );
  }

  /// Inserts or updates an admin account in the database.
  Future<void> createAdminAccount(AdminAccount admin) async {
    final database = await this.database;
    final adminCols = await _getTableColumns(database, 'admin_accounts');
    final filteredAdmin = Map<String, Object?>.fromEntries(
      admin.toMap().entries.where(
            (e) => adminCols.isEmpty || adminCols.contains(e.key.toLowerCase()),
          ),
    );
    // Mirror to users table with role 'admin' for relational references
    final userCols = await _getTableColumns(database, 'users');
    final filteredUser = Map<String, Object?>.fromEntries(
      admin.toUser().toMap().entries.where(
            (e) => userCols.isEmpty || userCols.contains(e.key.toLowerCase()),
          ),
    );
    await database.transaction((txn) async {
      for (final entry
          in {'admin_accounts': filteredAdmin, 'users': filteredUser}.entries) {
        final count = await txn.update(entry.key, entry.value,
            where: 'id = ?', whereArgs: [admin.id]);
        if (count == 0) await txn.insert(entry.key, entry.value);
      }
    });
  }

  /// Retrieves all admin accounts stored in the database.
  Future<List<AdminAccount>> getAdminAccounts() async {
    final database = await this.database;
    final rows = await database.query(
      'admin_accounts',
      orderBy: 'created_at DESC',
    );
    if (rows.isNotEmpty) {
      return rows.map((row) => AdminAccount.fromMap(row)).toList();
    }
    // Fallback: check users table for role='admin'
    final userRows = await database.query(
      'users',
      where: 'role = ?',
      whereArgs: [UserRole.admin],
      orderBy: 'created_at DESC',
    );
    return userRows.map(AdminAccount.fromMap).toList();
  }

  /// Finds an admin by unique ID.
  Future<AdminAccount?> getAdminById(String id) async {
    final database = await this.database;
    final rows = await database.query(
      'admin_accounts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return AdminAccount.fromMap(rows.first);
    }
    final userRows = await database.query(
      'users',
      where: 'id = ? AND role = ?',
      whereArgs: [id, UserRole.admin],
      limit: 1,
    );
    if (userRows.isNotEmpty) {
      return AdminAccount.fromMap(userRows.first);
    }
    return null;
  }

  /// Finds an admin by either email or mobile number.
  Future<AdminAccount?> getAdminByIdentifier(String identifier) async {
    final clean = identifier.trim().toLowerCase();
    final database = await this.database;
    final rows = await database.query(
      'admin_accounts',
      where: 'LOWER(email) = ? OR mobile = ?',
      whereArgs: [clean, identifier.trim()],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return AdminAccount.fromMap(rows.first);
    }
    final userRows = await database.query(
      'users',
      where: '(LOWER(email) = ? OR mobile = ?) AND role = ?',
      whereArgs: [clean, identifier.trim(), UserRole.admin],
      limit: 1,
    );
    if (userRows.isNotEmpty) {
      return AdminAccount.fromMap(userRows.first);
    }
    return null;
  }

  /// Updates status of an admin account (e.g. 'active' vs 'deactivated').
  Future<void> updateAdminStatus(String id, String status) async {
    final database = await this.database;
    await database.update(
      'admin_accounts',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
    await database.update(
      'users',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Updates the last login timestamp for an admin account.
  Future<void> updateAdminLastLogin(String id, int timestamp) async {
    final database = await this.database;
    await database.update(
      'admin_accounts',
      {'last_login': timestamp},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Updates password hash for an admin account.
  Future<void> updateAdminPassword(String id, String passwordHash) async {
    final database = await this.database;
    await database.update(
      'admin_accounts',
      {'password_hash': passwordHash},
      where: 'id = ?',
      whereArgs: [id],
    );
    await database.update(
      'users',
      {'password_hash': passwordHash},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Deletes an admin account from the database.
  Future<void> deleteAdminAccount(String id) async {
    final database = await this.database;
    await database.delete(
      'admin_accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
    await database.delete(
      'users',
      where: 'id = ? AND role = ?',
      whereArgs: [id, UserRole.admin],
    );
  }

  // =========================================================================
  // ADMIN & INCIDENT REPORTS (SQLITE PERSISTENCE)
  // =========================================================================

  Future<void> _createReportsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reports (
        id TEXT PRIMARY KEY,
        reporter_id TEXT NOT NULL,
        reporter_name TEXT NOT NULL,
        reporter_role TEXT NOT NULL DEFAULT 'passenger',
        reporter_mobile TEXT,
        reported_user_id TEXT,
        reported_user_name TEXT,
        reported_user_role TEXT,
        ride_id TEXT,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        priority TEXT NOT NULL DEFAULT 'normal',
        admin_notes TEXT NOT NULL DEFAULT '[]',
        resolution_summary TEXT,
        resolved_by_admin_name TEXT,
        created_at INTEGER NOT NULL,
        resolved_at INTEGER
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_reports_status ON reports(status)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_reports_created ON reports(created_at DESC)');
  }

  Future<void> _seedDefaultReports(Database db) async {
    if (!allowTestAccounts) return;
    final count =
        _firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM reports'));
    if (count > 0) return;

    final now = DateTime.now();
    final sampleReports = [
      FireReport(
        id: 'rep-101',
        reporterId: 'test-passenger-1',
        reporterName: 'Maria Santos',
        reporterRole: 'passenger',
        reporterMobile: '09171234567',
        reportedUserId: 'test-driver-1',
        reportedUserName: 'Pedro Reyes',
        reportedUserRole: 'driver',
        rideId: 'ride-cebu-9821',
        type: ReportType.overcharging,
        title: 'Excessive fare charged beyond meter',
        description:
            'Driver asked for an extra ₱50 on top of the calculated ₱75 fare during peak rain in Colon St.',
        status: ReportStatus.pending,
        priority: 'high',
        adminNotes: const ['Assigned to Customer Care for investigation.'],
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      FireReport(
        id: 'rep-102',
        reporterId: 'test-passenger-1',
        reporterName: 'Carlo Mendoza',
        reporterRole: 'passenger',
        reporterMobile: '09189876543',
        reportedUserId: 'test-driver-2',
        reportedUserName: 'Mario Santos',
        reportedUserRole: 'driver',
        rideId: 'ride-mandaue-4412',
        type: ReportType.lostItem,
        title: 'Left black wallet in tricycle back seat',
        description:
            'Left leather wallet containing SSS ID and cash after dropoff near SM City Cebu.',
        status: ReportStatus.underInvestigation,
        priority: 'normal',
        adminNotes: const [
          'Contacted driver via registered mobile. Driver confirmed holding the item.',
          'Arranging pickup at TODA station.'
        ],
        createdAt: now.subtract(const Duration(hours: 14)),
      ),
      FireReport(
        id: 'rep-103',
        reporterId: 'test-driver-1',
        reporterName: 'Pedro Reyes',
        reporterRole: 'driver',
        reporterMobile: '09987654321',
        reportedUserId: 'test-passenger-1',
        reportedUserName: 'Juan Dela Cruz',
        reportedUserRole: 'passenger',
        rideId: 'ride-lapu-7811',
        type: ReportType.passengerBehavior,
        title: 'Passenger refused cash payment upon arrival',
        description:
            'Passenger booked cash ride but claimed GCash had no balance and walked away near Mactan Marina.',
        status: ReportStatus.resolved,
        priority: 'normal',
        adminNotes: const [
          'Passenger contacted and settled payment via platform wallet refund credit.',
          'Account given 1st warning.'
        ],
        resolutionSummary: 'Fare reimbursed to driver wallet. Case closed.',
        resolvedByAdminName: 'Super Admin',
        createdAt: now.subtract(const Duration(days: 2)),
        resolvedAt: now.subtract(const Duration(days: 1)),
      ),
      FireReport(
        id: 'rep-104',
        reporterId: 'test-passenger-1',
        reporterName: 'Elena Reyes',
        reporterRole: 'passenger',
        reporterMobile: '09204443322',
        type: ReportType.safety,
        title: 'Fast driving and broken headlight at night',
        description:
            'Vehicle headlight was flickering off in dark alley along Banilad road.',
        status: ReportStatus.pending,
        priority: 'urgent',
        adminNotes: const ['Flagged for vehicle safety re-inspection.'],
        createdAt: now.subtract(const Duration(minutes: 45)),
      ),
    ];

    for (final rep in sampleReports) {
      await db.insert('reports', {
        'id': rep.id,
        'reporter_id': rep.reporterId,
        'reporter_name': rep.reporterName,
        'reporter_role': rep.reporterRole,
        'reporter_mobile': rep.reporterMobile,
        'reported_user_id': rep.reportedUserId,
        'reported_user_name': rep.reportedUserName,
        'reported_user_role': rep.reportedUserRole,
        'ride_id': rep.rideId,
        'type': rep.type,
        'title': rep.title,
        'description': rep.description,
        'status': rep.status,
        'priority': rep.priority,
        'admin_notes': jsonEncode(rep.adminNotes),
        'resolution_summary': rep.resolutionSummary,
        'resolved_by_admin_name': rep.resolvedByAdminName,
        'created_at': rep.createdAt.millisecondsSinceEpoch,
        'resolved_at': rep.resolvedAt?.millisecondsSinceEpoch,
      });
    }
  }

  Future<void> createReport(FireReport report) async {
    final db = await database;
    await db.insert(
      'reports',
      {
        'id': report.id,
        'reporter_id': report.reporterId,
        'reporter_name': report.reporterName,
        'reporter_role': report.reporterRole,
        'reporter_mobile': report.reporterMobile,
        'reported_user_id': report.reportedUserId,
        'reported_user_name': report.reportedUserName,
        'reported_user_role': report.reportedUserRole,
        'ride_id': report.rideId,
        'type': report.type,
        'title': report.title,
        'description': report.description,
        'status': report.status,
        'priority': report.priority,
        'admin_notes': jsonEncode(report.adminNotes),
        'resolution_summary': report.resolutionSummary,
        'resolved_by_admin_name': report.resolvedByAdminName,
        'created_at': report.createdAt.millisecondsSinceEpoch,
        'resolved_at': report.resolvedAt?.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<FireReport>> getReports({
    String? status,
    String? type,
    String? searchQuery,
  }) async {
    final db = await database;
    final rows = await db.query('reports', orderBy: 'created_at DESC');
    var list = rows.map((r) {
      List<String> notes = [];
      try {
        final raw = r['admin_notes'] as String?;
        if (raw != null) {
          notes = List<String>.from(jsonDecode(raw) as List);
        }
      } catch (_) {}

      return FireReport(
        id: r['id'] as String,
        reporterId: (r['reporter_id'] as String?) ?? '',
        reporterName: (r['reporter_name'] as String?) ?? 'Unknown',
        reporterRole: (r['reporter_role'] as String?) ?? 'passenger',
        reporterMobile: r['reporter_mobile'] as String?,
        reportedUserId: r['reported_user_id'] as String?,
        reportedUserName: r['reported_user_name'] as String?,
        reportedUserRole: r['reported_user_role'] as String?,
        rideId: r['ride_id'] as String?,
        type: (r['type'] as String?) ?? ReportType.other,
        title: (r['title'] as String?) ?? '',
        description: (r['description'] as String?) ?? '',
        status: (r['status'] as String?) ?? ReportStatus.pending,
        priority: (r['priority'] as String?) ?? 'normal',
        adminNotes: notes,
        resolutionSummary: r['resolution_summary'] as String?,
        resolvedByAdminName: r['resolved_by_admin_name'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
        resolvedAt: r['resolved_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(r['resolved_at'] as int)
            : null,
      );
    }).toList();

    if (status != null && status != 'all') {
      list = list
          .where((r) => r.status.toLowerCase() == status.toLowerCase())
          .toList();
    }
    if (type != null && type != 'all') {
      list = list
          .where((r) => r.type.toLowerCase() == type.toLowerCase())
          .toList();
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      list = list
          .where((r) =>
              r.title.toLowerCase().contains(q) ||
              r.description.toLowerCase().contains(q) ||
              r.reporterName.toLowerCase().contains(q) ||
              (r.reportedUserName?.toLowerCase().contains(q) ?? false) ||
              r.id.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  Future<void> addReportNote(String reportId, String note) async {
    final db = await database;
    final rows = await db.query('reports',
        where: 'id = ?', whereArgs: [reportId], limit: 1);
    if (rows.isEmpty) return;

    List<String> notes = [];
    try {
      final raw = rows.first['admin_notes'] as String?;
      if (raw != null) notes = List<String>.from(jsonDecode(raw) as List);
    } catch (_) {}
    notes.add(note);

    await db.update(
      'reports',
      {'admin_notes': jsonEncode(notes)},
      where: 'id = ?',
      whereArgs: [reportId],
    );
  }

  Future<void> updateReportStatus(
    String reportId,
    String status, {
    String? resolution,
    String? adminName,
  }) async {
    final db = await database;
    final Map<String, Object?> updates = {
      'status': status,
    };
    if (resolution != null) {
      updates['resolution_summary'] = resolution;
    }
    if (adminName != null) {
      updates['resolved_by_admin_name'] = adminName;
    }
    if (status == ReportStatus.resolved) {
      updates['resolved_at'] = DateTime.now().millisecondsSinceEpoch;
    }
    await db.update(
      'reports',
      updates,
      where: 'id = ?',
      whereArgs: [reportId],
    );
  }

  // =========================================================================
  // TODA MANAGEMENT (SQLITE PERSISTENCE)
  // =========================================================================

  Future<void> saveToda(Map<String, dynamic> toda) async {
    final db = await database;
    // The local cache schema has no created_at/updated_at columns for this
    // table; sending either field makes the insert fail before Supabase runs.
    await db.insert(
      'toda_associations',
      {
        'id': toda['id'] ?? 'toda-${DateTime.now().millisecondsSinceEpoch}',
        'name': toda['name'] ?? '',
        'code': toda['code'] ?? 'TODA',
        'city': toda['municipality'] ?? toda['city'] ?? 'Cebu City',
        'president': toda['president'] ?? 'Association President',
        'contact_number':
            toda['contactNumber'] ?? toda['contact_number'] ?? '+639170000000',
        'is_active': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteToda(String todaId) async {
    final db = await database;
    await db.delete('toda_associations', where: 'id = ?', whereArgs: [todaId]);
  }

  Future<List<Map<String, dynamic>>> getTodas() async {
    final db = await database;
    final rows = await db.query('toda_associations', orderBy: 'name ASC');
    return rows
        .map((r) => {
              'id': r['id'],
              'name': r['name'],
              'code': r['code'],
              'municipality': r['city'],
              'city': r['city'],
              'area': r['city'],
              'province': 'Cebu',
              'president': r['president'],
              'contact_number': r['contact_number'],
              'is_active': r['is_active'],
            })
        .toList();
  }

  // =========================================================================
  // FARE MATRIX CONFIGURATION
  // =========================================================================

  Future<List<Map<String, dynamic>>> getFareMatrix() async {
    final db = await database;
    return await db.query('fare_matrix');
  }

  Future<void> updateFareMatrix(
      String vehicleType, double baseFare, double perKmRate) async {
    final db = await database;
    final cleanType = vehicleType.trim().toLowerCase();
    final count = await db.update(
      'fare_matrix',
      {
        'base_fare': baseFare,
        'per_km_rate': perKmRate,
        'effective_date': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'vehicle_type = ?',
      whereArgs: [cleanType],
    );
    if (count == 0) {
      await db.insert(
        'fare_matrix',
        {
          'id': 'fm_$cleanType',
          'vehicle_type': cleanType,
          'base_fare': baseFare,
          'base_km': 1.0,
          'per_km_rate': perKmRate,
          'night_diff_percent': 10.0,
          'senior_discount_percent': 20.0,
          'student_discount_percent': 20.0,
          'pwd_discount_percent': 20.0,
          'effective_date': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  // =========================================================================
  // LOCAL PAYMENTS LIST HELPER
  // =========================================================================

  Future<List<FirePayment>> getLocalPayments({
    String? status,
    String? method,
    String? searchQuery,
    int limit = 150,
  }) async {
    final db = await database;
    final trips =
        await db.query('trip', orderBy: 'created_at DESC', limit: limit);
    final refunds =
        (await db.query('admin_refunds')).map((row) => row['ride_id']).toSet();
    List<FirePayment> list = trips.map<FirePayment>((t) {
      final tripId = (t['id'] as String?) ?? '';
      final fare = (t['fare'] as num?)?.toDouble() ?? 0.0;
      final pMethod = (t['payment_method'] as String?) ?? 'cash';
      final tripStatus = (t['status'] as String?) ?? 'completed';
      final createdAt = DateTime.fromMillisecondsSinceEpoch(
        (t['created_at'] as int?) ?? 0,
      );

      final pStatus = refunds.contains(tripId)
          ? 'refunded'
          : (tripStatus == 'completed')
              ? 'paid'
              : (tripStatus == 'cancelled' ? 'cancelled' : 'pending');

      return FirePayment(
        id: 'pay-$tripId',
        rideId: tripId,
        payerId: (t['passenger_id'] as String?) ?? '',
        payeeId: (t['driver_id'] as String?) ?? '',
        amount: fare,
        method: pMethod,
        status: pStatus,
        reference: 'TXN-${(t['created_at'] as int?) ?? 0}',
        createdAt: createdAt,
      );
    }).toList();

    if (status != null && status != 'all') {
      list = list
          .where((p) => p.status.toLowerCase() == status.toLowerCase())
          .toList();
    }
    if (method != null && method != 'all') {
      list = list
          .where((p) => p.method.toLowerCase().contains(method.toLowerCase()))
          .toList();
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      list = list
          .where((p) =>
              p.id.toLowerCase().contains(q) ||
              p.rideId.toLowerCase().contains(q) ||
              (p.reference?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return list;
  }

  Future<void> recordAdminRefund(
      String paymentId, double amount, String reason) async {
    final db = await database;
    final rideId =
        paymentId.startsWith('pay-') ? paymentId.substring(4) : paymentId;
    await db.transaction((txn) async {
      final rows =
          await txn.query('trip', where: 'id = ?', whereArgs: [rideId]);
      if (rows.isEmpty) {
        throw StateError('Payment was not found. Refresh the payments list.');
      }
      final trip = rows.single;
      if (trip['status'] != 'completed') {
        throw StateError('Only completed ride payments can be refunded.');
      }
      final fare = (trip['fare'] as num).toDouble();
      if (!amount.isFinite ||
          amount <= 0 ||
          amount > fare ||
          reason.trim().isEmpty) {
        throw ArgumentError(
            'Enter a refund amount within the paid fare and a reason.');
      }
      final existing = await txn
          .query('admin_refunds', where: 'ride_id = ?', whereArgs: [rideId]);
      if (existing.isNotEmpty) {
        throw StateError(
            'A refund has already been recorded for this payment.');
      }
      await txn.insert('admin_refunds', {
        'ride_id': rideId,
        'amount': amount,
        'reason': reason.trim(),
        'created_at': DateTime.now().millisecondsSinceEpoch
      });
    });
  }

  // =========================================================================
  // PERSISTENT MAP CACHE FOR OFFLINE / LOW-CONNECTIVITY NAVIGATION
  // =========================================================================

  Future<void> saveMapCache(
    String key,
    String dataType,
    String responseJson, {
    Duration ttl = const Duration(days: 14),
  }) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      final expires = now + ttl.inMilliseconds;
      await db.insert(
        'map_cache',
        {
          'cache_key': key,
          'data_type': dataType,
          'response_json': responseJson,
          'created_at': now,
          'expires_at': expires,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<String?> getMapCache(String key) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      final rows = await db.query(
        'map_cache',
        columns: ['response_json', 'expires_at'],
        where: 'cache_key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final expires = (rows.first['expires_at'] as int?) ?? 0;
      if (expires < now) {
        return null;
      }
      return rows.first['response_json'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearExpiredMapCache() async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.delete(
        'map_cache',
        where: 'expires_at < ?',
        whereArgs: [now],
      );
    } catch (_) {}
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
