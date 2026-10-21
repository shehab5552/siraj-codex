// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class UserProfile extends Table with TableInfo<UserProfile, UserProfileData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  UserProfile(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'PRIMARY KEY NOT NULL',
  );
  static const VerificationMeta _singletonSlotMeta = const VerificationMeta(
    'singletonSlot',
  );
  late final GeneratedColumn<int> singletonSlot = GeneratedColumn<int>(
    'singleton_slot',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 1 UNIQUE CHECK (singleton_slot = 1)',
    defaultValue: const CustomExpression('1'),
  );
  static const VerificationMeta _accountEpochMeta = const VerificationMeta(
    'accountEpoch',
  );
  late final GeneratedColumn<String> accountEpoch = GeneratedColumn<String>(
    'account_epoch',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL UNIQUE',
  );
  static const VerificationMeta _usernameNormalizedMeta =
      const VerificationMeta('usernameNormalized');
  late final GeneratedColumn<String> usernameNormalized =
      GeneratedColumn<String>(
        'username_normalized',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL UNIQUE',
      );
  static const VerificationMeta _usernameDisplayMeta = const VerificationMeta(
    'usernameDisplay',
  );
  late final GeneratedColumn<String> usernameDisplay = GeneratedColumn<String>(
    'username_display',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _passwordKdfMeta = const VerificationMeta(
    'passwordKdf',
  );
  late final GeneratedColumn<String> passwordKdf = GeneratedColumn<String>(
    'password_kdf',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (password_kdf = \'PBKDF2-HMAC-SHA256\')',
  );
  static const VerificationMeta _passwordSaltMeta = const VerificationMeta(
    'passwordSalt',
  );
  late final GeneratedColumn<Uint8List> passwordSalt =
      GeneratedColumn<Uint8List>(
        'password_salt',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      );
  static const VerificationMeta _passwordHashMeta = const VerificationMeta(
    'passwordHash',
  );
  late final GeneratedColumn<Uint8List> passwordHash =
      GeneratedColumn<Uint8List>(
        'password_hash',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      );
  static const VerificationMeta _passwordParamsJsonMeta =
      const VerificationMeta('passwordParamsJson');
  late final GeneratedColumn<String> passwordParamsJson =
      GeneratedColumn<String>(
        'password_params_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      );
  static const VerificationMeta _activeSessionNonceHashMeta =
      const VerificationMeta('activeSessionNonceHash');
  late final GeneratedColumn<Uint8List> activeSessionNonceHash =
      GeneratedColumn<Uint8List>(
        'active_session_nonce_hash',
        aliasedName,
        true,
        type: DriftSqlType.blob,
        requiredDuringInsert: false,
        $customConstraints: '',
      );
  static const VerificationMeta _localeMeta = const VerificationMeta('locale');
  late final GeneratedColumn<String> locale = GeneratedColumn<String>(
    'locale',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'ar\'',
    defaultValue: const CustomExpression('\'ar\''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    singletonSlot,
    accountEpoch,
    usernameNormalized,
    usernameDisplay,
    passwordKdf,
    passwordSalt,
    passwordHash,
    passwordParamsJson,
    activeSessionNonceHash,
    locale,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profile';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserProfileData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('singleton_slot')) {
      context.handle(
        _singletonSlotMeta,
        singletonSlot.isAcceptableOrUnknown(
          data['singleton_slot']!,
          _singletonSlotMeta,
        ),
      );
    }
    if (data.containsKey('account_epoch')) {
      context.handle(
        _accountEpochMeta,
        accountEpoch.isAcceptableOrUnknown(
          data['account_epoch']!,
          _accountEpochMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_accountEpochMeta);
    }
    if (data.containsKey('username_normalized')) {
      context.handle(
        _usernameNormalizedMeta,
        usernameNormalized.isAcceptableOrUnknown(
          data['username_normalized']!,
          _usernameNormalizedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_usernameNormalizedMeta);
    }
    if (data.containsKey('username_display')) {
      context.handle(
        _usernameDisplayMeta,
        usernameDisplay.isAcceptableOrUnknown(
          data['username_display']!,
          _usernameDisplayMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_usernameDisplayMeta);
    }
    if (data.containsKey('password_kdf')) {
      context.handle(
        _passwordKdfMeta,
        passwordKdf.isAcceptableOrUnknown(
          data['password_kdf']!,
          _passwordKdfMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_passwordKdfMeta);
    }
    if (data.containsKey('password_salt')) {
      context.handle(
        _passwordSaltMeta,
        passwordSalt.isAcceptableOrUnknown(
          data['password_salt']!,
          _passwordSaltMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_passwordSaltMeta);
    }
    if (data.containsKey('password_hash')) {
      context.handle(
        _passwordHashMeta,
        passwordHash.isAcceptableOrUnknown(
          data['password_hash']!,
          _passwordHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_passwordHashMeta);
    }
    if (data.containsKey('password_params_json')) {
      context.handle(
        _passwordParamsJsonMeta,
        passwordParamsJson.isAcceptableOrUnknown(
          data['password_params_json']!,
          _passwordParamsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_passwordParamsJsonMeta);
    }
    if (data.containsKey('active_session_nonce_hash')) {
      context.handle(
        _activeSessionNonceHashMeta,
        activeSessionNonceHash.isAcceptableOrUnknown(
          data['active_session_nonce_hash']!,
          _activeSessionNonceHashMeta,
        ),
      );
    }
    if (data.containsKey('locale')) {
      context.handle(
        _localeMeta,
        locale.isAcceptableOrUnknown(data['locale']!, _localeMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId};
  @override
  UserProfileData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfileData(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      singletonSlot: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}singleton_slot'],
      )!,
      accountEpoch: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_epoch'],
      )!,
      usernameNormalized: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username_normalized'],
      )!,
      usernameDisplay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username_display'],
      )!,
      passwordKdf: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}password_kdf'],
      )!,
      passwordSalt: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}password_salt'],
      )!,
      passwordHash: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}password_hash'],
      )!,
      passwordParamsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}password_params_json'],
      )!,
      activeSessionNonceHash: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}active_session_nonce_hash'],
      ),
      locale: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locale'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  UserProfile createAlias(String alias) {
    return UserProfile(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class UserProfileData extends DataClass implements Insertable<UserProfileData> {
  final String userId;
  final int singletonSlot;
  final String accountEpoch;
  final String usernameNormalized;
  final String usernameDisplay;
  final String passwordKdf;
  final Uint8List passwordSalt;
  final Uint8List passwordHash;
  final String passwordParamsJson;
  final Uint8List? activeSessionNonceHash;
  final String locale;
  final String createdAt;
  final String updatedAt;
  const UserProfileData({
    required this.userId,
    required this.singletonSlot,
    required this.accountEpoch,
    required this.usernameNormalized,
    required this.usernameDisplay,
    required this.passwordKdf,
    required this.passwordSalt,
    required this.passwordHash,
    required this.passwordParamsJson,
    this.activeSessionNonceHash,
    required this.locale,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['singleton_slot'] = Variable<int>(singletonSlot);
    map['account_epoch'] = Variable<String>(accountEpoch);
    map['username_normalized'] = Variable<String>(usernameNormalized);
    map['username_display'] = Variable<String>(usernameDisplay);
    map['password_kdf'] = Variable<String>(passwordKdf);
    map['password_salt'] = Variable<Uint8List>(passwordSalt);
    map['password_hash'] = Variable<Uint8List>(passwordHash);
    map['password_params_json'] = Variable<String>(passwordParamsJson);
    if (!nullToAbsent || activeSessionNonceHash != null) {
      map['active_session_nonce_hash'] = Variable<Uint8List>(
        activeSessionNonceHash,
      );
    }
    map['locale'] = Variable<String>(locale);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  UserProfileCompanion toCompanion(bool nullToAbsent) {
    return UserProfileCompanion(
      userId: Value(userId),
      singletonSlot: Value(singletonSlot),
      accountEpoch: Value(accountEpoch),
      usernameNormalized: Value(usernameNormalized),
      usernameDisplay: Value(usernameDisplay),
      passwordKdf: Value(passwordKdf),
      passwordSalt: Value(passwordSalt),
      passwordHash: Value(passwordHash),
      passwordParamsJson: Value(passwordParamsJson),
      activeSessionNonceHash: activeSessionNonceHash == null && nullToAbsent
          ? const Value.absent()
          : Value(activeSessionNonceHash),
      locale: Value(locale),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserProfileData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfileData(
      userId: serializer.fromJson<String>(json['user_id']),
      singletonSlot: serializer.fromJson<int>(json['singleton_slot']),
      accountEpoch: serializer.fromJson<String>(json['account_epoch']),
      usernameNormalized: serializer.fromJson<String>(
        json['username_normalized'],
      ),
      usernameDisplay: serializer.fromJson<String>(json['username_display']),
      passwordKdf: serializer.fromJson<String>(json['password_kdf']),
      passwordSalt: serializer.fromJson<Uint8List>(json['password_salt']),
      passwordHash: serializer.fromJson<Uint8List>(json['password_hash']),
      passwordParamsJson: serializer.fromJson<String>(
        json['password_params_json'],
      ),
      activeSessionNonceHash: serializer.fromJson<Uint8List?>(
        json['active_session_nonce_hash'],
      ),
      locale: serializer.fromJson<String>(json['locale']),
      createdAt: serializer.fromJson<String>(json['created_at']),
      updatedAt: serializer.fromJson<String>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'user_id': serializer.toJson<String>(userId),
      'singleton_slot': serializer.toJson<int>(singletonSlot),
      'account_epoch': serializer.toJson<String>(accountEpoch),
      'username_normalized': serializer.toJson<String>(usernameNormalized),
      'username_display': serializer.toJson<String>(usernameDisplay),
      'password_kdf': serializer.toJson<String>(passwordKdf),
      'password_salt': serializer.toJson<Uint8List>(passwordSalt),
      'password_hash': serializer.toJson<Uint8List>(passwordHash),
      'password_params_json': serializer.toJson<String>(passwordParamsJson),
      'active_session_nonce_hash': serializer.toJson<Uint8List?>(
        activeSessionNonceHash,
      ),
      'locale': serializer.toJson<String>(locale),
      'created_at': serializer.toJson<String>(createdAt),
      'updated_at': serializer.toJson<String>(updatedAt),
    };
  }

  UserProfileData copyWith({
    String? userId,
    int? singletonSlot,
    String? accountEpoch,
    String? usernameNormalized,
    String? usernameDisplay,
    String? passwordKdf,
    Uint8List? passwordSalt,
    Uint8List? passwordHash,
    String? passwordParamsJson,
    Value<Uint8List?> activeSessionNonceHash = const Value.absent(),
    String? locale,
    String? createdAt,
    String? updatedAt,
  }) => UserProfileData(
    userId: userId ?? this.userId,
    singletonSlot: singletonSlot ?? this.singletonSlot,
    accountEpoch: accountEpoch ?? this.accountEpoch,
    usernameNormalized: usernameNormalized ?? this.usernameNormalized,
    usernameDisplay: usernameDisplay ?? this.usernameDisplay,
    passwordKdf: passwordKdf ?? this.passwordKdf,
    passwordSalt: passwordSalt ?? this.passwordSalt,
    passwordHash: passwordHash ?? this.passwordHash,
    passwordParamsJson: passwordParamsJson ?? this.passwordParamsJson,
    activeSessionNonceHash: activeSessionNonceHash.present
        ? activeSessionNonceHash.value
        : this.activeSessionNonceHash,
    locale: locale ?? this.locale,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UserProfileData copyWithCompanion(UserProfileCompanion data) {
    return UserProfileData(
      userId: data.userId.present ? data.userId.value : this.userId,
      singletonSlot: data.singletonSlot.present
          ? data.singletonSlot.value
          : this.singletonSlot,
      accountEpoch: data.accountEpoch.present
          ? data.accountEpoch.value
          : this.accountEpoch,
      usernameNormalized: data.usernameNormalized.present
          ? data.usernameNormalized.value
          : this.usernameNormalized,
      usernameDisplay: data.usernameDisplay.present
          ? data.usernameDisplay.value
          : this.usernameDisplay,
      passwordKdf: data.passwordKdf.present
          ? data.passwordKdf.value
          : this.passwordKdf,
      passwordSalt: data.passwordSalt.present
          ? data.passwordSalt.value
          : this.passwordSalt,
      passwordHash: data.passwordHash.present
          ? data.passwordHash.value
          : this.passwordHash,
      passwordParamsJson: data.passwordParamsJson.present
          ? data.passwordParamsJson.value
          : this.passwordParamsJson,
      activeSessionNonceHash: data.activeSessionNonceHash.present
          ? data.activeSessionNonceHash.value
          : this.activeSessionNonceHash,
      locale: data.locale.present ? data.locale.value : this.locale,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfileData(')
          ..write('userId: $userId, ')
          ..write('singletonSlot: $singletonSlot, ')
          ..write('accountEpoch: $accountEpoch, ')
          ..write('usernameNormalized: $usernameNormalized, ')
          ..write('usernameDisplay: $usernameDisplay, ')
          ..write('passwordKdf: $passwordKdf, ')
          ..write('passwordSalt: $passwordSalt, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('passwordParamsJson: $passwordParamsJson, ')
          ..write('activeSessionNonceHash: $activeSessionNonceHash, ')
          ..write('locale: $locale, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userId,
    singletonSlot,
    accountEpoch,
    usernameNormalized,
    usernameDisplay,
    passwordKdf,
    $driftBlobEquality.hash(passwordSalt),
    $driftBlobEquality.hash(passwordHash),
    passwordParamsJson,
    $driftBlobEquality.hash(activeSessionNonceHash),
    locale,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfileData &&
          other.userId == this.userId &&
          other.singletonSlot == this.singletonSlot &&
          other.accountEpoch == this.accountEpoch &&
          other.usernameNormalized == this.usernameNormalized &&
          other.usernameDisplay == this.usernameDisplay &&
          other.passwordKdf == this.passwordKdf &&
          $driftBlobEquality.equals(other.passwordSalt, this.passwordSalt) &&
          $driftBlobEquality.equals(other.passwordHash, this.passwordHash) &&
          other.passwordParamsJson == this.passwordParamsJson &&
          $driftBlobEquality.equals(
            other.activeSessionNonceHash,
            this.activeSessionNonceHash,
          ) &&
          other.locale == this.locale &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class UserProfileCompanion extends UpdateCompanion<UserProfileData> {
  final Value<String> userId;
  final Value<int> singletonSlot;
  final Value<String> accountEpoch;
  final Value<String> usernameNormalized;
  final Value<String> usernameDisplay;
  final Value<String> passwordKdf;
  final Value<Uint8List> passwordSalt;
  final Value<Uint8List> passwordHash;
  final Value<String> passwordParamsJson;
  final Value<Uint8List?> activeSessionNonceHash;
  final Value<String> locale;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const UserProfileCompanion({
    this.userId = const Value.absent(),
    this.singletonSlot = const Value.absent(),
    this.accountEpoch = const Value.absent(),
    this.usernameNormalized = const Value.absent(),
    this.usernameDisplay = const Value.absent(),
    this.passwordKdf = const Value.absent(),
    this.passwordSalt = const Value.absent(),
    this.passwordHash = const Value.absent(),
    this.passwordParamsJson = const Value.absent(),
    this.activeSessionNonceHash = const Value.absent(),
    this.locale = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserProfileCompanion.insert({
    required String userId,
    this.singletonSlot = const Value.absent(),
    required String accountEpoch,
    required String usernameNormalized,
    required String usernameDisplay,
    required String passwordKdf,
    required Uint8List passwordSalt,
    required Uint8List passwordHash,
    required String passwordParamsJson,
    this.activeSessionNonceHash = const Value.absent(),
    this.locale = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       accountEpoch = Value(accountEpoch),
       usernameNormalized = Value(usernameNormalized),
       usernameDisplay = Value(usernameDisplay),
       passwordKdf = Value(passwordKdf),
       passwordSalt = Value(passwordSalt),
       passwordHash = Value(passwordHash),
       passwordParamsJson = Value(passwordParamsJson),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<UserProfileData> custom({
    Expression<String>? userId,
    Expression<int>? singletonSlot,
    Expression<String>? accountEpoch,
    Expression<String>? usernameNormalized,
    Expression<String>? usernameDisplay,
    Expression<String>? passwordKdf,
    Expression<Uint8List>? passwordSalt,
    Expression<Uint8List>? passwordHash,
    Expression<String>? passwordParamsJson,
    Expression<Uint8List>? activeSessionNonceHash,
    Expression<String>? locale,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (singletonSlot != null) 'singleton_slot': singletonSlot,
      if (accountEpoch != null) 'account_epoch': accountEpoch,
      if (usernameNormalized != null) 'username_normalized': usernameNormalized,
      if (usernameDisplay != null) 'username_display': usernameDisplay,
      if (passwordKdf != null) 'password_kdf': passwordKdf,
      if (passwordSalt != null) 'password_salt': passwordSalt,
      if (passwordHash != null) 'password_hash': passwordHash,
      if (passwordParamsJson != null)
        'password_params_json': passwordParamsJson,
      if (activeSessionNonceHash != null)
        'active_session_nonce_hash': activeSessionNonceHash,
      if (locale != null) 'locale': locale,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserProfileCompanion copyWith({
    Value<String>? userId,
    Value<int>? singletonSlot,
    Value<String>? accountEpoch,
    Value<String>? usernameNormalized,
    Value<String>? usernameDisplay,
    Value<String>? passwordKdf,
    Value<Uint8List>? passwordSalt,
    Value<Uint8List>? passwordHash,
    Value<String>? passwordParamsJson,
    Value<Uint8List?>? activeSessionNonceHash,
    Value<String>? locale,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return UserProfileCompanion(
      userId: userId ?? this.userId,
      singletonSlot: singletonSlot ?? this.singletonSlot,
      accountEpoch: accountEpoch ?? this.accountEpoch,
      usernameNormalized: usernameNormalized ?? this.usernameNormalized,
      usernameDisplay: usernameDisplay ?? this.usernameDisplay,
      passwordKdf: passwordKdf ?? this.passwordKdf,
      passwordSalt: passwordSalt ?? this.passwordSalt,
      passwordHash: passwordHash ?? this.passwordHash,
      passwordParamsJson: passwordParamsJson ?? this.passwordParamsJson,
      activeSessionNonceHash:
          activeSessionNonceHash ?? this.activeSessionNonceHash,
      locale: locale ?? this.locale,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (singletonSlot.present) {
      map['singleton_slot'] = Variable<int>(singletonSlot.value);
    }
    if (accountEpoch.present) {
      map['account_epoch'] = Variable<String>(accountEpoch.value);
    }
    if (usernameNormalized.present) {
      map['username_normalized'] = Variable<String>(usernameNormalized.value);
    }
    if (usernameDisplay.present) {
      map['username_display'] = Variable<String>(usernameDisplay.value);
    }
    if (passwordKdf.present) {
      map['password_kdf'] = Variable<String>(passwordKdf.value);
    }
    if (passwordSalt.present) {
      map['password_salt'] = Variable<Uint8List>(passwordSalt.value);
    }
    if (passwordHash.present) {
      map['password_hash'] = Variable<Uint8List>(passwordHash.value);
    }
    if (passwordParamsJson.present) {
      map['password_params_json'] = Variable<String>(passwordParamsJson.value);
    }
    if (activeSessionNonceHash.present) {
      map['active_session_nonce_hash'] = Variable<Uint8List>(
        activeSessionNonceHash.value,
      );
    }
    if (locale.present) {
      map['locale'] = Variable<String>(locale.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfileCompanion(')
          ..write('userId: $userId, ')
          ..write('singletonSlot: $singletonSlot, ')
          ..write('accountEpoch: $accountEpoch, ')
          ..write('usernameNormalized: $usernameNormalized, ')
          ..write('usernameDisplay: $usernameDisplay, ')
          ..write('passwordKdf: $passwordKdf, ')
          ..write('passwordSalt: $passwordSalt, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('passwordParamsJson: $passwordParamsJson, ')
          ..write('activeSessionNonceHash: $activeSessionNonceHash, ')
          ..write('locale: $locale, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Conversation extends Table
    with TableInfo<Conversation, ConversationData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Conversation(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'PRIMARY KEY NOT NULL',
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL REFERENCES user_profile(user_id)ON DELETE CASCADE',
  );
  static const VerificationMeta _activeScopeJsonMeta = const VerificationMeta(
    'activeScopeJson',
  );
  late final GeneratedColumn<String> activeScopeJson = GeneratedColumn<String>(
    'active_scope_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    conversationId,
    userId,
    activeScopeJson,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversation';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConversationData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('active_scope_json')) {
      context.handle(
        _activeScopeJsonMeta,
        activeScopeJson.isAcceptableOrUnknown(
          data['active_scope_json']!,
          _activeScopeJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {conversationId};
  @override
  ConversationData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationData(
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      activeScopeJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}active_scope_json'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  Conversation createAlias(String alias) {
    return Conversation(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class ConversationData extends DataClass
    implements Insertable<ConversationData> {
  final String conversationId;
  final String userId;
  final String? activeScopeJson;
  final String createdAt;
  final String updatedAt;
  const ConversationData({
    required this.conversationId,
    required this.userId,
    this.activeScopeJson,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['conversation_id'] = Variable<String>(conversationId);
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || activeScopeJson != null) {
      map['active_scope_json'] = Variable<String>(activeScopeJson);
    }
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  ConversationCompanion toCompanion(bool nullToAbsent) {
    return ConversationCompanion(
      conversationId: Value(conversationId),
      userId: Value(userId),
      activeScopeJson: activeScopeJson == null && nullToAbsent
          ? const Value.absent()
          : Value(activeScopeJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ConversationData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationData(
      conversationId: serializer.fromJson<String>(json['conversation_id']),
      userId: serializer.fromJson<String>(json['user_id']),
      activeScopeJson: serializer.fromJson<String?>(json['active_scope_json']),
      createdAt: serializer.fromJson<String>(json['created_at']),
      updatedAt: serializer.fromJson<String>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'conversation_id': serializer.toJson<String>(conversationId),
      'user_id': serializer.toJson<String>(userId),
      'active_scope_json': serializer.toJson<String?>(activeScopeJson),
      'created_at': serializer.toJson<String>(createdAt),
      'updated_at': serializer.toJson<String>(updatedAt),
    };
  }

  ConversationData copyWith({
    String? conversationId,
    String? userId,
    Value<String?> activeScopeJson = const Value.absent(),
    String? createdAt,
    String? updatedAt,
  }) => ConversationData(
    conversationId: conversationId ?? this.conversationId,
    userId: userId ?? this.userId,
    activeScopeJson: activeScopeJson.present
        ? activeScopeJson.value
        : this.activeScopeJson,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ConversationData copyWithCompanion(ConversationCompanion data) {
    return ConversationData(
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      userId: data.userId.present ? data.userId.value : this.userId,
      activeScopeJson: data.activeScopeJson.present
          ? data.activeScopeJson.value
          : this.activeScopeJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationData(')
          ..write('conversationId: $conversationId, ')
          ..write('userId: $userId, ')
          ..write('activeScopeJson: $activeScopeJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    conversationId,
    userId,
    activeScopeJson,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationData &&
          other.conversationId == this.conversationId &&
          other.userId == this.userId &&
          other.activeScopeJson == this.activeScopeJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ConversationCompanion extends UpdateCompanion<ConversationData> {
  final Value<String> conversationId;
  final Value<String> userId;
  final Value<String?> activeScopeJson;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const ConversationCompanion({
    this.conversationId = const Value.absent(),
    this.userId = const Value.absent(),
    this.activeScopeJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationCompanion.insert({
    required String conversationId,
    required String userId,
    this.activeScopeJson = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : conversationId = Value(conversationId),
       userId = Value(userId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ConversationData> custom({
    Expression<String>? conversationId,
    Expression<String>? userId,
    Expression<String>? activeScopeJson,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (conversationId != null) 'conversation_id': conversationId,
      if (userId != null) 'user_id': userId,
      if (activeScopeJson != null) 'active_scope_json': activeScopeJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationCompanion copyWith({
    Value<String>? conversationId,
    Value<String>? userId,
    Value<String?>? activeScopeJson,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return ConversationCompanion(
      conversationId: conversationId ?? this.conversationId,
      userId: userId ?? this.userId,
      activeScopeJson: activeScopeJson ?? this.activeScopeJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (activeScopeJson.present) {
      map['active_scope_json'] = Variable<String>(activeScopeJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationCompanion(')
          ..write('conversationId: $conversationId, ')
          ..write('userId: $userId, ')
          ..write('activeScopeJson: $activeScopeJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Message extends Table with TableInfo<Message, MessageData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Message(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'PRIMARY KEY NOT NULL',
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL REFERENCES conversation(conversation_id)ON DELETE CASCADE',
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (role IN (\'USER\', \'ASSISTANT\'))',
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _sourceRefsJsonMeta = const VerificationMeta(
    'sourceRefsJson',
  );
  late final GeneratedColumn<String> sourceRefsJson = GeneratedColumn<String>(
    'source_refs_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'[]\'',
    defaultValue: const CustomExpression('\'[]\''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    messageId,
    conversationId,
    role,
    content,
    sourceRefsJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'message';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('source_refs_json')) {
      context.handle(
        _sourceRefsJsonMeta,
        sourceRefsJson.isAcceptableOrUnknown(
          data['source_refs_json']!,
          _sourceRefsJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId};
  @override
  MessageData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageData(
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      sourceRefsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_refs_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  Message createAlias(String alias) {
    return Message(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class MessageData extends DataClass implements Insertable<MessageData> {
  final String messageId;
  final String conversationId;
  final String role;
  final String content;
  final String sourceRefsJson;
  final String createdAt;
  const MessageData({
    required this.messageId,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.sourceRefsJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['message_id'] = Variable<String>(messageId);
    map['conversation_id'] = Variable<String>(conversationId);
    map['role'] = Variable<String>(role);
    map['content'] = Variable<String>(content);
    map['source_refs_json'] = Variable<String>(sourceRefsJson);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  MessageCompanion toCompanion(bool nullToAbsent) {
    return MessageCompanion(
      messageId: Value(messageId),
      conversationId: Value(conversationId),
      role: Value(role),
      content: Value(content),
      sourceRefsJson: Value(sourceRefsJson),
      createdAt: Value(createdAt),
    );
  }

  factory MessageData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageData(
      messageId: serializer.fromJson<String>(json['message_id']),
      conversationId: serializer.fromJson<String>(json['conversation_id']),
      role: serializer.fromJson<String>(json['role']),
      content: serializer.fromJson<String>(json['content']),
      sourceRefsJson: serializer.fromJson<String>(json['source_refs_json']),
      createdAt: serializer.fromJson<String>(json['created_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'message_id': serializer.toJson<String>(messageId),
      'conversation_id': serializer.toJson<String>(conversationId),
      'role': serializer.toJson<String>(role),
      'content': serializer.toJson<String>(content),
      'source_refs_json': serializer.toJson<String>(sourceRefsJson),
      'created_at': serializer.toJson<String>(createdAt),
    };
  }

  MessageData copyWith({
    String? messageId,
    String? conversationId,
    String? role,
    String? content,
    String? sourceRefsJson,
    String? createdAt,
  }) => MessageData(
    messageId: messageId ?? this.messageId,
    conversationId: conversationId ?? this.conversationId,
    role: role ?? this.role,
    content: content ?? this.content,
    sourceRefsJson: sourceRefsJson ?? this.sourceRefsJson,
    createdAt: createdAt ?? this.createdAt,
  );
  MessageData copyWithCompanion(MessageCompanion data) {
    return MessageData(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      role: data.role.present ? data.role.value : this.role,
      content: data.content.present ? data.content.value : this.content,
      sourceRefsJson: data.sourceRefsJson.present
          ? data.sourceRefsJson.value
          : this.sourceRefsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageData(')
          ..write('messageId: $messageId, ')
          ..write('conversationId: $conversationId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('sourceRefsJson: $sourceRefsJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    messageId,
    conversationId,
    role,
    content,
    sourceRefsJson,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageData &&
          other.messageId == this.messageId &&
          other.conversationId == this.conversationId &&
          other.role == this.role &&
          other.content == this.content &&
          other.sourceRefsJson == this.sourceRefsJson &&
          other.createdAt == this.createdAt);
}

class MessageCompanion extends UpdateCompanion<MessageData> {
  final Value<String> messageId;
  final Value<String> conversationId;
  final Value<String> role;
  final Value<String> content;
  final Value<String> sourceRefsJson;
  final Value<String> createdAt;
  final Value<int> rowid;
  const MessageCompanion({
    this.messageId = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.role = const Value.absent(),
    this.content = const Value.absent(),
    this.sourceRefsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessageCompanion.insert({
    required String messageId,
    required String conversationId,
    required String role,
    required String content,
    this.sourceRefsJson = const Value.absent(),
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : messageId = Value(messageId),
       conversationId = Value(conversationId),
       role = Value(role),
       content = Value(content),
       createdAt = Value(createdAt);
  static Insertable<MessageData> custom({
    Expression<String>? messageId,
    Expression<String>? conversationId,
    Expression<String>? role,
    Expression<String>? content,
    Expression<String>? sourceRefsJson,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageId != null) 'message_id': messageId,
      if (conversationId != null) 'conversation_id': conversationId,
      if (role != null) 'role': role,
      if (content != null) 'content': content,
      if (sourceRefsJson != null) 'source_refs_json': sourceRefsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessageCompanion copyWith({
    Value<String>? messageId,
    Value<String>? conversationId,
    Value<String>? role,
    Value<String>? content,
    Value<String>? sourceRefsJson,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return MessageCompanion(
      messageId: messageId ?? this.messageId,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      sourceRefsJson: sourceRefsJson ?? this.sourceRefsJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (sourceRefsJson.present) {
      map['source_refs_json'] = Variable<String>(sourceRefsJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessageCompanion(')
          ..write('messageId: $messageId, ')
          ..write('conversationId: $conversationId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('sourceRefsJson: $sourceRefsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class AppSetting extends Table with TableInfo<AppSetting, AppSettingData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  AppSetting(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL REFERENCES user_profile(user_id)ON DELETE CASCADE',
  );
  static const VerificationMeta _settingKeyMeta = const VerificationMeta(
    'settingKey',
  );
  late final GeneratedColumn<String> settingKey = GeneratedColumn<String>(
    'setting_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _valueJsonMeta = const VerificationMeta(
    'valueJson',
  );
  late final GeneratedColumn<String> valueJson = GeneratedColumn<String>(
    'value_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    settingKey,
    valueJson,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_setting';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSettingData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('setting_key')) {
      context.handle(
        _settingKeyMeta,
        settingKey.isAcceptableOrUnknown(data['setting_key']!, _settingKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_settingKeyMeta);
    }
    if (data.containsKey('value_json')) {
      context.handle(
        _valueJsonMeta,
        valueJson.isAcceptableOrUnknown(data['value_json']!, _valueJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_valueJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, settingKey};
  @override
  AppSettingData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingData(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      settingKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}setting_key'],
      )!,
      valueJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  AppSetting createAlias(String alias) {
    return AppSetting(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(user_id, setting_key)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class AppSettingData extends DataClass implements Insertable<AppSettingData> {
  final String userId;
  final String settingKey;
  final String valueJson;
  final String updatedAt;
  const AppSettingData({
    required this.userId,
    required this.settingKey,
    required this.valueJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['setting_key'] = Variable<String>(settingKey);
    map['value_json'] = Variable<String>(valueJson);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  AppSettingCompanion toCompanion(bool nullToAbsent) {
    return AppSettingCompanion(
      userId: Value(userId),
      settingKey: Value(settingKey),
      valueJson: Value(valueJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppSettingData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingData(
      userId: serializer.fromJson<String>(json['user_id']),
      settingKey: serializer.fromJson<String>(json['setting_key']),
      valueJson: serializer.fromJson<String>(json['value_json']),
      updatedAt: serializer.fromJson<String>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'user_id': serializer.toJson<String>(userId),
      'setting_key': serializer.toJson<String>(settingKey),
      'value_json': serializer.toJson<String>(valueJson),
      'updated_at': serializer.toJson<String>(updatedAt),
    };
  }

  AppSettingData copyWith({
    String? userId,
    String? settingKey,
    String? valueJson,
    String? updatedAt,
  }) => AppSettingData(
    userId: userId ?? this.userId,
    settingKey: settingKey ?? this.settingKey,
    valueJson: valueJson ?? this.valueJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AppSettingData copyWithCompanion(AppSettingCompanion data) {
    return AppSettingData(
      userId: data.userId.present ? data.userId.value : this.userId,
      settingKey: data.settingKey.present
          ? data.settingKey.value
          : this.settingKey,
      valueJson: data.valueJson.present ? data.valueJson.value : this.valueJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingData(')
          ..write('userId: $userId, ')
          ..write('settingKey: $settingKey, ')
          ..write('valueJson: $valueJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, settingKey, valueJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingData &&
          other.userId == this.userId &&
          other.settingKey == this.settingKey &&
          other.valueJson == this.valueJson &&
          other.updatedAt == this.updatedAt);
}

class AppSettingCompanion extends UpdateCompanion<AppSettingData> {
  final Value<String> userId;
  final Value<String> settingKey;
  final Value<String> valueJson;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const AppSettingCompanion({
    this.userId = const Value.absent(),
    this.settingKey = const Value.absent(),
    this.valueJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingCompanion.insert({
    required String userId,
    required String settingKey,
    required String valueJson,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       settingKey = Value(settingKey),
       valueJson = Value(valueJson),
       updatedAt = Value(updatedAt);
  static Insertable<AppSettingData> custom({
    Expression<String>? userId,
    Expression<String>? settingKey,
    Expression<String>? valueJson,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (settingKey != null) 'setting_key': settingKey,
      if (valueJson != null) 'value_json': valueJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingCompanion copyWith({
    Value<String>? userId,
    Value<String>? settingKey,
    Value<String>? valueJson,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return AppSettingCompanion(
      userId: userId ?? this.userId,
      settingKey: settingKey ?? this.settingKey,
      valueJson: valueJson ?? this.valueJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (settingKey.present) {
      map['setting_key'] = Variable<String>(settingKey.value);
    }
    if (valueJson.present) {
      map['value_json'] = Variable<String>(valueJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingCompanion(')
          ..write('userId: $userId, ')
          ..write('settingKey: $settingKey, ')
          ..write('valueJson: $valueJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class InstalledResource extends Table
    with TableInfo<InstalledResource, InstalledResourceData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  InstalledResource(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _resourceIdMeta = const VerificationMeta(
    'resourceId',
  );
  late final GeneratedColumn<String> resourceId = GeneratedColumn<String>(
    'resource_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (kind IN (\'LLM\', \'RAG_PACK\', \'RAG_EMBEDDING\', \'PDF\'))',
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  late final GeneratedColumn<String> revision = GeneratedColumn<String>(
    'revision',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _manifestJsonMeta = const VerificationMeta(
    'manifestJson',
  );
  late final GeneratedColumn<String> manifestJson = GeneratedColumn<String>(
    'manifest_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    resourceId,
    kind,
    revision,
    state,
    localPath,
    manifestJson,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'installed_resource';
  @override
  VerificationContext validateIntegrity(
    Insertable<InstalledResourceData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('resource_id')) {
      context.handle(
        _resourceIdMeta,
        resourceId.isAcceptableOrUnknown(data['resource_id']!, _resourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_resourceIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    if (data.containsKey('manifest_json')) {
      context.handle(
        _manifestJsonMeta,
        manifestJson.isAcceptableOrUnknown(
          data['manifest_json']!,
          _manifestJsonMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {kind, resourceId};
  @override
  InstalledResourceData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InstalledResourceData(
      resourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resource_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}revision'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      manifestJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manifest_json'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  InstalledResource createAlias(String alias) {
    return InstalledResource(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(kind, resource_id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class InstalledResourceData extends DataClass
    implements Insertable<InstalledResourceData> {
  final String resourceId;
  final String kind;
  final String? revision;
  final String state;
  final String? localPath;
  final String? manifestJson;
  final String updatedAt;
  const InstalledResourceData({
    required this.resourceId,
    required this.kind,
    this.revision,
    required this.state,
    this.localPath,
    this.manifestJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['resource_id'] = Variable<String>(resourceId);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || revision != null) {
      map['revision'] = Variable<String>(revision);
    }
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    if (!nullToAbsent || manifestJson != null) {
      map['manifest_json'] = Variable<String>(manifestJson);
    }
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  InstalledResourceCompanion toCompanion(bool nullToAbsent) {
    return InstalledResourceCompanion(
      resourceId: Value(resourceId),
      kind: Value(kind),
      revision: revision == null && nullToAbsent
          ? const Value.absent()
          : Value(revision),
      state: Value(state),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      manifestJson: manifestJson == null && nullToAbsent
          ? const Value.absent()
          : Value(manifestJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory InstalledResourceData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InstalledResourceData(
      resourceId: serializer.fromJson<String>(json['resource_id']),
      kind: serializer.fromJson<String>(json['kind']),
      revision: serializer.fromJson<String?>(json['revision']),
      state: serializer.fromJson<String>(json['state']),
      localPath: serializer.fromJson<String?>(json['local_path']),
      manifestJson: serializer.fromJson<String?>(json['manifest_json']),
      updatedAt: serializer.fromJson<String>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'resource_id': serializer.toJson<String>(resourceId),
      'kind': serializer.toJson<String>(kind),
      'revision': serializer.toJson<String?>(revision),
      'state': serializer.toJson<String>(state),
      'local_path': serializer.toJson<String?>(localPath),
      'manifest_json': serializer.toJson<String?>(manifestJson),
      'updated_at': serializer.toJson<String>(updatedAt),
    };
  }

  InstalledResourceData copyWith({
    String? resourceId,
    String? kind,
    Value<String?> revision = const Value.absent(),
    String? state,
    Value<String?> localPath = const Value.absent(),
    Value<String?> manifestJson = const Value.absent(),
    String? updatedAt,
  }) => InstalledResourceData(
    resourceId: resourceId ?? this.resourceId,
    kind: kind ?? this.kind,
    revision: revision.present ? revision.value : this.revision,
    state: state ?? this.state,
    localPath: localPath.present ? localPath.value : this.localPath,
    manifestJson: manifestJson.present ? manifestJson.value : this.manifestJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  InstalledResourceData copyWithCompanion(InstalledResourceCompanion data) {
    return InstalledResourceData(
      resourceId: data.resourceId.present
          ? data.resourceId.value
          : this.resourceId,
      kind: data.kind.present ? data.kind.value : this.kind,
      revision: data.revision.present ? data.revision.value : this.revision,
      state: data.state.present ? data.state.value : this.state,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      manifestJson: data.manifestJson.present
          ? data.manifestJson.value
          : this.manifestJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InstalledResourceData(')
          ..write('resourceId: $resourceId, ')
          ..write('kind: $kind, ')
          ..write('revision: $revision, ')
          ..write('state: $state, ')
          ..write('localPath: $localPath, ')
          ..write('manifestJson: $manifestJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    resourceId,
    kind,
    revision,
    state,
    localPath,
    manifestJson,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InstalledResourceData &&
          other.resourceId == this.resourceId &&
          other.kind == this.kind &&
          other.revision == this.revision &&
          other.state == this.state &&
          other.localPath == this.localPath &&
          other.manifestJson == this.manifestJson &&
          other.updatedAt == this.updatedAt);
}

class InstalledResourceCompanion
    extends UpdateCompanion<InstalledResourceData> {
  final Value<String> resourceId;
  final Value<String> kind;
  final Value<String?> revision;
  final Value<String> state;
  final Value<String?> localPath;
  final Value<String?> manifestJson;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const InstalledResourceCompanion({
    this.resourceId = const Value.absent(),
    this.kind = const Value.absent(),
    this.revision = const Value.absent(),
    this.state = const Value.absent(),
    this.localPath = const Value.absent(),
    this.manifestJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InstalledResourceCompanion.insert({
    required String resourceId,
    required String kind,
    this.revision = const Value.absent(),
    required String state,
    this.localPath = const Value.absent(),
    this.manifestJson = const Value.absent(),
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : resourceId = Value(resourceId),
       kind = Value(kind),
       state = Value(state),
       updatedAt = Value(updatedAt);
  static Insertable<InstalledResourceData> custom({
    Expression<String>? resourceId,
    Expression<String>? kind,
    Expression<String>? revision,
    Expression<String>? state,
    Expression<String>? localPath,
    Expression<String>? manifestJson,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (resourceId != null) 'resource_id': resourceId,
      if (kind != null) 'kind': kind,
      if (revision != null) 'revision': revision,
      if (state != null) 'state': state,
      if (localPath != null) 'local_path': localPath,
      if (manifestJson != null) 'manifest_json': manifestJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InstalledResourceCompanion copyWith({
    Value<String>? resourceId,
    Value<String>? kind,
    Value<String?>? revision,
    Value<String>? state,
    Value<String?>? localPath,
    Value<String?>? manifestJson,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return InstalledResourceCompanion(
      resourceId: resourceId ?? this.resourceId,
      kind: kind ?? this.kind,
      revision: revision ?? this.revision,
      state: state ?? this.state,
      localPath: localPath ?? this.localPath,
      manifestJson: manifestJson ?? this.manifestJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (resourceId.present) {
      map['resource_id'] = Variable<String>(resourceId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (revision.present) {
      map['revision'] = Variable<String>(revision.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (manifestJson.present) {
      map['manifest_json'] = Variable<String>(manifestJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InstalledResourceCompanion(')
          ..write('resourceId: $resourceId, ')
          ..write('kind: $kind, ')
          ..write('revision: $revision, ')
          ..write('state: $state, ')
          ..write('localPath: $localPath, ')
          ..write('manifestJson: $manifestJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final UserProfile userProfile = UserProfile(this);
  late final Conversation conversation = Conversation(this);
  late final Index ixConversationOwnerCreated = Index(
    'ix_conversation_owner_created',
    'CREATE INDEX ix_conversation_owner_created ON conversation (user_id, created_at, conversation_id)',
  );
  late final Message message = Message(this);
  late final Index ixMessageConversationCreated = Index(
    'ix_message_conversation_created',
    'CREATE INDEX ix_message_conversation_created ON message (conversation_id, created_at, message_id)',
  );
  late final AppSetting appSetting = AppSetting(this);
  late final InstalledResource installedResource = InstalledResource(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    userProfile,
    conversation,
    ixConversationOwnerCreated,
    message,
    ixMessageConversationCreated,
    appSetting,
    installedResource,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'user_profile',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('conversation', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'conversation',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('message', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'user_profile',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('app_setting', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $UserProfileCreateCompanionBuilder =
    UserProfileCompanion Function({
      required String userId,
      Value<int> singletonSlot,
      required String accountEpoch,
      required String usernameNormalized,
      required String usernameDisplay,
      required String passwordKdf,
      required Uint8List passwordSalt,
      required Uint8List passwordHash,
      required String passwordParamsJson,
      Value<Uint8List?> activeSessionNonceHash,
      Value<String> locale,
      required String createdAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $UserProfileUpdateCompanionBuilder =
    UserProfileCompanion Function({
      Value<String> userId,
      Value<int> singletonSlot,
      Value<String> accountEpoch,
      Value<String> usernameNormalized,
      Value<String> usernameDisplay,
      Value<String> passwordKdf,
      Value<Uint8List> passwordSalt,
      Value<Uint8List> passwordHash,
      Value<String> passwordParamsJson,
      Value<Uint8List?> activeSessionNonceHash,
      Value<String> locale,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

final class $UserProfileReferences
    extends BaseReferences<_$AppDatabase, UserProfile, UserProfileData> {
  $UserProfileReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<Conversation, List<ConversationData>>
  _conversationRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.conversation,
    aliasName: $_aliasNameGenerator(
      db.userProfile.userId,
      db.conversation.userId,
    ),
  );

  $ConversationProcessedTableManager get conversationRefs {
    final manager = $ConversationTableManager($_db, $_db.conversation).filter(
      (f) => f.userId.userId.sqlEquals($_itemColumn<String>('user_id')!),
    );

    final cache = $_typedResult.readTableOrNull(_conversationRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<AppSetting, List<AppSettingData>>
  _appSettingRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.appSetting,
    aliasName: $_aliasNameGenerator(
      db.userProfile.userId,
      db.appSetting.userId,
    ),
  );

  $AppSettingProcessedTableManager get appSettingRefs {
    final manager = $AppSettingTableManager($_db, $_db.appSetting).filter(
      (f) => f.userId.userId.sqlEquals($_itemColumn<String>('user_id')!),
    );

    final cache = $_typedResult.readTableOrNull(_appSettingRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $UserProfileFilterComposer extends Composer<_$AppDatabase, UserProfile> {
  $UserProfileFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get singletonSlot => $composableBuilder(
    column: $table.singletonSlot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountEpoch => $composableBuilder(
    column: $table.accountEpoch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get usernameNormalized => $composableBuilder(
    column: $table.usernameNormalized,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get usernameDisplay => $composableBuilder(
    column: $table.usernameDisplay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get passwordKdf => $composableBuilder(
    column: $table.passwordKdf,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get passwordSalt => $composableBuilder(
    column: $table.passwordSalt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get passwordParamsJson => $composableBuilder(
    column: $table.passwordParamsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get activeSessionNonceHash => $composableBuilder(
    column: $table.activeSessionNonceHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locale => $composableBuilder(
    column: $table.locale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> conversationRefs(
    Expression<bool> Function($ConversationFilterComposer f) f,
  ) {
    final $ConversationFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.conversation,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ConversationFilterComposer(
            $db: $db,
            $table: $db.conversation,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> appSettingRefs(
    Expression<bool> Function($AppSettingFilterComposer f) f,
  ) {
    final $AppSettingFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.appSetting,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $AppSettingFilterComposer(
            $db: $db,
            $table: $db.appSetting,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $UserProfileOrderingComposer
    extends Composer<_$AppDatabase, UserProfile> {
  $UserProfileOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get singletonSlot => $composableBuilder(
    column: $table.singletonSlot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountEpoch => $composableBuilder(
    column: $table.accountEpoch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get usernameNormalized => $composableBuilder(
    column: $table.usernameNormalized,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get usernameDisplay => $composableBuilder(
    column: $table.usernameDisplay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get passwordKdf => $composableBuilder(
    column: $table.passwordKdf,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get passwordSalt => $composableBuilder(
    column: $table.passwordSalt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get passwordParamsJson => $composableBuilder(
    column: $table.passwordParamsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get activeSessionNonceHash => $composableBuilder(
    column: $table.activeSessionNonceHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locale => $composableBuilder(
    column: $table.locale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $UserProfileAnnotationComposer
    extends Composer<_$AppDatabase, UserProfile> {
  $UserProfileAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get singletonSlot => $composableBuilder(
    column: $table.singletonSlot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accountEpoch => $composableBuilder(
    column: $table.accountEpoch,
    builder: (column) => column,
  );

  GeneratedColumn<String> get usernameNormalized => $composableBuilder(
    column: $table.usernameNormalized,
    builder: (column) => column,
  );

  GeneratedColumn<String> get usernameDisplay => $composableBuilder(
    column: $table.usernameDisplay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get passwordKdf => $composableBuilder(
    column: $table.passwordKdf,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get passwordSalt => $composableBuilder(
    column: $table.passwordSalt,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get passwordParamsJson => $composableBuilder(
    column: $table.passwordParamsJson,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get activeSessionNonceHash => $composableBuilder(
    column: $table.activeSessionNonceHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get locale =>
      $composableBuilder(column: $table.locale, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> conversationRefs<T extends Object>(
    Expression<T> Function($ConversationAnnotationComposer a) f,
  ) {
    final $ConversationAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.conversation,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ConversationAnnotationComposer(
            $db: $db,
            $table: $db.conversation,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> appSettingRefs<T extends Object>(
    Expression<T> Function($AppSettingAnnotationComposer a) f,
  ) {
    final $AppSettingAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.appSetting,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $AppSettingAnnotationComposer(
            $db: $db,
            $table: $db.appSetting,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $UserProfileTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          UserProfile,
          UserProfileData,
          $UserProfileFilterComposer,
          $UserProfileOrderingComposer,
          $UserProfileAnnotationComposer,
          $UserProfileCreateCompanionBuilder,
          $UserProfileUpdateCompanionBuilder,
          (UserProfileData, $UserProfileReferences),
          UserProfileData,
          PrefetchHooks Function({bool conversationRefs, bool appSettingRefs})
        > {
  $UserProfileTableManager(_$AppDatabase db, UserProfile table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $UserProfileFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $UserProfileOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $UserProfileAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<int> singletonSlot = const Value.absent(),
                Value<String> accountEpoch = const Value.absent(),
                Value<String> usernameNormalized = const Value.absent(),
                Value<String> usernameDisplay = const Value.absent(),
                Value<String> passwordKdf = const Value.absent(),
                Value<Uint8List> passwordSalt = const Value.absent(),
                Value<Uint8List> passwordHash = const Value.absent(),
                Value<String> passwordParamsJson = const Value.absent(),
                Value<Uint8List?> activeSessionNonceHash = const Value.absent(),
                Value<String> locale = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserProfileCompanion(
                userId: userId,
                singletonSlot: singletonSlot,
                accountEpoch: accountEpoch,
                usernameNormalized: usernameNormalized,
                usernameDisplay: usernameDisplay,
                passwordKdf: passwordKdf,
                passwordSalt: passwordSalt,
                passwordHash: passwordHash,
                passwordParamsJson: passwordParamsJson,
                activeSessionNonceHash: activeSessionNonceHash,
                locale: locale,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                Value<int> singletonSlot = const Value.absent(),
                required String accountEpoch,
                required String usernameNormalized,
                required String usernameDisplay,
                required String passwordKdf,
                required Uint8List passwordSalt,
                required Uint8List passwordHash,
                required String passwordParamsJson,
                Value<Uint8List?> activeSessionNonceHash = const Value.absent(),
                Value<String> locale = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => UserProfileCompanion.insert(
                userId: userId,
                singletonSlot: singletonSlot,
                accountEpoch: accountEpoch,
                usernameNormalized: usernameNormalized,
                usernameDisplay: usernameDisplay,
                passwordKdf: passwordKdf,
                passwordSalt: passwordSalt,
                passwordHash: passwordHash,
                passwordParamsJson: passwordParamsJson,
                activeSessionNonceHash: activeSessionNonceHash,
                locale: locale,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $UserProfileReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({conversationRefs = false, appSettingRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (conversationRefs) db.conversation,
                    if (appSettingRefs) db.appSetting,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (conversationRefs)
                        await $_getPrefetchedData<
                          UserProfileData,
                          UserProfile,
                          ConversationData
                        >(
                          currentTable: table,
                          referencedTable: $UserProfileReferences
                              ._conversationRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $UserProfileReferences(
                                db,
                                table,
                                p0,
                              ).conversationRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.userId == item.userId,
                              ),
                          typedResults: items,
                        ),
                      if (appSettingRefs)
                        await $_getPrefetchedData<
                          UserProfileData,
                          UserProfile,
                          AppSettingData
                        >(
                          currentTable: table,
                          referencedTable: $UserProfileReferences
                              ._appSettingRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $UserProfileReferences(
                                db,
                                table,
                                p0,
                              ).appSettingRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.userId == item.userId,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $UserProfileProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      UserProfile,
      UserProfileData,
      $UserProfileFilterComposer,
      $UserProfileOrderingComposer,
      $UserProfileAnnotationComposer,
      $UserProfileCreateCompanionBuilder,
      $UserProfileUpdateCompanionBuilder,
      (UserProfileData, $UserProfileReferences),
      UserProfileData,
      PrefetchHooks Function({bool conversationRefs, bool appSettingRefs})
    >;
typedef $ConversationCreateCompanionBuilder =
    ConversationCompanion Function({
      required String conversationId,
      required String userId,
      Value<String?> activeScopeJson,
      required String createdAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $ConversationUpdateCompanionBuilder =
    ConversationCompanion Function({
      Value<String> conversationId,
      Value<String> userId,
      Value<String?> activeScopeJson,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

final class $ConversationReferences
    extends BaseReferences<_$AppDatabase, Conversation, ConversationData> {
  $ConversationReferences(super.$_db, super.$_table, super.$_typedResult);

  static UserProfile _userIdTable(_$AppDatabase db) =>
      db.userProfile.createAlias(
        $_aliasNameGenerator(db.conversation.userId, db.userProfile.userId),
      );

  $UserProfileProcessedTableManager get userId {
    final $_column = $_itemColumn<String>('user_id')!;

    final manager = $UserProfileTableManager(
      $_db,
      $_db.userProfile,
    ).filter((f) => f.userId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<Message, List<MessageData>> _messageRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.message,
    aliasName: $_aliasNameGenerator(
      db.conversation.conversationId,
      db.message.conversationId,
    ),
  );

  $MessageProcessedTableManager get messageRefs {
    final manager = $MessageTableManager($_db, $_db.message).filter(
      (f) => f.conversationId.conversationId.sqlEquals(
        $_itemColumn<String>('conversation_id')!,
      ),
    );

    final cache = $_typedResult.readTableOrNull(_messageRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $ConversationFilterComposer
    extends Composer<_$AppDatabase, Conversation> {
  $ConversationFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activeScopeJson => $composableBuilder(
    column: $table.activeScopeJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $UserProfileFilterComposer get userId {
    final $UserProfileFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userProfile,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $UserProfileFilterComposer(
            $db: $db,
            $table: $db.userProfile,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> messageRefs(
    Expression<bool> Function($MessageFilterComposer f) f,
  ) {
    final $MessageFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.message,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MessageFilterComposer(
            $db: $db,
            $table: $db.message,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $ConversationOrderingComposer
    extends Composer<_$AppDatabase, Conversation> {
  $ConversationOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activeScopeJson => $composableBuilder(
    column: $table.activeScopeJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $UserProfileOrderingComposer get userId {
    final $UserProfileOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userProfile,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $UserProfileOrderingComposer(
            $db: $db,
            $table: $db.userProfile,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $ConversationAnnotationComposer
    extends Composer<_$AppDatabase, Conversation> {
  $ConversationAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get activeScopeJson => $composableBuilder(
    column: $table.activeScopeJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $UserProfileAnnotationComposer get userId {
    final $UserProfileAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userProfile,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $UserProfileAnnotationComposer(
            $db: $db,
            $table: $db.userProfile,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> messageRefs<T extends Object>(
    Expression<T> Function($MessageAnnotationComposer a) f,
  ) {
    final $MessageAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.message,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MessageAnnotationComposer(
            $db: $db,
            $table: $db.message,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $ConversationTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Conversation,
          ConversationData,
          $ConversationFilterComposer,
          $ConversationOrderingComposer,
          $ConversationAnnotationComposer,
          $ConversationCreateCompanionBuilder,
          $ConversationUpdateCompanionBuilder,
          (ConversationData, $ConversationReferences),
          ConversationData,
          PrefetchHooks Function({bool userId, bool messageRefs})
        > {
  $ConversationTableManager(_$AppDatabase db, Conversation table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $ConversationFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $ConversationOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $ConversationAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> conversationId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String?> activeScopeJson = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationCompanion(
                conversationId: conversationId,
                userId: userId,
                activeScopeJson: activeScopeJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String conversationId,
                required String userId,
                Value<String?> activeScopeJson = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ConversationCompanion.insert(
                conversationId: conversationId,
                userId: userId,
                activeScopeJson: activeScopeJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $ConversationReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({userId = false, messageRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (messageRefs) db.message],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (userId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.userId,
                                referencedTable: $ConversationReferences
                                    ._userIdTable(db),
                                referencedColumn: $ConversationReferences
                                    ._userIdTable(db)
                                    .userId,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (messageRefs)
                    await $_getPrefetchedData<
                      ConversationData,
                      Conversation,
                      MessageData
                    >(
                      currentTable: table,
                      referencedTable: $ConversationReferences
                          ._messageRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $ConversationReferences(db, table, p0).messageRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.conversationId == item.conversationId,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $ConversationProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Conversation,
      ConversationData,
      $ConversationFilterComposer,
      $ConversationOrderingComposer,
      $ConversationAnnotationComposer,
      $ConversationCreateCompanionBuilder,
      $ConversationUpdateCompanionBuilder,
      (ConversationData, $ConversationReferences),
      ConversationData,
      PrefetchHooks Function({bool userId, bool messageRefs})
    >;
typedef $MessageCreateCompanionBuilder =
    MessageCompanion Function({
      required String messageId,
      required String conversationId,
      required String role,
      required String content,
      Value<String> sourceRefsJson,
      required String createdAt,
      Value<int> rowid,
    });
typedef $MessageUpdateCompanionBuilder =
    MessageCompanion Function({
      Value<String> messageId,
      Value<String> conversationId,
      Value<String> role,
      Value<String> content,
      Value<String> sourceRefsJson,
      Value<String> createdAt,
      Value<int> rowid,
    });

final class $MessageReferences
    extends BaseReferences<_$AppDatabase, Message, MessageData> {
  $MessageReferences(super.$_db, super.$_table, super.$_typedResult);

  static Conversation _conversationIdTable(_$AppDatabase db) =>
      db.conversation.createAlias(
        $_aliasNameGenerator(
          db.message.conversationId,
          db.conversation.conversationId,
        ),
      );

  $ConversationProcessedTableManager get conversationId {
    final $_column = $_itemColumn<String>('conversation_id')!;

    final manager = $ConversationTableManager(
      $_db,
      $_db.conversation,
    ).filter((f) => f.conversationId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_conversationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $MessageFilterComposer extends Composer<_$AppDatabase, Message> {
  $MessageFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceRefsJson => $composableBuilder(
    column: $table.sourceRefsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $ConversationFilterComposer get conversationId {
    final $ConversationFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversation,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ConversationFilterComposer(
            $db: $db,
            $table: $db.conversation,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $MessageOrderingComposer extends Composer<_$AppDatabase, Message> {
  $MessageOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceRefsJson => $composableBuilder(
    column: $table.sourceRefsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $ConversationOrderingComposer get conversationId {
    final $ConversationOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversation,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ConversationOrderingComposer(
            $db: $db,
            $table: $db.conversation,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $MessageAnnotationComposer extends Composer<_$AppDatabase, Message> {
  $MessageAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get sourceRefsJson => $composableBuilder(
    column: $table.sourceRefsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $ConversationAnnotationComposer get conversationId {
    final $ConversationAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversation,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ConversationAnnotationComposer(
            $db: $db,
            $table: $db.conversation,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $MessageTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Message,
          MessageData,
          $MessageFilterComposer,
          $MessageOrderingComposer,
          $MessageAnnotationComposer,
          $MessageCreateCompanionBuilder,
          $MessageUpdateCompanionBuilder,
          (MessageData, $MessageReferences),
          MessageData,
          PrefetchHooks Function({bool conversationId})
        > {
  $MessageTableManager(_$AppDatabase db, Message table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $MessageFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $MessageOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $MessageAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> messageId = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> sourceRefsJson = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessageCompanion(
                messageId: messageId,
                conversationId: conversationId,
                role: role,
                content: content,
                sourceRefsJson: sourceRefsJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String messageId,
                required String conversationId,
                required String role,
                required String content,
                Value<String> sourceRefsJson = const Value.absent(),
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => MessageCompanion.insert(
                messageId: messageId,
                conversationId: conversationId,
                role: role,
                content: content,
                sourceRefsJson: sourceRefsJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (e.readTable(table), $MessageReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({conversationId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (conversationId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.conversationId,
                                referencedTable: $MessageReferences
                                    ._conversationIdTable(db),
                                referencedColumn: $MessageReferences
                                    ._conversationIdTable(db)
                                    .conversationId,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $MessageProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Message,
      MessageData,
      $MessageFilterComposer,
      $MessageOrderingComposer,
      $MessageAnnotationComposer,
      $MessageCreateCompanionBuilder,
      $MessageUpdateCompanionBuilder,
      (MessageData, $MessageReferences),
      MessageData,
      PrefetchHooks Function({bool conversationId})
    >;
typedef $AppSettingCreateCompanionBuilder =
    AppSettingCompanion Function({
      required String userId,
      required String settingKey,
      required String valueJson,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $AppSettingUpdateCompanionBuilder =
    AppSettingCompanion Function({
      Value<String> userId,
      Value<String> settingKey,
      Value<String> valueJson,
      Value<String> updatedAt,
      Value<int> rowid,
    });

final class $AppSettingReferences
    extends BaseReferences<_$AppDatabase, AppSetting, AppSettingData> {
  $AppSettingReferences(super.$_db, super.$_table, super.$_typedResult);

  static UserProfile _userIdTable(_$AppDatabase db) =>
      db.userProfile.createAlias(
        $_aliasNameGenerator(db.appSetting.userId, db.userProfile.userId),
      );

  $UserProfileProcessedTableManager get userId {
    final $_column = $_itemColumn<String>('user_id')!;

    final manager = $UserProfileTableManager(
      $_db,
      $_db.userProfile,
    ).filter((f) => f.userId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $AppSettingFilterComposer extends Composer<_$AppDatabase, AppSetting> {
  $AppSettingFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get settingKey => $composableBuilder(
    column: $table.settingKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $UserProfileFilterComposer get userId {
    final $UserProfileFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userProfile,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $UserProfileFilterComposer(
            $db: $db,
            $table: $db.userProfile,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $AppSettingOrderingComposer extends Composer<_$AppDatabase, AppSetting> {
  $AppSettingOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get settingKey => $composableBuilder(
    column: $table.settingKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $UserProfileOrderingComposer get userId {
    final $UserProfileOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userProfile,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $UserProfileOrderingComposer(
            $db: $db,
            $table: $db.userProfile,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $AppSettingAnnotationComposer
    extends Composer<_$AppDatabase, AppSetting> {
  $AppSettingAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get settingKey => $composableBuilder(
    column: $table.settingKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get valueJson =>
      $composableBuilder(column: $table.valueJson, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $UserProfileAnnotationComposer get userId {
    final $UserProfileAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userProfile,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $UserProfileAnnotationComposer(
            $db: $db,
            $table: $db.userProfile,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $AppSettingTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          AppSetting,
          AppSettingData,
          $AppSettingFilterComposer,
          $AppSettingOrderingComposer,
          $AppSettingAnnotationComposer,
          $AppSettingCreateCompanionBuilder,
          $AppSettingUpdateCompanionBuilder,
          (AppSettingData, $AppSettingReferences),
          AppSettingData,
          PrefetchHooks Function({bool userId})
        > {
  $AppSettingTableManager(_$AppDatabase db, AppSetting table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $AppSettingFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $AppSettingOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $AppSettingAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> settingKey = const Value.absent(),
                Value<String> valueJson = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingCompanion(
                userId: userId,
                settingKey: settingKey,
                valueJson: valueJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String settingKey,
                required String valueJson,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingCompanion.insert(
                userId: userId,
                settingKey: settingKey,
                valueJson: valueJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $AppSettingReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({userId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (userId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.userId,
                                referencedTable: $AppSettingReferences
                                    ._userIdTable(db),
                                referencedColumn: $AppSettingReferences
                                    ._userIdTable(db)
                                    .userId,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $AppSettingProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      AppSetting,
      AppSettingData,
      $AppSettingFilterComposer,
      $AppSettingOrderingComposer,
      $AppSettingAnnotationComposer,
      $AppSettingCreateCompanionBuilder,
      $AppSettingUpdateCompanionBuilder,
      (AppSettingData, $AppSettingReferences),
      AppSettingData,
      PrefetchHooks Function({bool userId})
    >;
typedef $InstalledResourceCreateCompanionBuilder =
    InstalledResourceCompanion Function({
      required String resourceId,
      required String kind,
      Value<String?> revision,
      required String state,
      Value<String?> localPath,
      Value<String?> manifestJson,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $InstalledResourceUpdateCompanionBuilder =
    InstalledResourceCompanion Function({
      Value<String> resourceId,
      Value<String> kind,
      Value<String?> revision,
      Value<String> state,
      Value<String?> localPath,
      Value<String?> manifestJson,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $InstalledResourceFilterComposer
    extends Composer<_$AppDatabase, InstalledResource> {
  $InstalledResourceFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manifestJson => $composableBuilder(
    column: $table.manifestJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $InstalledResourceOrderingComposer
    extends Composer<_$AppDatabase, InstalledResource> {
  $InstalledResourceOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manifestJson => $composableBuilder(
    column: $table.manifestJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $InstalledResourceAnnotationComposer
    extends Composer<_$AppDatabase, InstalledResource> {
  $InstalledResourceAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get manifestJson => $composableBuilder(
    column: $table.manifestJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $InstalledResourceTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          InstalledResource,
          InstalledResourceData,
          $InstalledResourceFilterComposer,
          $InstalledResourceOrderingComposer,
          $InstalledResourceAnnotationComposer,
          $InstalledResourceCreateCompanionBuilder,
          $InstalledResourceUpdateCompanionBuilder,
          (
            InstalledResourceData,
            BaseReferences<
              _$AppDatabase,
              InstalledResource,
              InstalledResourceData
            >,
          ),
          InstalledResourceData,
          PrefetchHooks Function()
        > {
  $InstalledResourceTableManager(_$AppDatabase db, InstalledResource table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $InstalledResourceFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $InstalledResourceOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $InstalledResourceAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> resourceId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> revision = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<String?> manifestJson = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InstalledResourceCompanion(
                resourceId: resourceId,
                kind: kind,
                revision: revision,
                state: state,
                localPath: localPath,
                manifestJson: manifestJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String resourceId,
                required String kind,
                Value<String?> revision = const Value.absent(),
                required String state,
                Value<String?> localPath = const Value.absent(),
                Value<String?> manifestJson = const Value.absent(),
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => InstalledResourceCompanion.insert(
                resourceId: resourceId,
                kind: kind,
                revision: revision,
                state: state,
                localPath: localPath,
                manifestJson: manifestJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $InstalledResourceProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      InstalledResource,
      InstalledResourceData,
      $InstalledResourceFilterComposer,
      $InstalledResourceOrderingComposer,
      $InstalledResourceAnnotationComposer,
      $InstalledResourceCreateCompanionBuilder,
      $InstalledResourceUpdateCompanionBuilder,
      (
        InstalledResourceData,
        BaseReferences<_$AppDatabase, InstalledResource, InstalledResourceData>,
      ),
      InstalledResourceData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $UserProfileTableManager get userProfile =>
      $UserProfileTableManager(_db, _db.userProfile);
  $ConversationTableManager get conversation =>
      $ConversationTableManager(_db, _db.conversation);
  $MessageTableManager get message => $MessageTableManager(_db, _db.message);
  $AppSettingTableManager get appSetting =>
      $AppSettingTableManager(_db, _db.appSetting);
  $InstalledResourceTableManager get installedResource =>
      $InstalledResourceTableManager(_db, _db.installedResource);
}
