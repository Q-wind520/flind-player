// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TracksTable extends Tracks with TableInfo<$TracksTable, TrackRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceTrackIdMeta = const VerificationMeta(
    'sourceTrackId',
  );
  @override
  late final GeneratedColumn<String> sourceTrackId = GeneratedColumn<String>(
    'source_track_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uriMeta = const VerificationMeta('uri');
  @override
  late final GeneratedColumn<String> uri = GeneratedColumn<String>(
    'uri',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
    'album',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumArtistMeta = const VerificationMeta(
    'albumArtist',
  );
  @override
  late final GeneratedColumn<String> albumArtist = GeneratedColumn<String>(
    'album_artist',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trackNoMeta = const VerificationMeta(
    'trackNo',
  );
  @override
  late final GeneratedColumn<int> trackNo = GeneratedColumn<int>(
    'track_no',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _discNoMeta = const VerificationMeta('discNo');
  @override
  late final GeneratedColumn<int> discNo = GeneratedColumn<int>(
    'disc_no',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bitrateMeta = const VerificationMeta(
    'bitrate',
  );
  @override
  late final GeneratedColumn<int> bitrate = GeneratedColumn<int>(
    'bitrate',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sampleRateMeta = const VerificationMeta(
    'sampleRate',
  );
  @override
  late final GeneratedColumn<int> sampleRate = GeneratedColumn<int>(
    'sample_rate',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverPathMeta = const VerificationMeta(
    'coverPath',
  );
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
    'cover_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<int> lastSeenAt = GeneratedColumn<int>(
    'last_seen_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mtimeMsMeta = const VerificationMeta(
    'mtimeMs',
  );
  @override
  late final GeneratedColumn<int> mtimeMs = GeneratedColumn<int>(
    'mtime_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scanRootMeta = const VerificationMeta(
    'scanRoot',
  );
  @override
  late final GeneratedColumn<String> scanRoot = GeneratedColumn<String>(
    'scan_root',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _missingAtMeta = const VerificationMeta(
    'missingAt',
  );
  @override
  late final GeneratedColumn<int> missingAt = GeneratedColumn<int>(
    'missing_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    source,
    sourceTrackId,
    uri,
    title,
    artist,
    album,
    albumArtist,
    trackNo,
    discNo,
    year,
    durationMs,
    bitrate,
    sampleRate,
    genre,
    coverPath,
    coverUrl,
    lastSeenAt,
    sizeBytes,
    mtimeMs,
    scanRoot,
    missingAt,
    deletedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrackRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('source_track_id')) {
      context.handle(
        _sourceTrackIdMeta,
        sourceTrackId.isAcceptableOrUnknown(
          data['source_track_id']!,
          _sourceTrackIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceTrackIdMeta);
    }
    if (data.containsKey('uri')) {
      context.handle(
        _uriMeta,
        uri.isAcceptableOrUnknown(data['uri']!, _uriMeta),
      );
    } else if (isInserting) {
      context.missing(_uriMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    }
    if (data.containsKey('album')) {
      context.handle(
        _albumMeta,
        album.isAcceptableOrUnknown(data['album']!, _albumMeta),
      );
    }
    if (data.containsKey('album_artist')) {
      context.handle(
        _albumArtistMeta,
        albumArtist.isAcceptableOrUnknown(
          data['album_artist']!,
          _albumArtistMeta,
        ),
      );
    }
    if (data.containsKey('track_no')) {
      context.handle(
        _trackNoMeta,
        trackNo.isAcceptableOrUnknown(data['track_no']!, _trackNoMeta),
      );
    }
    if (data.containsKey('disc_no')) {
      context.handle(
        _discNoMeta,
        discNo.isAcceptableOrUnknown(data['disc_no']!, _discNoMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('bitrate')) {
      context.handle(
        _bitrateMeta,
        bitrate.isAcceptableOrUnknown(data['bitrate']!, _bitrateMeta),
      );
    }
    if (data.containsKey('sample_rate')) {
      context.handle(
        _sampleRateMeta,
        sampleRate.isAcceptableOrUnknown(data['sample_rate']!, _sampleRateMeta),
      );
    }
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('mtime_ms')) {
      context.handle(
        _mtimeMsMeta,
        mtimeMs.isAcceptableOrUnknown(data['mtime_ms']!, _mtimeMsMeta),
      );
    }
    if (data.containsKey('scan_root')) {
      context.handle(
        _scanRootMeta,
        scanRoot.isAcceptableOrUnknown(data['scan_root']!, _scanRootMeta),
      );
    }
    if (data.containsKey('missing_at')) {
      context.handle(
        _missingAtMeta,
        missingAt.isAcceptableOrUnknown(data['missing_at']!, _missingAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TrackRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      sourceTrackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_track_id'],
      )!,
      uri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uri'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      ),
      album: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album'],
      ),
      albumArtist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_artist'],
      ),
      trackNo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_no'],
      ),
      discNo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}disc_no'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      bitrate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bitrate'],
      ),
      sampleRate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sample_rate'],
      ),
      genre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre'],
      ),
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      ),
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seen_at'],
      ),
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      ),
      mtimeMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mtime_ms'],
      ),
      scanRoot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scan_root'],
      ),
      missingAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}missing_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TracksTable createAlias(String alias) {
    return $TracksTable(attachedDatabase, alias);
  }
}

class TrackRow extends DataClass implements Insertable<TrackRow> {
  final int id;

  /// Source identifier, e.g. `local` or `bilibili`.
  final String source;

  /// Source-specific identity (absolute path, or `bvid:cid`).
  final String sourceTrackId;

  /// Canonical source-namespaced key; the upsert conflict target.
  final String uri;
  final String title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final int? trackNo;
  final int? discNo;
  final int? year;
  final int? durationMs;
  final int? bitrate;
  final int? sampleRate;
  final String? genre;
  final String? coverPath;

  /// Remote cover URL (e.g. a Bilibili `pic` link), or `null` (schema v7).
  ///
  /// Persisted so a cover can be re-resolved from the cache index — or fetched
  /// again after LRU eviction — without another `view` API round-trip.
  final String? coverUrl;
  final int? lastSeenAt;

  /// Size of the source file in bytes at the last scan (schema v5).
  ///
  /// Together with [mtimeMs] this is the `(mtime, size)` freshness key that
  /// lets a rescan skip files whose content has not changed
  /// (docs/local-library.md §2.4, §6). `null` for online tracks and for rows
  /// written before the fingerprint columns existed.
  final int? sizeBytes;

  /// Last-modified time of the source file, in milliseconds since epoch
  /// (schema v5). See [sizeBytes].
  final int? mtimeMs;

  /// Scan root this track was discovered under, or `null` for individually
  /// imported files and pre-v5 rows (schema v5).
  ///
  /// Scopes soft-deletes: a root that is temporarily offline (e.g. an
  /// unplugged drive) must not lose its tracks
  /// (docs/local-library.md §2.4 rule 3).
  final String? scanRoot;

  /// Unix timestamp when the track disappeared from its source, or `null`
  /// while it is present.
  ///
  /// Soft delete: a transiently unplugged drive or a failed scan must not
  /// destroy rows that future playlists/stats still reference.
  final int? missingAt;

  /// Unix timestamp when the user removed this track, or `null` while live
  /// (schema v11).
  ///
  /// Distinct from [missingAt]: a removed track is intentionally gone, while a
  /// missing track may return when its source comes back. Rows referenced by
  /// playlists/downloads/stats are kept as tombstones instead of hard-deleted.
  final int? deletedAt;
  final int createdAt;
  final int updatedAt;
  const TrackRow({
    required this.id,
    required this.source,
    required this.sourceTrackId,
    required this.uri,
    required this.title,
    this.artist,
    this.album,
    this.albumArtist,
    this.trackNo,
    this.discNo,
    this.year,
    this.durationMs,
    this.bitrate,
    this.sampleRate,
    this.genre,
    this.coverPath,
    this.coverUrl,
    this.lastSeenAt,
    this.sizeBytes,
    this.mtimeMs,
    this.scanRoot,
    this.missingAt,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source'] = Variable<String>(source);
    map['source_track_id'] = Variable<String>(sourceTrackId);
    map['uri'] = Variable<String>(uri);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || artist != null) {
      map['artist'] = Variable<String>(artist);
    }
    if (!nullToAbsent || album != null) {
      map['album'] = Variable<String>(album);
    }
    if (!nullToAbsent || albumArtist != null) {
      map['album_artist'] = Variable<String>(albumArtist);
    }
    if (!nullToAbsent || trackNo != null) {
      map['track_no'] = Variable<int>(trackNo);
    }
    if (!nullToAbsent || discNo != null) {
      map['disc_no'] = Variable<int>(discNo);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    if (!nullToAbsent || bitrate != null) {
      map['bitrate'] = Variable<int>(bitrate);
    }
    if (!nullToAbsent || sampleRate != null) {
      map['sample_rate'] = Variable<int>(sampleRate);
    }
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    if (!nullToAbsent || lastSeenAt != null) {
      map['last_seen_at'] = Variable<int>(lastSeenAt);
    }
    if (!nullToAbsent || sizeBytes != null) {
      map['size_bytes'] = Variable<int>(sizeBytes);
    }
    if (!nullToAbsent || mtimeMs != null) {
      map['mtime_ms'] = Variable<int>(mtimeMs);
    }
    if (!nullToAbsent || scanRoot != null) {
      map['scan_root'] = Variable<String>(scanRoot);
    }
    if (!nullToAbsent || missingAt != null) {
      map['missing_at'] = Variable<int>(missingAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  TracksCompanion toCompanion(bool nullToAbsent) {
    return TracksCompanion(
      id: Value(id),
      source: Value(source),
      sourceTrackId: Value(sourceTrackId),
      uri: Value(uri),
      title: Value(title),
      artist: artist == null && nullToAbsent
          ? const Value.absent()
          : Value(artist),
      album: album == null && nullToAbsent
          ? const Value.absent()
          : Value(album),
      albumArtist: albumArtist == null && nullToAbsent
          ? const Value.absent()
          : Value(albumArtist),
      trackNo: trackNo == null && nullToAbsent
          ? const Value.absent()
          : Value(trackNo),
      discNo: discNo == null && nullToAbsent
          ? const Value.absent()
          : Value(discNo),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      bitrate: bitrate == null && nullToAbsent
          ? const Value.absent()
          : Value(bitrate),
      sampleRate: sampleRate == null && nullToAbsent
          ? const Value.absent()
          : Value(sampleRate),
      genre: genre == null && nullToAbsent
          ? const Value.absent()
          : Value(genre),
      coverPath: coverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverPath),
      coverUrl: coverUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverUrl),
      lastSeenAt: lastSeenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeenAt),
      sizeBytes: sizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeBytes),
      mtimeMs: mtimeMs == null && nullToAbsent
          ? const Value.absent()
          : Value(mtimeMs),
      scanRoot: scanRoot == null && nullToAbsent
          ? const Value.absent()
          : Value(scanRoot),
      missingAt: missingAt == null && nullToAbsent
          ? const Value.absent()
          : Value(missingAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TrackRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackRow(
      id: serializer.fromJson<int>(json['id']),
      source: serializer.fromJson<String>(json['source']),
      sourceTrackId: serializer.fromJson<String>(json['sourceTrackId']),
      uri: serializer.fromJson<String>(json['uri']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String?>(json['artist']),
      album: serializer.fromJson<String?>(json['album']),
      albumArtist: serializer.fromJson<String?>(json['albumArtist']),
      trackNo: serializer.fromJson<int?>(json['trackNo']),
      discNo: serializer.fromJson<int?>(json['discNo']),
      year: serializer.fromJson<int?>(json['year']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      bitrate: serializer.fromJson<int?>(json['bitrate']),
      sampleRate: serializer.fromJson<int?>(json['sampleRate']),
      genre: serializer.fromJson<String?>(json['genre']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      lastSeenAt: serializer.fromJson<int?>(json['lastSeenAt']),
      sizeBytes: serializer.fromJson<int?>(json['sizeBytes']),
      mtimeMs: serializer.fromJson<int?>(json['mtimeMs']),
      scanRoot: serializer.fromJson<String?>(json['scanRoot']),
      missingAt: serializer.fromJson<int?>(json['missingAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'source': serializer.toJson<String>(source),
      'sourceTrackId': serializer.toJson<String>(sourceTrackId),
      'uri': serializer.toJson<String>(uri),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String?>(artist),
      'album': serializer.toJson<String?>(album),
      'albumArtist': serializer.toJson<String?>(albumArtist),
      'trackNo': serializer.toJson<int?>(trackNo),
      'discNo': serializer.toJson<int?>(discNo),
      'year': serializer.toJson<int?>(year),
      'durationMs': serializer.toJson<int?>(durationMs),
      'bitrate': serializer.toJson<int?>(bitrate),
      'sampleRate': serializer.toJson<int?>(sampleRate),
      'genre': serializer.toJson<String?>(genre),
      'coverPath': serializer.toJson<String?>(coverPath),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'lastSeenAt': serializer.toJson<int?>(lastSeenAt),
      'sizeBytes': serializer.toJson<int?>(sizeBytes),
      'mtimeMs': serializer.toJson<int?>(mtimeMs),
      'scanRoot': serializer.toJson<String?>(scanRoot),
      'missingAt': serializer.toJson<int?>(missingAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  TrackRow copyWith({
    int? id,
    String? source,
    String? sourceTrackId,
    String? uri,
    String? title,
    Value<String?> artist = const Value.absent(),
    Value<String?> album = const Value.absent(),
    Value<String?> albumArtist = const Value.absent(),
    Value<int?> trackNo = const Value.absent(),
    Value<int?> discNo = const Value.absent(),
    Value<int?> year = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    Value<int?> bitrate = const Value.absent(),
    Value<int?> sampleRate = const Value.absent(),
    Value<String?> genre = const Value.absent(),
    Value<String?> coverPath = const Value.absent(),
    Value<String?> coverUrl = const Value.absent(),
    Value<int?> lastSeenAt = const Value.absent(),
    Value<int?> sizeBytes = const Value.absent(),
    Value<int?> mtimeMs = const Value.absent(),
    Value<String?> scanRoot = const Value.absent(),
    Value<int?> missingAt = const Value.absent(),
    Value<int?> deletedAt = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => TrackRow(
    id: id ?? this.id,
    source: source ?? this.source,
    sourceTrackId: sourceTrackId ?? this.sourceTrackId,
    uri: uri ?? this.uri,
    title: title ?? this.title,
    artist: artist.present ? artist.value : this.artist,
    album: album.present ? album.value : this.album,
    albumArtist: albumArtist.present ? albumArtist.value : this.albumArtist,
    trackNo: trackNo.present ? trackNo.value : this.trackNo,
    discNo: discNo.present ? discNo.value : this.discNo,
    year: year.present ? year.value : this.year,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    bitrate: bitrate.present ? bitrate.value : this.bitrate,
    sampleRate: sampleRate.present ? sampleRate.value : this.sampleRate,
    genre: genre.present ? genre.value : this.genre,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
    lastSeenAt: lastSeenAt.present ? lastSeenAt.value : this.lastSeenAt,
    sizeBytes: sizeBytes.present ? sizeBytes.value : this.sizeBytes,
    mtimeMs: mtimeMs.present ? mtimeMs.value : this.mtimeMs,
    scanRoot: scanRoot.present ? scanRoot.value : this.scanRoot,
    missingAt: missingAt.present ? missingAt.value : this.missingAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TrackRow copyWithCompanion(TracksCompanion data) {
    return TrackRow(
      id: data.id.present ? data.id.value : this.id,
      source: data.source.present ? data.source.value : this.source,
      sourceTrackId: data.sourceTrackId.present
          ? data.sourceTrackId.value
          : this.sourceTrackId,
      uri: data.uri.present ? data.uri.value : this.uri,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      album: data.album.present ? data.album.value : this.album,
      albumArtist: data.albumArtist.present
          ? data.albumArtist.value
          : this.albumArtist,
      trackNo: data.trackNo.present ? data.trackNo.value : this.trackNo,
      discNo: data.discNo.present ? data.discNo.value : this.discNo,
      year: data.year.present ? data.year.value : this.year,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      bitrate: data.bitrate.present ? data.bitrate.value : this.bitrate,
      sampleRate: data.sampleRate.present
          ? data.sampleRate.value
          : this.sampleRate,
      genre: data.genre.present ? data.genre.value : this.genre,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      mtimeMs: data.mtimeMs.present ? data.mtimeMs.value : this.mtimeMs,
      scanRoot: data.scanRoot.present ? data.scanRoot.value : this.scanRoot,
      missingAt: data.missingAt.present ? data.missingAt.value : this.missingAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackRow(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('sourceTrackId: $sourceTrackId, ')
          ..write('uri: $uri, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('albumArtist: $albumArtist, ')
          ..write('trackNo: $trackNo, ')
          ..write('discNo: $discNo, ')
          ..write('year: $year, ')
          ..write('durationMs: $durationMs, ')
          ..write('bitrate: $bitrate, ')
          ..write('sampleRate: $sampleRate, ')
          ..write('genre: $genre, ')
          ..write('coverPath: $coverPath, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('mtimeMs: $mtimeMs, ')
          ..write('scanRoot: $scanRoot, ')
          ..write('missingAt: $missingAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    source,
    sourceTrackId,
    uri,
    title,
    artist,
    album,
    albumArtist,
    trackNo,
    discNo,
    year,
    durationMs,
    bitrate,
    sampleRate,
    genre,
    coverPath,
    coverUrl,
    lastSeenAt,
    sizeBytes,
    mtimeMs,
    scanRoot,
    missingAt,
    deletedAt,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackRow &&
          other.id == this.id &&
          other.source == this.source &&
          other.sourceTrackId == this.sourceTrackId &&
          other.uri == this.uri &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.album == this.album &&
          other.albumArtist == this.albumArtist &&
          other.trackNo == this.trackNo &&
          other.discNo == this.discNo &&
          other.year == this.year &&
          other.durationMs == this.durationMs &&
          other.bitrate == this.bitrate &&
          other.sampleRate == this.sampleRate &&
          other.genre == this.genre &&
          other.coverPath == this.coverPath &&
          other.coverUrl == this.coverUrl &&
          other.lastSeenAt == this.lastSeenAt &&
          other.sizeBytes == this.sizeBytes &&
          other.mtimeMs == this.mtimeMs &&
          other.scanRoot == this.scanRoot &&
          other.missingAt == this.missingAt &&
          other.deletedAt == this.deletedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TracksCompanion extends UpdateCompanion<TrackRow> {
  final Value<int> id;
  final Value<String> source;
  final Value<String> sourceTrackId;
  final Value<String> uri;
  final Value<String> title;
  final Value<String?> artist;
  final Value<String?> album;
  final Value<String?> albumArtist;
  final Value<int?> trackNo;
  final Value<int?> discNo;
  final Value<int?> year;
  final Value<int?> durationMs;
  final Value<int?> bitrate;
  final Value<int?> sampleRate;
  final Value<String?> genre;
  final Value<String?> coverPath;
  final Value<String?> coverUrl;
  final Value<int?> lastSeenAt;
  final Value<int?> sizeBytes;
  final Value<int?> mtimeMs;
  final Value<String?> scanRoot;
  final Value<int?> missingAt;
  final Value<int?> deletedAt;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  const TracksCompanion({
    this.id = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceTrackId = const Value.absent(),
    this.uri = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.albumArtist = const Value.absent(),
    this.trackNo = const Value.absent(),
    this.discNo = const Value.absent(),
    this.year = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.bitrate = const Value.absent(),
    this.sampleRate = const Value.absent(),
    this.genre = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.mtimeMs = const Value.absent(),
    this.scanRoot = const Value.absent(),
    this.missingAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  TracksCompanion.insert({
    this.id = const Value.absent(),
    required String source,
    required String sourceTrackId,
    required String uri,
    required String title,
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.albumArtist = const Value.absent(),
    this.trackNo = const Value.absent(),
    this.discNo = const Value.absent(),
    this.year = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.bitrate = const Value.absent(),
    this.sampleRate = const Value.absent(),
    this.genre = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.mtimeMs = const Value.absent(),
    this.scanRoot = const Value.absent(),
    this.missingAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required int createdAt,
    required int updatedAt,
  }) : source = Value(source),
       sourceTrackId = Value(sourceTrackId),
       uri = Value(uri),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TrackRow> custom({
    Expression<int>? id,
    Expression<String>? source,
    Expression<String>? sourceTrackId,
    Expression<String>? uri,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? album,
    Expression<String>? albumArtist,
    Expression<int>? trackNo,
    Expression<int>? discNo,
    Expression<int>? year,
    Expression<int>? durationMs,
    Expression<int>? bitrate,
    Expression<int>? sampleRate,
    Expression<String>? genre,
    Expression<String>? coverPath,
    Expression<String>? coverUrl,
    Expression<int>? lastSeenAt,
    Expression<int>? sizeBytes,
    Expression<int>? mtimeMs,
    Expression<String>? scanRoot,
    Expression<int>? missingAt,
    Expression<int>? deletedAt,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (source != null) 'source': source,
      if (sourceTrackId != null) 'source_track_id': sourceTrackId,
      if (uri != null) 'uri': uri,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (albumArtist != null) 'album_artist': albumArtist,
      if (trackNo != null) 'track_no': trackNo,
      if (discNo != null) 'disc_no': discNo,
      if (year != null) 'year': year,
      if (durationMs != null) 'duration_ms': durationMs,
      if (bitrate != null) 'bitrate': bitrate,
      if (sampleRate != null) 'sample_rate': sampleRate,
      if (genre != null) 'genre': genre,
      if (coverPath != null) 'cover_path': coverPath,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (mtimeMs != null) 'mtime_ms': mtimeMs,
      if (scanRoot != null) 'scan_root': scanRoot,
      if (missingAt != null) 'missing_at': missingAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  TracksCompanion copyWith({
    Value<int>? id,
    Value<String>? source,
    Value<String>? sourceTrackId,
    Value<String>? uri,
    Value<String>? title,
    Value<String?>? artist,
    Value<String?>? album,
    Value<String?>? albumArtist,
    Value<int?>? trackNo,
    Value<int?>? discNo,
    Value<int?>? year,
    Value<int?>? durationMs,
    Value<int?>? bitrate,
    Value<int?>? sampleRate,
    Value<String?>? genre,
    Value<String?>? coverPath,
    Value<String?>? coverUrl,
    Value<int?>? lastSeenAt,
    Value<int?>? sizeBytes,
    Value<int?>? mtimeMs,
    Value<String?>? scanRoot,
    Value<int?>? missingAt,
    Value<int?>? deletedAt,
    Value<int>? createdAt,
    Value<int>? updatedAt,
  }) {
    return TracksCompanion(
      id: id ?? this.id,
      source: source ?? this.source,
      sourceTrackId: sourceTrackId ?? this.sourceTrackId,
      uri: uri ?? this.uri,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtist: albumArtist ?? this.albumArtist,
      trackNo: trackNo ?? this.trackNo,
      discNo: discNo ?? this.discNo,
      year: year ?? this.year,
      durationMs: durationMs ?? this.durationMs,
      bitrate: bitrate ?? this.bitrate,
      sampleRate: sampleRate ?? this.sampleRate,
      genre: genre ?? this.genre,
      coverPath: coverPath ?? this.coverPath,
      coverUrl: coverUrl ?? this.coverUrl,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      mtimeMs: mtimeMs ?? this.mtimeMs,
      scanRoot: scanRoot ?? this.scanRoot,
      missingAt: missingAt ?? this.missingAt,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (sourceTrackId.present) {
      map['source_track_id'] = Variable<String>(sourceTrackId.value);
    }
    if (uri.present) {
      map['uri'] = Variable<String>(uri.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (albumArtist.present) {
      map['album_artist'] = Variable<String>(albumArtist.value);
    }
    if (trackNo.present) {
      map['track_no'] = Variable<int>(trackNo.value);
    }
    if (discNo.present) {
      map['disc_no'] = Variable<int>(discNo.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (bitrate.present) {
      map['bitrate'] = Variable<int>(bitrate.value);
    }
    if (sampleRate.present) {
      map['sample_rate'] = Variable<int>(sampleRate.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<int>(lastSeenAt.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (mtimeMs.present) {
      map['mtime_ms'] = Variable<int>(mtimeMs.value);
    }
    if (scanRoot.present) {
      map['scan_root'] = Variable<String>(scanRoot.value);
    }
    if (missingAt.present) {
      map['missing_at'] = Variable<int>(missingAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TracksCompanion(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('sourceTrackId: $sourceTrackId, ')
          ..write('uri: $uri, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('albumArtist: $albumArtist, ')
          ..write('trackNo: $trackNo, ')
          ..write('discNo: $discNo, ')
          ..write('year: $year, ')
          ..write('durationMs: $durationMs, ')
          ..write('bitrate: $bitrate, ')
          ..write('sampleRate: $sampleRate, ')
          ..write('genre: $genre, ')
          ..write('coverPath: $coverPath, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('mtimeMs: $mtimeMs, ')
          ..write('scanRoot: $scanRoot, ')
          ..write('missingAt: $missingAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ScanRootsTable extends ScanRoots
    with TableInfo<$ScanRootsTable, ScanRootRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScanRootsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, path, kind, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scan_roots';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScanRootRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScanRootRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScanRootRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $ScanRootsTable createAlias(String alias) {
    return $ScanRootsTable(attachedDatabase, alias);
  }
}

class ScanRootRow extends DataClass implements Insertable<ScanRootRow> {
  final int id;
  final String path;

  /// Root kind, currently only `local`.
  final String kind;
  final int addedAt;
  const ScanRootRow({
    required this.id,
    required this.path,
    required this.kind,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['path'] = Variable<String>(path);
    map['kind'] = Variable<String>(kind);
    map['added_at'] = Variable<int>(addedAt);
    return map;
  }

  ScanRootsCompanion toCompanion(bool nullToAbsent) {
    return ScanRootsCompanion(
      id: Value(id),
      path: Value(path),
      kind: Value(kind),
      addedAt: Value(addedAt),
    );
  }

  factory ScanRootRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScanRootRow(
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String>(json['path']),
      kind: serializer.fromJson<String>(json['kind']),
      addedAt: serializer.fromJson<int>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String>(path),
      'kind': serializer.toJson<String>(kind),
      'addedAt': serializer.toJson<int>(addedAt),
    };
  }

  ScanRootRow copyWith({int? id, String? path, String? kind, int? addedAt}) =>
      ScanRootRow(
        id: id ?? this.id,
        path: path ?? this.path,
        kind: kind ?? this.kind,
        addedAt: addedAt ?? this.addedAt,
      );
  ScanRootRow copyWithCompanion(ScanRootsCompanion data) {
    return ScanRootRow(
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
      kind: data.kind.present ? data.kind.value : this.kind,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScanRootRow(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('kind: $kind, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, path, kind, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScanRootRow &&
          other.id == this.id &&
          other.path == this.path &&
          other.kind == this.kind &&
          other.addedAt == this.addedAt);
}

class ScanRootsCompanion extends UpdateCompanion<ScanRootRow> {
  final Value<int> id;
  final Value<String> path;
  final Value<String> kind;
  final Value<int> addedAt;
  const ScanRootsCompanion({
    this.id = const Value.absent(),
    this.path = const Value.absent(),
    this.kind = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  ScanRootsCompanion.insert({
    this.id = const Value.absent(),
    required String path,
    required String kind,
    required int addedAt,
  }) : path = Value(path),
       kind = Value(kind),
       addedAt = Value(addedAt);
  static Insertable<ScanRootRow> custom({
    Expression<int>? id,
    Expression<String>? path,
    Expression<String>? kind,
    Expression<int>? addedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
      if (kind != null) 'kind': kind,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  ScanRootsCompanion copyWith({
    Value<int>? id,
    Value<String>? path,
    Value<String>? kind,
    Value<int>? addedAt,
  }) {
    return ScanRootsCompanion(
      id: id ?? this.id,
      path: path ?? this.path,
      kind: kind ?? this.kind,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScanRootsCompanion(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('kind: $kind, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

class $AudioCacheTable extends AudioCache
    with TableInfo<$AudioCacheTable, AudioCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AudioCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceTrackIdMeta = const VerificationMeta(
    'sourceTrackId',
  );
  @override
  late final GeneratedColumn<String> sourceTrackId = GeneratedColumn<String>(
    'source_track_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackUriMeta = const VerificationMeta(
    'trackUri',
  );
  @override
  late final GeneratedColumn<String> trackUri = GeneratedColumn<String>(
    'track_uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qualityIdMeta = const VerificationMeta(
    'qualityId',
  );
  @override
  late final GeneratedColumn<String> qualityId = GeneratedColumn<String>(
    'quality_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
    'pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<int> cachedAt = GeneratedColumn<int>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastAccessedAtMeta = const VerificationMeta(
    'lastAccessedAt',
  );
  @override
  late final GeneratedColumn<int> lastAccessedAt = GeneratedColumn<int>(
    'last_accessed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverPathMeta = const VerificationMeta(
    'coverPath',
  );
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
    'cover_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverBytesMeta = const VerificationMeta(
    'coverBytes',
  );
  @override
  late final GeneratedColumn<int> coverBytes = GeneratedColumn<int>(
    'cover_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    source,
    sourceTrackId,
    trackUri,
    filePath,
    bytes,
    qualityId,
    pinned,
    cachedAt,
    lastAccessedAt,
    contentHash,
    coverPath,
    coverBytes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audio_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<AudioCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('source_track_id')) {
      context.handle(
        _sourceTrackIdMeta,
        sourceTrackId.isAcceptableOrUnknown(
          data['source_track_id']!,
          _sourceTrackIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceTrackIdMeta);
    }
    if (data.containsKey('track_uri')) {
      context.handle(
        _trackUriMeta,
        trackUri.isAcceptableOrUnknown(data['track_uri']!, _trackUriMeta),
      );
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    if (data.containsKey('quality_id')) {
      context.handle(
        _qualityIdMeta,
        qualityId.isAcceptableOrUnknown(data['quality_id']!, _qualityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_qualityIdMeta);
    }
    if (data.containsKey('pinned')) {
      context.handle(
        _pinnedMeta,
        pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    if (data.containsKey('last_accessed_at')) {
      context.handle(
        _lastAccessedAtMeta,
        lastAccessedAt.isAcceptableOrUnknown(
          data['last_accessed_at']!,
          _lastAccessedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastAccessedAtMeta);
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('cover_bytes')) {
      context.handle(
        _coverBytesMeta,
        coverBytes.isAcceptableOrUnknown(data['cover_bytes']!, _coverBytesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {source, sourceTrackId},
  ];
  @override
  AudioCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AudioCacheRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      sourceTrackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_track_id'],
      )!,
      trackUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_uri'],
      ),
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes'],
      )!,
      qualityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quality_id'],
      )!,
      pinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pinned'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cached_at'],
      )!,
      lastAccessedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_accessed_at'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      ),
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      coverBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cover_bytes'],
      )!,
    );
  }

  @override
  $AudioCacheTable createAlias(String alias) {
    return $AudioCacheTable(attachedDatabase, alias);
  }
}

class AudioCacheRow extends DataClass implements Insertable<AudioCacheRow> {
  final int id;

  /// Source identifier, e.g. `bilibili`.
  final String source;

  /// Source-specific identity, e.g. `BV...:cid`.
  final String sourceTrackId;

  /// Canonical pool key (schema v11), backfilled from `tracks.uri`.
  ///
  /// Nullable for legacy cache rows whose pool row no longer exists; new rows
  /// always carry it. This is the shared identity for cache, downloads,
  /// lyrics and stats.
  final String? trackUri;

  /// Absolute path of the cached file.
  final String filePath;

  /// Size of the cached file, in bytes.
  final int bytes;

  /// Stream quality the file was downloaded at, e.g. `30280`.
  final String qualityId;

  /// Manual downloads are pinned and excluded from LRU eviction.
  final bool pinned;

  /// Unix timestamp when the file entered the cache.
  final int cachedAt;

  /// Unix timestamp of the last read; the LRU ordering key.
  final int lastAccessedAt;

  /// SHA-1 hex digest of the cached file's bytes (schema v6).
  ///
  /// Identical content written under two logical keys shares one physical
  /// file; this column is how those rows are grouped. `null` for legacy rows
  /// written before v6 and for rows whose file could not be hashed.
  final String? contentHash;

  /// Absolute path of the song's companion cover, or `null` when none.
  final String? coverPath;

  /// Bytes of the companion cover, counted in the layer-1 quota.
  final int coverBytes;
  const AudioCacheRow({
    required this.id,
    required this.source,
    required this.sourceTrackId,
    this.trackUri,
    required this.filePath,
    required this.bytes,
    required this.qualityId,
    required this.pinned,
    required this.cachedAt,
    required this.lastAccessedAt,
    this.contentHash,
    this.coverPath,
    required this.coverBytes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source'] = Variable<String>(source);
    map['source_track_id'] = Variable<String>(sourceTrackId);
    if (!nullToAbsent || trackUri != null) {
      map['track_uri'] = Variable<String>(trackUri);
    }
    map['file_path'] = Variable<String>(filePath);
    map['bytes'] = Variable<int>(bytes);
    map['quality_id'] = Variable<String>(qualityId);
    map['pinned'] = Variable<bool>(pinned);
    map['cached_at'] = Variable<int>(cachedAt);
    map['last_accessed_at'] = Variable<int>(lastAccessedAt);
    if (!nullToAbsent || contentHash != null) {
      map['content_hash'] = Variable<String>(contentHash);
    }
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    map['cover_bytes'] = Variable<int>(coverBytes);
    return map;
  }

  AudioCacheCompanion toCompanion(bool nullToAbsent) {
    return AudioCacheCompanion(
      id: Value(id),
      source: Value(source),
      sourceTrackId: Value(sourceTrackId),
      trackUri: trackUri == null && nullToAbsent
          ? const Value.absent()
          : Value(trackUri),
      filePath: Value(filePath),
      bytes: Value(bytes),
      qualityId: Value(qualityId),
      pinned: Value(pinned),
      cachedAt: Value(cachedAt),
      lastAccessedAt: Value(lastAccessedAt),
      contentHash: contentHash == null && nullToAbsent
          ? const Value.absent()
          : Value(contentHash),
      coverPath: coverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverPath),
      coverBytes: Value(coverBytes),
    );
  }

  factory AudioCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AudioCacheRow(
      id: serializer.fromJson<int>(json['id']),
      source: serializer.fromJson<String>(json['source']),
      sourceTrackId: serializer.fromJson<String>(json['sourceTrackId']),
      trackUri: serializer.fromJson<String?>(json['trackUri']),
      filePath: serializer.fromJson<String>(json['filePath']),
      bytes: serializer.fromJson<int>(json['bytes']),
      qualityId: serializer.fromJson<String>(json['qualityId']),
      pinned: serializer.fromJson<bool>(json['pinned']),
      cachedAt: serializer.fromJson<int>(json['cachedAt']),
      lastAccessedAt: serializer.fromJson<int>(json['lastAccessedAt']),
      contentHash: serializer.fromJson<String?>(json['contentHash']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      coverBytes: serializer.fromJson<int>(json['coverBytes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'source': serializer.toJson<String>(source),
      'sourceTrackId': serializer.toJson<String>(sourceTrackId),
      'trackUri': serializer.toJson<String?>(trackUri),
      'filePath': serializer.toJson<String>(filePath),
      'bytes': serializer.toJson<int>(bytes),
      'qualityId': serializer.toJson<String>(qualityId),
      'pinned': serializer.toJson<bool>(pinned),
      'cachedAt': serializer.toJson<int>(cachedAt),
      'lastAccessedAt': serializer.toJson<int>(lastAccessedAt),
      'contentHash': serializer.toJson<String?>(contentHash),
      'coverPath': serializer.toJson<String?>(coverPath),
      'coverBytes': serializer.toJson<int>(coverBytes),
    };
  }

  AudioCacheRow copyWith({
    int? id,
    String? source,
    String? sourceTrackId,
    Value<String?> trackUri = const Value.absent(),
    String? filePath,
    int? bytes,
    String? qualityId,
    bool? pinned,
    int? cachedAt,
    int? lastAccessedAt,
    Value<String?> contentHash = const Value.absent(),
    Value<String?> coverPath = const Value.absent(),
    int? coverBytes,
  }) => AudioCacheRow(
    id: id ?? this.id,
    source: source ?? this.source,
    sourceTrackId: sourceTrackId ?? this.sourceTrackId,
    trackUri: trackUri.present ? trackUri.value : this.trackUri,
    filePath: filePath ?? this.filePath,
    bytes: bytes ?? this.bytes,
    qualityId: qualityId ?? this.qualityId,
    pinned: pinned ?? this.pinned,
    cachedAt: cachedAt ?? this.cachedAt,
    lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
    contentHash: contentHash.present ? contentHash.value : this.contentHash,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    coverBytes: coverBytes ?? this.coverBytes,
  );
  AudioCacheRow copyWithCompanion(AudioCacheCompanion data) {
    return AudioCacheRow(
      id: data.id.present ? data.id.value : this.id,
      source: data.source.present ? data.source.value : this.source,
      sourceTrackId: data.sourceTrackId.present
          ? data.sourceTrackId.value
          : this.sourceTrackId,
      trackUri: data.trackUri.present ? data.trackUri.value : this.trackUri,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      qualityId: data.qualityId.present ? data.qualityId.value : this.qualityId,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
      lastAccessedAt: data.lastAccessedAt.present
          ? data.lastAccessedAt.value
          : this.lastAccessedAt,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      coverBytes: data.coverBytes.present
          ? data.coverBytes.value
          : this.coverBytes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AudioCacheRow(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('sourceTrackId: $sourceTrackId, ')
          ..write('trackUri: $trackUri, ')
          ..write('filePath: $filePath, ')
          ..write('bytes: $bytes, ')
          ..write('qualityId: $qualityId, ')
          ..write('pinned: $pinned, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('lastAccessedAt: $lastAccessedAt, ')
          ..write('contentHash: $contentHash, ')
          ..write('coverPath: $coverPath, ')
          ..write('coverBytes: $coverBytes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    source,
    sourceTrackId,
    trackUri,
    filePath,
    bytes,
    qualityId,
    pinned,
    cachedAt,
    lastAccessedAt,
    contentHash,
    coverPath,
    coverBytes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AudioCacheRow &&
          other.id == this.id &&
          other.source == this.source &&
          other.sourceTrackId == this.sourceTrackId &&
          other.trackUri == this.trackUri &&
          other.filePath == this.filePath &&
          other.bytes == this.bytes &&
          other.qualityId == this.qualityId &&
          other.pinned == this.pinned &&
          other.cachedAt == this.cachedAt &&
          other.lastAccessedAt == this.lastAccessedAt &&
          other.contentHash == this.contentHash &&
          other.coverPath == this.coverPath &&
          other.coverBytes == this.coverBytes);
}

class AudioCacheCompanion extends UpdateCompanion<AudioCacheRow> {
  final Value<int> id;
  final Value<String> source;
  final Value<String> sourceTrackId;
  final Value<String?> trackUri;
  final Value<String> filePath;
  final Value<int> bytes;
  final Value<String> qualityId;
  final Value<bool> pinned;
  final Value<int> cachedAt;
  final Value<int> lastAccessedAt;
  final Value<String?> contentHash;
  final Value<String?> coverPath;
  final Value<int> coverBytes;
  const AudioCacheCompanion({
    this.id = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceTrackId = const Value.absent(),
    this.trackUri = const Value.absent(),
    this.filePath = const Value.absent(),
    this.bytes = const Value.absent(),
    this.qualityId = const Value.absent(),
    this.pinned = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.lastAccessedAt = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.coverBytes = const Value.absent(),
  });
  AudioCacheCompanion.insert({
    this.id = const Value.absent(),
    required String source,
    required String sourceTrackId,
    this.trackUri = const Value.absent(),
    required String filePath,
    required int bytes,
    required String qualityId,
    this.pinned = const Value.absent(),
    required int cachedAt,
    required int lastAccessedAt,
    this.contentHash = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.coverBytes = const Value.absent(),
  }) : source = Value(source),
       sourceTrackId = Value(sourceTrackId),
       filePath = Value(filePath),
       bytes = Value(bytes),
       qualityId = Value(qualityId),
       cachedAt = Value(cachedAt),
       lastAccessedAt = Value(lastAccessedAt);
  static Insertable<AudioCacheRow> custom({
    Expression<int>? id,
    Expression<String>? source,
    Expression<String>? sourceTrackId,
    Expression<String>? trackUri,
    Expression<String>? filePath,
    Expression<int>? bytes,
    Expression<String>? qualityId,
    Expression<bool>? pinned,
    Expression<int>? cachedAt,
    Expression<int>? lastAccessedAt,
    Expression<String>? contentHash,
    Expression<String>? coverPath,
    Expression<int>? coverBytes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (source != null) 'source': source,
      if (sourceTrackId != null) 'source_track_id': sourceTrackId,
      if (trackUri != null) 'track_uri': trackUri,
      if (filePath != null) 'file_path': filePath,
      if (bytes != null) 'bytes': bytes,
      if (qualityId != null) 'quality_id': qualityId,
      if (pinned != null) 'pinned': pinned,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (lastAccessedAt != null) 'last_accessed_at': lastAccessedAt,
      if (contentHash != null) 'content_hash': contentHash,
      if (coverPath != null) 'cover_path': coverPath,
      if (coverBytes != null) 'cover_bytes': coverBytes,
    });
  }

  AudioCacheCompanion copyWith({
    Value<int>? id,
    Value<String>? source,
    Value<String>? sourceTrackId,
    Value<String?>? trackUri,
    Value<String>? filePath,
    Value<int>? bytes,
    Value<String>? qualityId,
    Value<bool>? pinned,
    Value<int>? cachedAt,
    Value<int>? lastAccessedAt,
    Value<String?>? contentHash,
    Value<String?>? coverPath,
    Value<int>? coverBytes,
  }) {
    return AudioCacheCompanion(
      id: id ?? this.id,
      source: source ?? this.source,
      sourceTrackId: sourceTrackId ?? this.sourceTrackId,
      trackUri: trackUri ?? this.trackUri,
      filePath: filePath ?? this.filePath,
      bytes: bytes ?? this.bytes,
      qualityId: qualityId ?? this.qualityId,
      pinned: pinned ?? this.pinned,
      cachedAt: cachedAt ?? this.cachedAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      contentHash: contentHash ?? this.contentHash,
      coverPath: coverPath ?? this.coverPath,
      coverBytes: coverBytes ?? this.coverBytes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (sourceTrackId.present) {
      map['source_track_id'] = Variable<String>(sourceTrackId.value);
    }
    if (trackUri.present) {
      map['track_uri'] = Variable<String>(trackUri.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<int>(bytes.value);
    }
    if (qualityId.present) {
      map['quality_id'] = Variable<String>(qualityId.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<int>(cachedAt.value);
    }
    if (lastAccessedAt.present) {
      map['last_accessed_at'] = Variable<int>(lastAccessedAt.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (coverBytes.present) {
      map['cover_bytes'] = Variable<int>(coverBytes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AudioCacheCompanion(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('sourceTrackId: $sourceTrackId, ')
          ..write('trackUri: $trackUri, ')
          ..write('filePath: $filePath, ')
          ..write('bytes: $bytes, ')
          ..write('qualityId: $qualityId, ')
          ..write('pinned: $pinned, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('lastAccessedAt: $lastAccessedAt, ')
          ..write('contentHash: $contentHash, ')
          ..write('coverPath: $coverPath, ')
          ..write('coverBytes: $coverBytes')
          ..write(')'))
        .toString();
  }
}

class $CoverCacheTable extends CoverCache
    with TableInfo<$CoverCacheTable, CoverCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CoverCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _urlHashMeta = const VerificationMeta(
    'urlHash',
  );
  @override
  late final GeneratedColumn<String> urlHash = GeneratedColumn<String>(
    'url_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<int> cachedAt = GeneratedColumn<int>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastAccessedAtMeta = const VerificationMeta(
    'lastAccessedAt',
  );
  @override
  late final GeneratedColumn<int> lastAccessedAt = GeneratedColumn<int>(
    'last_accessed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    urlHash,
    filePath,
    contentHash,
    bytes,
    cachedAt,
    lastAccessedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cover_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<CoverCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('url_hash')) {
      context.handle(
        _urlHashMeta,
        urlHash.isAcceptableOrUnknown(data['url_hash']!, _urlHashMeta),
      );
    } else if (isInserting) {
      context.missing(_urlHashMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    if (data.containsKey('last_accessed_at')) {
      context.handle(
        _lastAccessedAtMeta,
        lastAccessedAt.isAcceptableOrUnknown(
          data['last_accessed_at']!,
          _lastAccessedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastAccessedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CoverCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CoverCacheRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      urlHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url_hash'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cached_at'],
      )!,
      lastAccessedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_accessed_at'],
      )!,
    );
  }

  @override
  $CoverCacheTable createAlias(String alias) {
    return $CoverCacheTable(attachedDatabase, alias);
  }
}

class CoverCacheRow extends DataClass implements Insertable<CoverCacheRow> {
  final int id;

  /// `sha1(normalized cover URL)`; the lookup key.
  final String urlHash;

  /// Absolute path of the cached file.
  final String filePath;

  /// `sha1` hex digest of the stored bytes; also the on-disk file name.
  final String contentHash;

  /// Size of the cached file, in bytes.
  final int bytes;

  /// Unix timestamp when the file entered the cache.
  final int cachedAt;

  /// Unix timestamp of the last read; the LRU ordering key.
  final int lastAccessedAt;
  const CoverCacheRow({
    required this.id,
    required this.urlHash,
    required this.filePath,
    required this.contentHash,
    required this.bytes,
    required this.cachedAt,
    required this.lastAccessedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['url_hash'] = Variable<String>(urlHash);
    map['file_path'] = Variable<String>(filePath);
    map['content_hash'] = Variable<String>(contentHash);
    map['bytes'] = Variable<int>(bytes);
    map['cached_at'] = Variable<int>(cachedAt);
    map['last_accessed_at'] = Variable<int>(lastAccessedAt);
    return map;
  }

  CoverCacheCompanion toCompanion(bool nullToAbsent) {
    return CoverCacheCompanion(
      id: Value(id),
      urlHash: Value(urlHash),
      filePath: Value(filePath),
      contentHash: Value(contentHash),
      bytes: Value(bytes),
      cachedAt: Value(cachedAt),
      lastAccessedAt: Value(lastAccessedAt),
    );
  }

  factory CoverCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CoverCacheRow(
      id: serializer.fromJson<int>(json['id']),
      urlHash: serializer.fromJson<String>(json['urlHash']),
      filePath: serializer.fromJson<String>(json['filePath']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
      bytes: serializer.fromJson<int>(json['bytes']),
      cachedAt: serializer.fromJson<int>(json['cachedAt']),
      lastAccessedAt: serializer.fromJson<int>(json['lastAccessedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'urlHash': serializer.toJson<String>(urlHash),
      'filePath': serializer.toJson<String>(filePath),
      'contentHash': serializer.toJson<String>(contentHash),
      'bytes': serializer.toJson<int>(bytes),
      'cachedAt': serializer.toJson<int>(cachedAt),
      'lastAccessedAt': serializer.toJson<int>(lastAccessedAt),
    };
  }

  CoverCacheRow copyWith({
    int? id,
    String? urlHash,
    String? filePath,
    String? contentHash,
    int? bytes,
    int? cachedAt,
    int? lastAccessedAt,
  }) => CoverCacheRow(
    id: id ?? this.id,
    urlHash: urlHash ?? this.urlHash,
    filePath: filePath ?? this.filePath,
    contentHash: contentHash ?? this.contentHash,
    bytes: bytes ?? this.bytes,
    cachedAt: cachedAt ?? this.cachedAt,
    lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
  );
  CoverCacheRow copyWithCompanion(CoverCacheCompanion data) {
    return CoverCacheRow(
      id: data.id.present ? data.id.value : this.id,
      urlHash: data.urlHash.present ? data.urlHash.value : this.urlHash,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
      lastAccessedAt: data.lastAccessedAt.present
          ? data.lastAccessedAt.value
          : this.lastAccessedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CoverCacheRow(')
          ..write('id: $id, ')
          ..write('urlHash: $urlHash, ')
          ..write('filePath: $filePath, ')
          ..write('contentHash: $contentHash, ')
          ..write('bytes: $bytes, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('lastAccessedAt: $lastAccessedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    urlHash,
    filePath,
    contentHash,
    bytes,
    cachedAt,
    lastAccessedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CoverCacheRow &&
          other.id == this.id &&
          other.urlHash == this.urlHash &&
          other.filePath == this.filePath &&
          other.contentHash == this.contentHash &&
          other.bytes == this.bytes &&
          other.cachedAt == this.cachedAt &&
          other.lastAccessedAt == this.lastAccessedAt);
}

class CoverCacheCompanion extends UpdateCompanion<CoverCacheRow> {
  final Value<int> id;
  final Value<String> urlHash;
  final Value<String> filePath;
  final Value<String> contentHash;
  final Value<int> bytes;
  final Value<int> cachedAt;
  final Value<int> lastAccessedAt;
  const CoverCacheCompanion({
    this.id = const Value.absent(),
    this.urlHash = const Value.absent(),
    this.filePath = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.bytes = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.lastAccessedAt = const Value.absent(),
  });
  CoverCacheCompanion.insert({
    this.id = const Value.absent(),
    required String urlHash,
    required String filePath,
    required String contentHash,
    required int bytes,
    required int cachedAt,
    required int lastAccessedAt,
  }) : urlHash = Value(urlHash),
       filePath = Value(filePath),
       contentHash = Value(contentHash),
       bytes = Value(bytes),
       cachedAt = Value(cachedAt),
       lastAccessedAt = Value(lastAccessedAt);
  static Insertable<CoverCacheRow> custom({
    Expression<int>? id,
    Expression<String>? urlHash,
    Expression<String>? filePath,
    Expression<String>? contentHash,
    Expression<int>? bytes,
    Expression<int>? cachedAt,
    Expression<int>? lastAccessedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (urlHash != null) 'url_hash': urlHash,
      if (filePath != null) 'file_path': filePath,
      if (contentHash != null) 'content_hash': contentHash,
      if (bytes != null) 'bytes': bytes,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (lastAccessedAt != null) 'last_accessed_at': lastAccessedAt,
    });
  }

  CoverCacheCompanion copyWith({
    Value<int>? id,
    Value<String>? urlHash,
    Value<String>? filePath,
    Value<String>? contentHash,
    Value<int>? bytes,
    Value<int>? cachedAt,
    Value<int>? lastAccessedAt,
  }) {
    return CoverCacheCompanion(
      id: id ?? this.id,
      urlHash: urlHash ?? this.urlHash,
      filePath: filePath ?? this.filePath,
      contentHash: contentHash ?? this.contentHash,
      bytes: bytes ?? this.bytes,
      cachedAt: cachedAt ?? this.cachedAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (urlHash.present) {
      map['url_hash'] = Variable<String>(urlHash.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<int>(bytes.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<int>(cachedAt.value);
    }
    if (lastAccessedAt.present) {
      map['last_accessed_at'] = Variable<int>(lastAccessedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CoverCacheCompanion(')
          ..write('id: $id, ')
          ..write('urlHash: $urlHash, ')
          ..write('filePath: $filePath, ')
          ..write('contentHash: $contentHash, ')
          ..write('bytes: $bytes, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('lastAccessedAt: $lastAccessedAt')
          ..write(')'))
        .toString();
  }
}

class $PlaybackStatesTable extends PlaybackStates
    with TableInfo<$PlaybackStatesTable, PlaybackStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _queueJsonMeta = const VerificationMeta(
    'queueJson',
  );
  @override
  late final GeneratedColumn<String> queueJson = GeneratedColumn<String>(
    'queue_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentIndexMeta = const VerificationMeta(
    'currentIndex',
  );
  @override
  late final GeneratedColumn<int> currentIndex = GeneratedColumn<int>(
    'current_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repeatModeMeta = const VerificationMeta(
    'repeatMode',
  );
  @override
  late final GeneratedColumn<String> repeatMode = GeneratedColumn<String>(
    'repeat_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _shuffleEnabledMeta = const VerificationMeta(
    'shuffleEnabled',
  );
  @override
  late final GeneratedColumn<bool> shuffleEnabled = GeneratedColumn<bool>(
    'shuffle_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("shuffle_enabled" IN (0, 1))',
    ),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    queueJson,
    currentIndex,
    positionMs,
    repeatMode,
    shuffleEnabled,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaybackStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('queue_json')) {
      context.handle(
        _queueJsonMeta,
        queueJson.isAcceptableOrUnknown(data['queue_json']!, _queueJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_queueJsonMeta);
    }
    if (data.containsKey('current_index')) {
      context.handle(
        _currentIndexMeta,
        currentIndex.isAcceptableOrUnknown(
          data['current_index']!,
          _currentIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currentIndexMeta);
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMsMeta);
    }
    if (data.containsKey('repeat_mode')) {
      context.handle(
        _repeatModeMeta,
        repeatMode.isAcceptableOrUnknown(data['repeat_mode']!, _repeatModeMeta),
      );
    } else if (isInserting) {
      context.missing(_repeatModeMeta);
    }
    if (data.containsKey('shuffle_enabled')) {
      context.handle(
        _shuffleEnabledMeta,
        shuffleEnabled.isAcceptableOrUnknown(
          data['shuffle_enabled']!,
          _shuffleEnabledMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_shuffleEnabledMeta);
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaybackStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackStateRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      queueJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}queue_json'],
      )!,
      currentIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_index'],
      )!,
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      repeatMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repeat_mode'],
      )!,
      shuffleEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}shuffle_enabled'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PlaybackStatesTable createAlias(String alias) {
    return $PlaybackStatesTable(attachedDatabase, alias);
  }
}

class PlaybackStateRow extends DataClass
    implements Insertable<PlaybackStateRow> {
  final int id;

  /// Serialised playback queue (tracks + originalOrder), see the codec.
  final String queueJson;

  /// Index of the current track within the serialised queue.
  final int currentIndex;

  /// Playback position, in milliseconds.
  final int positionMs;

  /// Persisted repeat mode name (`off` / `all` / `one`).
  final String repeatMode;
  final bool shuffleEnabled;

  /// Unix timestamp of the last write.
  final int updatedAt;
  const PlaybackStateRow({
    required this.id,
    required this.queueJson,
    required this.currentIndex,
    required this.positionMs,
    required this.repeatMode,
    required this.shuffleEnabled,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['queue_json'] = Variable<String>(queueJson);
    map['current_index'] = Variable<int>(currentIndex);
    map['position_ms'] = Variable<int>(positionMs);
    map['repeat_mode'] = Variable<String>(repeatMode);
    map['shuffle_enabled'] = Variable<bool>(shuffleEnabled);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  PlaybackStatesCompanion toCompanion(bool nullToAbsent) {
    return PlaybackStatesCompanion(
      id: Value(id),
      queueJson: Value(queueJson),
      currentIndex: Value(currentIndex),
      positionMs: Value(positionMs),
      repeatMode: Value(repeatMode),
      shuffleEnabled: Value(shuffleEnabled),
      updatedAt: Value(updatedAt),
    );
  }

  factory PlaybackStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackStateRow(
      id: serializer.fromJson<int>(json['id']),
      queueJson: serializer.fromJson<String>(json['queueJson']),
      currentIndex: serializer.fromJson<int>(json['currentIndex']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      repeatMode: serializer.fromJson<String>(json['repeatMode']),
      shuffleEnabled: serializer.fromJson<bool>(json['shuffleEnabled']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'queueJson': serializer.toJson<String>(queueJson),
      'currentIndex': serializer.toJson<int>(currentIndex),
      'positionMs': serializer.toJson<int>(positionMs),
      'repeatMode': serializer.toJson<String>(repeatMode),
      'shuffleEnabled': serializer.toJson<bool>(shuffleEnabled),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  PlaybackStateRow copyWith({
    int? id,
    String? queueJson,
    int? currentIndex,
    int? positionMs,
    String? repeatMode,
    bool? shuffleEnabled,
    int? updatedAt,
  }) => PlaybackStateRow(
    id: id ?? this.id,
    queueJson: queueJson ?? this.queueJson,
    currentIndex: currentIndex ?? this.currentIndex,
    positionMs: positionMs ?? this.positionMs,
    repeatMode: repeatMode ?? this.repeatMode,
    shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PlaybackStateRow copyWithCompanion(PlaybackStatesCompanion data) {
    return PlaybackStateRow(
      id: data.id.present ? data.id.value : this.id,
      queueJson: data.queueJson.present ? data.queueJson.value : this.queueJson,
      currentIndex: data.currentIndex.present
          ? data.currentIndex.value
          : this.currentIndex,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      repeatMode: data.repeatMode.present
          ? data.repeatMode.value
          : this.repeatMode,
      shuffleEnabled: data.shuffleEnabled.present
          ? data.shuffleEnabled.value
          : this.shuffleEnabled,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackStateRow(')
          ..write('id: $id, ')
          ..write('queueJson: $queueJson, ')
          ..write('currentIndex: $currentIndex, ')
          ..write('positionMs: $positionMs, ')
          ..write('repeatMode: $repeatMode, ')
          ..write('shuffleEnabled: $shuffleEnabled, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    queueJson,
    currentIndex,
    positionMs,
    repeatMode,
    shuffleEnabled,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackStateRow &&
          other.id == this.id &&
          other.queueJson == this.queueJson &&
          other.currentIndex == this.currentIndex &&
          other.positionMs == this.positionMs &&
          other.repeatMode == this.repeatMode &&
          other.shuffleEnabled == this.shuffleEnabled &&
          other.updatedAt == this.updatedAt);
}

class PlaybackStatesCompanion extends UpdateCompanion<PlaybackStateRow> {
  final Value<int> id;
  final Value<String> queueJson;
  final Value<int> currentIndex;
  final Value<int> positionMs;
  final Value<String> repeatMode;
  final Value<bool> shuffleEnabled;
  final Value<int> updatedAt;
  const PlaybackStatesCompanion({
    this.id = const Value.absent(),
    this.queueJson = const Value.absent(),
    this.currentIndex = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.repeatMode = const Value.absent(),
    this.shuffleEnabled = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  PlaybackStatesCompanion.insert({
    this.id = const Value.absent(),
    required String queueJson,
    required int currentIndex,
    required int positionMs,
    required String repeatMode,
    required bool shuffleEnabled,
    required int updatedAt,
  }) : queueJson = Value(queueJson),
       currentIndex = Value(currentIndex),
       positionMs = Value(positionMs),
       repeatMode = Value(repeatMode),
       shuffleEnabled = Value(shuffleEnabled),
       updatedAt = Value(updatedAt);
  static Insertable<PlaybackStateRow> custom({
    Expression<int>? id,
    Expression<String>? queueJson,
    Expression<int>? currentIndex,
    Expression<int>? positionMs,
    Expression<String>? repeatMode,
    Expression<bool>? shuffleEnabled,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (queueJson != null) 'queue_json': queueJson,
      if (currentIndex != null) 'current_index': currentIndex,
      if (positionMs != null) 'position_ms': positionMs,
      if (repeatMode != null) 'repeat_mode': repeatMode,
      if (shuffleEnabled != null) 'shuffle_enabled': shuffleEnabled,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  PlaybackStatesCompanion copyWith({
    Value<int>? id,
    Value<String>? queueJson,
    Value<int>? currentIndex,
    Value<int>? positionMs,
    Value<String>? repeatMode,
    Value<bool>? shuffleEnabled,
    Value<int>? updatedAt,
  }) {
    return PlaybackStatesCompanion(
      id: id ?? this.id,
      queueJson: queueJson ?? this.queueJson,
      currentIndex: currentIndex ?? this.currentIndex,
      positionMs: positionMs ?? this.positionMs,
      repeatMode: repeatMode ?? this.repeatMode,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (queueJson.present) {
      map['queue_json'] = Variable<String>(queueJson.value);
    }
    if (currentIndex.present) {
      map['current_index'] = Variable<int>(currentIndex.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (repeatMode.present) {
      map['repeat_mode'] = Variable<String>(repeatMode.value);
    }
    if (shuffleEnabled.present) {
      map['shuffle_enabled'] = Variable<bool>(shuffleEnabled.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackStatesCompanion(')
          ..write('id: $id, ')
          ..write('queueJson: $queueJson, ')
          ..write('currentIndex: $currentIndex, ')
          ..write('positionMs: $positionMs, ')
          ..write('repeatMode: $repeatMode, ')
          ..write('shuffleEnabled: $shuffleEnabled, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $PlaylistsTable extends Playlists
    with TableInfo<$PlaylistsTable, PlaylistRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _publicIdMeta = const VerificationMeta(
    'publicId',
  );
  @override
  late final GeneratedColumn<String> publicId = GeneratedColumn<String>(
    'public_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverPathMeta = const VerificationMeta(
    'coverPath',
  );
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
    'cover_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    publicId,
    name,
    kind,
    description,
    coverPath,
    coverUrl,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('public_id')) {
      context.handle(
        _publicIdMeta,
        publicId.isAcceptableOrUnknown(data['public_id']!, _publicIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaylistRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      publicId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}public_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PlaylistsTable createAlias(String alias) {
    return $PlaylistsTable(attachedDatabase, alias);
  }
}

class PlaylistRow extends DataClass implements Insertable<PlaylistRow> {
  final int id;

  /// Stable, export-safe identifier (schema v11).
  ///
  /// The integer [id] stays the internal row id; [publicId] is what future
  /// export/import and multi-device sync use. Existing rows are backfilled in
  /// the v10 -> v11 migration. Nullable at the SQLite level only so the
  /// additive migration can run without a table rebuild; the repository always
  /// writes a value. Uniqueness is enforced by the named index above.
  final String? publicId;

  /// Display name; required and non-blank.
  final String name;

  /// `favorites` (built-in, id 1) or `custom` (user-created).
  final String kind;
  final String? description;

  /// Explicit cover (overrides the derived fallback chain).
  final String? coverPath;

  /// Remote cover URL, mirroring [Tracks.coverUrl].
  final String? coverUrl;
  final int createdAt;
  final int updatedAt;
  const PlaylistRow({
    required this.id,
    this.publicId,
    required this.name,
    required this.kind,
    this.description,
    this.coverPath,
    this.coverUrl,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || publicId != null) {
      map['public_id'] = Variable<String>(publicId);
    }
    map['name'] = Variable<String>(name);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  PlaylistsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistsCompanion(
      id: Value(id),
      publicId: publicId == null && nullToAbsent
          ? const Value.absent()
          : Value(publicId),
      name: Value(name),
      kind: Value(kind),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      coverPath: coverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverPath),
      coverUrl: coverUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverUrl),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PlaylistRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistRow(
      id: serializer.fromJson<int>(json['id']),
      publicId: serializer.fromJson<String?>(json['publicId']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<String>(json['kind']),
      description: serializer.fromJson<String?>(json['description']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'publicId': serializer.toJson<String?>(publicId),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(kind),
      'description': serializer.toJson<String?>(description),
      'coverPath': serializer.toJson<String?>(coverPath),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  PlaylistRow copyWith({
    int? id,
    Value<String?> publicId = const Value.absent(),
    String? name,
    String? kind,
    Value<String?> description = const Value.absent(),
    Value<String?> coverPath = const Value.absent(),
    Value<String?> coverUrl = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => PlaylistRow(
    id: id ?? this.id,
    publicId: publicId.present ? publicId.value : this.publicId,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    description: description.present ? description.value : this.description,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PlaylistRow copyWithCompanion(PlaylistsCompanion data) {
    return PlaylistRow(
      id: data.id.present ? data.id.value : this.id,
      publicId: data.publicId.present ? data.publicId.value : this.publicId,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      description: data.description.present
          ? data.description.value
          : this.description,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistRow(')
          ..write('id: $id, ')
          ..write('publicId: $publicId, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('description: $description, ')
          ..write('coverPath: $coverPath, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    publicId,
    name,
    kind,
    description,
    coverPath,
    coverUrl,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistRow &&
          other.id == this.id &&
          other.publicId == this.publicId &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.description == this.description &&
          other.coverPath == this.coverPath &&
          other.coverUrl == this.coverUrl &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PlaylistsCompanion extends UpdateCompanion<PlaylistRow> {
  final Value<int> id;
  final Value<String?> publicId;
  final Value<String> name;
  final Value<String> kind;
  final Value<String?> description;
  final Value<String?> coverPath;
  final Value<String?> coverUrl;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  const PlaylistsCompanion({
    this.id = const Value.absent(),
    this.publicId = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.description = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  PlaylistsCompanion.insert({
    this.id = const Value.absent(),
    this.publicId = const Value.absent(),
    required String name,
    required String kind,
    this.description = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.coverUrl = const Value.absent(),
    required int createdAt,
    required int updatedAt,
  }) : name = Value(name),
       kind = Value(kind),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<PlaylistRow> custom({
    Expression<int>? id,
    Expression<String>? publicId,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<String>? description,
    Expression<String>? coverPath,
    Expression<String>? coverUrl,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (publicId != null) 'public_id': publicId,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (description != null) 'description': description,
      if (coverPath != null) 'cover_path': coverPath,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  PlaylistsCompanion copyWith({
    Value<int>? id,
    Value<String?>? publicId,
    Value<String>? name,
    Value<String>? kind,
    Value<String?>? description,
    Value<String?>? coverPath,
    Value<String?>? coverUrl,
    Value<int>? createdAt,
    Value<int>? updatedAt,
  }) {
    return PlaylistsCompanion(
      id: id ?? this.id,
      publicId: publicId ?? this.publicId,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      description: description ?? this.description,
      coverPath: coverPath ?? this.coverPath,
      coverUrl: coverUrl ?? this.coverUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (publicId.present) {
      map['public_id'] = Variable<String>(publicId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistsCompanion(')
          ..write('id: $id, ')
          ..write('publicId: $publicId, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('description: $description, ')
          ..write('coverPath: $coverPath, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $PlaylistTracksTable extends PlaylistTracks
    with TableInfo<$PlaylistTracksTable, PlaylistTrackRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistTracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uriMeta = const VerificationMeta('uri');
  @override
  late final GeneratedColumn<String> uri = GeneratedColumn<String>(
    'uri',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    playlistId,
    uri,
    addedAt,
    position,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlist_tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistTrackRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('uri')) {
      context.handle(
        _uriMeta,
        uri.isAcceptableOrUnknown(data['uri']!, _uriMeta),
      );
    } else if (isInserting) {
      context.missing(_uriMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {playlistId, uri},
  ];
  @override
  PlaylistTrackRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistTrackRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      )!,
      uri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uri'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $PlaylistTracksTable createAlias(String alias) {
    return $PlaylistTracksTable(attachedDatabase, alias);
  }
}

class PlaylistTrackRow extends DataClass
    implements Insertable<PlaylistTrackRow> {
  final int id;

  /// Owning playlist row id.
  final int playlistId;

  /// Canonical pool key (`local:<path>` / `bilibili:<bvid>:<cid>`).
  final String uri;

  /// Unix timestamp when the member was added (kept for display/audit).
  final int addedAt;

  /// Manual display order within the playlist (schema v11).
  ///
  /// Smaller sorts first. Backfilled densely (0..n-1) in the v10 -> v11
  /// migration; new additions are inserted at the front with `min - 1`, and a
  /// manual reorder rewrites the list densely.
  final int position;

  /// Unix timestamp of the last member change (schema v11).
  final int updatedAt;

  /// Unix timestamp when the member was removed, or `null` while live
  /// (schema v11). Kept as a tombstone so future sync can distinguish
  /// "removed elsewhere" from "never existed".
  final int? deletedAt;
  const PlaylistTrackRow({
    required this.id,
    required this.playlistId,
    required this.uri,
    required this.addedAt,
    required this.position,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['playlist_id'] = Variable<int>(playlistId);
    map['uri'] = Variable<String>(uri);
    map['added_at'] = Variable<int>(addedAt);
    map['position'] = Variable<int>(position);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  PlaylistTracksCompanion toCompanion(bool nullToAbsent) {
    return PlaylistTracksCompanion(
      id: Value(id),
      playlistId: Value(playlistId),
      uri: Value(uri),
      addedAt: Value(addedAt),
      position: Value(position),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory PlaylistTrackRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistTrackRow(
      id: serializer.fromJson<int>(json['id']),
      playlistId: serializer.fromJson<int>(json['playlistId']),
      uri: serializer.fromJson<String>(json['uri']),
      addedAt: serializer.fromJson<int>(json['addedAt']),
      position: serializer.fromJson<int>(json['position']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'playlistId': serializer.toJson<int>(playlistId),
      'uri': serializer.toJson<String>(uri),
      'addedAt': serializer.toJson<int>(addedAt),
      'position': serializer.toJson<int>(position),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  PlaylistTrackRow copyWith({
    int? id,
    int? playlistId,
    String? uri,
    int? addedAt,
    int? position,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
  }) => PlaylistTrackRow(
    id: id ?? this.id,
    playlistId: playlistId ?? this.playlistId,
    uri: uri ?? this.uri,
    addedAt: addedAt ?? this.addedAt,
    position: position ?? this.position,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  PlaylistTrackRow copyWithCompanion(PlaylistTracksCompanion data) {
    return PlaylistTrackRow(
      id: data.id.present ? data.id.value : this.id,
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      uri: data.uri.present ? data.uri.value : this.uri,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      position: data.position.present ? data.position.value : this.position,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistTrackRow(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('uri: $uri, ')
          ..write('addedAt: $addedAt, ')
          ..write('position: $position, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, playlistId, uri, addedAt, position, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistTrackRow &&
          other.id == this.id &&
          other.playlistId == this.playlistId &&
          other.uri == this.uri &&
          other.addedAt == this.addedAt &&
          other.position == this.position &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class PlaylistTracksCompanion extends UpdateCompanion<PlaylistTrackRow> {
  final Value<int> id;
  final Value<int> playlistId;
  final Value<String> uri;
  final Value<int> addedAt;
  final Value<int> position;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  const PlaylistTracksCompanion({
    this.id = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.uri = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.position = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  PlaylistTracksCompanion.insert({
    this.id = const Value.absent(),
    required int playlistId,
    required String uri,
    required int addedAt,
    this.position = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  }) : playlistId = Value(playlistId),
       uri = Value(uri),
       addedAt = Value(addedAt);
  static Insertable<PlaylistTrackRow> custom({
    Expression<int>? id,
    Expression<int>? playlistId,
    Expression<String>? uri,
    Expression<int>? addedAt,
    Expression<int>? position,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (playlistId != null) 'playlist_id': playlistId,
      if (uri != null) 'uri': uri,
      if (addedAt != null) 'added_at': addedAt,
      if (position != null) 'position': position,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  PlaylistTracksCompanion copyWith({
    Value<int>? id,
    Value<int>? playlistId,
    Value<String>? uri,
    Value<int>? addedAt,
    Value<int>? position,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
  }) {
    return PlaylistTracksCompanion(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      uri: uri ?? this.uri,
      addedAt: addedAt ?? this.addedAt,
      position: position ?? this.position,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (uri.present) {
      map['uri'] = Variable<String>(uri.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistTracksCompanion(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('uri: $uri, ')
          ..write('addedAt: $addedAt, ')
          ..write('position: $position, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $DownloadsTable extends Downloads
    with TableInfo<$DownloadsTable, DownloadRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _publicIdMeta = const VerificationMeta(
    'publicId',
  );
  @override
  late final GeneratedColumn<String> publicId = GeneratedColumn<String>(
    'public_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _trackUriMeta = const VerificationMeta(
    'trackUri',
  );
  @override
  late final GeneratedColumn<String> trackUri = GeneratedColumn<String>(
    'track_uri',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qualityIdMeta = const VerificationMeta(
    'qualityId',
  );
  @override
  late final GeneratedColumn<String> qualityId = GeneratedColumn<String>(
    'quality_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bytesDoneMeta = const VerificationMeta(
    'bytesDone',
  );
  @override
  late final GeneratedColumn<int> bytesDone = GeneratedColumn<int>(
    'bytes_done',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _bytesTotalMeta = const VerificationMeta(
    'bytesTotal',
  );
  @override
  late final GeneratedColumn<int> bytesTotal = GeneratedColumn<int>(
    'bytes_total',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    publicId,
    trackUri,
    status,
    qualityId,
    filePath,
    bytesDone,
    bytesTotal,
    error,
    createdAt,
    updatedAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'downloads';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('public_id')) {
      context.handle(
        _publicIdMeta,
        publicId.isAcceptableOrUnknown(data['public_id']!, _publicIdMeta),
      );
    } else if (isInserting) {
      context.missing(_publicIdMeta);
    }
    if (data.containsKey('track_uri')) {
      context.handle(
        _trackUriMeta,
        trackUri.isAcceptableOrUnknown(data['track_uri']!, _trackUriMeta),
      );
    } else if (isInserting) {
      context.missing(_trackUriMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('quality_id')) {
      context.handle(
        _qualityIdMeta,
        qualityId.isAcceptableOrUnknown(data['quality_id']!, _qualityIdMeta),
      );
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    }
    if (data.containsKey('bytes_done')) {
      context.handle(
        _bytesDoneMeta,
        bytesDone.isAcceptableOrUnknown(data['bytes_done']!, _bytesDoneMeta),
      );
    }
    if (data.containsKey('bytes_total')) {
      context.handle(
        _bytesTotalMeta,
        bytesTotal.isAcceptableOrUnknown(data['bytes_total']!, _bytesTotalMeta),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
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
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DownloadRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      publicId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}public_id'],
      )!,
      trackUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_uri'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      qualityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quality_id'],
      ),
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      ),
      bytesDone: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes_done'],
      )!,
      bytesTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes_total'],
      ),
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $DownloadsTable createAlias(String alias) {
    return $DownloadsTable(attachedDatabase, alias);
  }
}

class DownloadRow extends DataClass implements Insertable<DownloadRow> {
  final int id;

  /// Stable, export-safe identifier for future sync/import.
  final String publicId;

  /// Canonical pool key (`tracks.uri`).
  final String trackUri;

  /// `queued` / `downloading` / `paused` / `done` / `failed` / `canceled`.
  final String status;

  /// Source-specific quality id, when known.
  final String? qualityId;

  /// Absolute path of the finished audio file, or `null` while incomplete.
  final String? filePath;

  /// Bytes written so far.
  final int bytesDone;

  /// Total bytes when the source reports a length, else `null`.
  final int? bytesTotal;

  /// Last error message for `failed`, else `null`.
  final String? error;
  final int createdAt;
  final int updatedAt;
  final int? completedAt;
  const DownloadRow({
    required this.id,
    required this.publicId,
    required this.trackUri,
    required this.status,
    this.qualityId,
    this.filePath,
    required this.bytesDone,
    this.bytesTotal,
    this.error,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['public_id'] = Variable<String>(publicId);
    map['track_uri'] = Variable<String>(trackUri);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || qualityId != null) {
      map['quality_id'] = Variable<String>(qualityId);
    }
    if (!nullToAbsent || filePath != null) {
      map['file_path'] = Variable<String>(filePath);
    }
    map['bytes_done'] = Variable<int>(bytesDone);
    if (!nullToAbsent || bytesTotal != null) {
      map['bytes_total'] = Variable<int>(bytesTotal);
    }
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<int>(completedAt);
    }
    return map;
  }

  DownloadsCompanion toCompanion(bool nullToAbsent) {
    return DownloadsCompanion(
      id: Value(id),
      publicId: Value(publicId),
      trackUri: Value(trackUri),
      status: Value(status),
      qualityId: qualityId == null && nullToAbsent
          ? const Value.absent()
          : Value(qualityId),
      filePath: filePath == null && nullToAbsent
          ? const Value.absent()
          : Value(filePath),
      bytesDone: Value(bytesDone),
      bytesTotal: bytesTotal == null && nullToAbsent
          ? const Value.absent()
          : Value(bytesTotal),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory DownloadRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadRow(
      id: serializer.fromJson<int>(json['id']),
      publicId: serializer.fromJson<String>(json['publicId']),
      trackUri: serializer.fromJson<String>(json['trackUri']),
      status: serializer.fromJson<String>(json['status']),
      qualityId: serializer.fromJson<String?>(json['qualityId']),
      filePath: serializer.fromJson<String?>(json['filePath']),
      bytesDone: serializer.fromJson<int>(json['bytesDone']),
      bytesTotal: serializer.fromJson<int?>(json['bytesTotal']),
      error: serializer.fromJson<String?>(json['error']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      completedAt: serializer.fromJson<int?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'publicId': serializer.toJson<String>(publicId),
      'trackUri': serializer.toJson<String>(trackUri),
      'status': serializer.toJson<String>(status),
      'qualityId': serializer.toJson<String?>(qualityId),
      'filePath': serializer.toJson<String?>(filePath),
      'bytesDone': serializer.toJson<int>(bytesDone),
      'bytesTotal': serializer.toJson<int?>(bytesTotal),
      'error': serializer.toJson<String?>(error),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'completedAt': serializer.toJson<int?>(completedAt),
    };
  }

  DownloadRow copyWith({
    int? id,
    String? publicId,
    String? trackUri,
    String? status,
    Value<String?> qualityId = const Value.absent(),
    Value<String?> filePath = const Value.absent(),
    int? bytesDone,
    Value<int?> bytesTotal = const Value.absent(),
    Value<String?> error = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<int?> completedAt = const Value.absent(),
  }) => DownloadRow(
    id: id ?? this.id,
    publicId: publicId ?? this.publicId,
    trackUri: trackUri ?? this.trackUri,
    status: status ?? this.status,
    qualityId: qualityId.present ? qualityId.value : this.qualityId,
    filePath: filePath.present ? filePath.value : this.filePath,
    bytesDone: bytesDone ?? this.bytesDone,
    bytesTotal: bytesTotal.present ? bytesTotal.value : this.bytesTotal,
    error: error.present ? error.value : this.error,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  DownloadRow copyWithCompanion(DownloadsCompanion data) {
    return DownloadRow(
      id: data.id.present ? data.id.value : this.id,
      publicId: data.publicId.present ? data.publicId.value : this.publicId,
      trackUri: data.trackUri.present ? data.trackUri.value : this.trackUri,
      status: data.status.present ? data.status.value : this.status,
      qualityId: data.qualityId.present ? data.qualityId.value : this.qualityId,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      bytesDone: data.bytesDone.present ? data.bytesDone.value : this.bytesDone,
      bytesTotal: data.bytesTotal.present
          ? data.bytesTotal.value
          : this.bytesTotal,
      error: data.error.present ? data.error.value : this.error,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadRow(')
          ..write('id: $id, ')
          ..write('publicId: $publicId, ')
          ..write('trackUri: $trackUri, ')
          ..write('status: $status, ')
          ..write('qualityId: $qualityId, ')
          ..write('filePath: $filePath, ')
          ..write('bytesDone: $bytesDone, ')
          ..write('bytesTotal: $bytesTotal, ')
          ..write('error: $error, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    publicId,
    trackUri,
    status,
    qualityId,
    filePath,
    bytesDone,
    bytesTotal,
    error,
    createdAt,
    updatedAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadRow &&
          other.id == this.id &&
          other.publicId == this.publicId &&
          other.trackUri == this.trackUri &&
          other.status == this.status &&
          other.qualityId == this.qualityId &&
          other.filePath == this.filePath &&
          other.bytesDone == this.bytesDone &&
          other.bytesTotal == this.bytesTotal &&
          other.error == this.error &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.completedAt == this.completedAt);
}

class DownloadsCompanion extends UpdateCompanion<DownloadRow> {
  final Value<int> id;
  final Value<String> publicId;
  final Value<String> trackUri;
  final Value<String> status;
  final Value<String?> qualityId;
  final Value<String?> filePath;
  final Value<int> bytesDone;
  final Value<int?> bytesTotal;
  final Value<String?> error;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> completedAt;
  const DownloadsCompanion({
    this.id = const Value.absent(),
    this.publicId = const Value.absent(),
    this.trackUri = const Value.absent(),
    this.status = const Value.absent(),
    this.qualityId = const Value.absent(),
    this.filePath = const Value.absent(),
    this.bytesDone = const Value.absent(),
    this.bytesTotal = const Value.absent(),
    this.error = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
  });
  DownloadsCompanion.insert({
    this.id = const Value.absent(),
    required String publicId,
    required String trackUri,
    required String status,
    this.qualityId = const Value.absent(),
    this.filePath = const Value.absent(),
    this.bytesDone = const Value.absent(),
    this.bytesTotal = const Value.absent(),
    this.error = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.completedAt = const Value.absent(),
  }) : publicId = Value(publicId),
       trackUri = Value(trackUri),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DownloadRow> custom({
    Expression<int>? id,
    Expression<String>? publicId,
    Expression<String>? trackUri,
    Expression<String>? status,
    Expression<String>? qualityId,
    Expression<String>? filePath,
    Expression<int>? bytesDone,
    Expression<int>? bytesTotal,
    Expression<String>? error,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? completedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (publicId != null) 'public_id': publicId,
      if (trackUri != null) 'track_uri': trackUri,
      if (status != null) 'status': status,
      if (qualityId != null) 'quality_id': qualityId,
      if (filePath != null) 'file_path': filePath,
      if (bytesDone != null) 'bytes_done': bytesDone,
      if (bytesTotal != null) 'bytes_total': bytesTotal,
      if (error != null) 'error': error,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (completedAt != null) 'completed_at': completedAt,
    });
  }

  DownloadsCompanion copyWith({
    Value<int>? id,
    Value<String>? publicId,
    Value<String>? trackUri,
    Value<String>? status,
    Value<String?>? qualityId,
    Value<String?>? filePath,
    Value<int>? bytesDone,
    Value<int?>? bytesTotal,
    Value<String?>? error,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? completedAt,
  }) {
    return DownloadsCompanion(
      id: id ?? this.id,
      publicId: publicId ?? this.publicId,
      trackUri: trackUri ?? this.trackUri,
      status: status ?? this.status,
      qualityId: qualityId ?? this.qualityId,
      filePath: filePath ?? this.filePath,
      bytesDone: bytesDone ?? this.bytesDone,
      bytesTotal: bytesTotal ?? this.bytesTotal,
      error: error ?? this.error,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (publicId.present) {
      map['public_id'] = Variable<String>(publicId.value);
    }
    if (trackUri.present) {
      map['track_uri'] = Variable<String>(trackUri.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (qualityId.present) {
      map['quality_id'] = Variable<String>(qualityId.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (bytesDone.present) {
      map['bytes_done'] = Variable<int>(bytesDone.value);
    }
    if (bytesTotal.present) {
      map['bytes_total'] = Variable<int>(bytesTotal.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadsCompanion(')
          ..write('id: $id, ')
          ..write('publicId: $publicId, ')
          ..write('trackUri: $trackUri, ')
          ..write('status: $status, ')
          ..write('qualityId: $qualityId, ')
          ..write('filePath: $filePath, ')
          ..write('bytesDone: $bytesDone, ')
          ..write('bytesTotal: $bytesTotal, ')
          ..write('error: $error, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }
}

class $DownloadAssetsTable extends DownloadAssets
    with TableInfo<$DownloadAssetsTable, DownloadAssetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadAssetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _downloadIdMeta = const VerificationMeta(
    'downloadId',
  );
  @override
  late final GeneratedColumn<int> downloadId = GeneratedColumn<int>(
    'download_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    downloadId,
    kind,
    filePath,
    bytes,
    contentHash,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_assets';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadAssetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('download_id')) {
      context.handle(
        _downloadIdMeta,
        downloadId.isAcceptableOrUnknown(data['download_id']!, _downloadIdMeta),
      );
    } else if (isInserting) {
      context.missing(_downloadIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {downloadId, kind},
  ];
  @override
  DownloadAssetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadAssetRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      downloadId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}download_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DownloadAssetsTable createAlias(String alias) {
    return $DownloadAssetsTable(attachedDatabase, alias);
  }
}

class DownloadAssetRow extends DataClass
    implements Insertable<DownloadAssetRow> {
  final int id;
  final int downloadId;

  /// `audio` / `cover` / `lyric` / `translation`.
  final String kind;
  final String filePath;
  final int bytes;
  final String? contentHash;
  final int updatedAt;
  const DownloadAssetRow({
    required this.id,
    required this.downloadId,
    required this.kind,
    required this.filePath,
    required this.bytes,
    this.contentHash,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['download_id'] = Variable<int>(downloadId);
    map['kind'] = Variable<String>(kind);
    map['file_path'] = Variable<String>(filePath);
    map['bytes'] = Variable<int>(bytes);
    if (!nullToAbsent || contentHash != null) {
      map['content_hash'] = Variable<String>(contentHash);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  DownloadAssetsCompanion toCompanion(bool nullToAbsent) {
    return DownloadAssetsCompanion(
      id: Value(id),
      downloadId: Value(downloadId),
      kind: Value(kind),
      filePath: Value(filePath),
      bytes: Value(bytes),
      contentHash: contentHash == null && nullToAbsent
          ? const Value.absent()
          : Value(contentHash),
      updatedAt: Value(updatedAt),
    );
  }

  factory DownloadAssetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadAssetRow(
      id: serializer.fromJson<int>(json['id']),
      downloadId: serializer.fromJson<int>(json['downloadId']),
      kind: serializer.fromJson<String>(json['kind']),
      filePath: serializer.fromJson<String>(json['filePath']),
      bytes: serializer.fromJson<int>(json['bytes']),
      contentHash: serializer.fromJson<String?>(json['contentHash']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'downloadId': serializer.toJson<int>(downloadId),
      'kind': serializer.toJson<String>(kind),
      'filePath': serializer.toJson<String>(filePath),
      'bytes': serializer.toJson<int>(bytes),
      'contentHash': serializer.toJson<String?>(contentHash),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  DownloadAssetRow copyWith({
    int? id,
    int? downloadId,
    String? kind,
    String? filePath,
    int? bytes,
    Value<String?> contentHash = const Value.absent(),
    int? updatedAt,
  }) => DownloadAssetRow(
    id: id ?? this.id,
    downloadId: downloadId ?? this.downloadId,
    kind: kind ?? this.kind,
    filePath: filePath ?? this.filePath,
    bytes: bytes ?? this.bytes,
    contentHash: contentHash.present ? contentHash.value : this.contentHash,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DownloadAssetRow copyWithCompanion(DownloadAssetsCompanion data) {
    return DownloadAssetRow(
      id: data.id.present ? data.id.value : this.id,
      downloadId: data.downloadId.present
          ? data.downloadId.value
          : this.downloadId,
      kind: data.kind.present ? data.kind.value : this.kind,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadAssetRow(')
          ..write('id: $id, ')
          ..write('downloadId: $downloadId, ')
          ..write('kind: $kind, ')
          ..write('filePath: $filePath, ')
          ..write('bytes: $bytes, ')
          ..write('contentHash: $contentHash, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    downloadId,
    kind,
    filePath,
    bytes,
    contentHash,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadAssetRow &&
          other.id == this.id &&
          other.downloadId == this.downloadId &&
          other.kind == this.kind &&
          other.filePath == this.filePath &&
          other.bytes == this.bytes &&
          other.contentHash == this.contentHash &&
          other.updatedAt == this.updatedAt);
}

class DownloadAssetsCompanion extends UpdateCompanion<DownloadAssetRow> {
  final Value<int> id;
  final Value<int> downloadId;
  final Value<String> kind;
  final Value<String> filePath;
  final Value<int> bytes;
  final Value<String?> contentHash;
  final Value<int> updatedAt;
  const DownloadAssetsCompanion({
    this.id = const Value.absent(),
    this.downloadId = const Value.absent(),
    this.kind = const Value.absent(),
    this.filePath = const Value.absent(),
    this.bytes = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  DownloadAssetsCompanion.insert({
    this.id = const Value.absent(),
    required int downloadId,
    required String kind,
    required String filePath,
    required int bytes,
    this.contentHash = const Value.absent(),
    required int updatedAt,
  }) : downloadId = Value(downloadId),
       kind = Value(kind),
       filePath = Value(filePath),
       bytes = Value(bytes),
       updatedAt = Value(updatedAt);
  static Insertable<DownloadAssetRow> custom({
    Expression<int>? id,
    Expression<int>? downloadId,
    Expression<String>? kind,
    Expression<String>? filePath,
    Expression<int>? bytes,
    Expression<String>? contentHash,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (downloadId != null) 'download_id': downloadId,
      if (kind != null) 'kind': kind,
      if (filePath != null) 'file_path': filePath,
      if (bytes != null) 'bytes': bytes,
      if (contentHash != null) 'content_hash': contentHash,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  DownloadAssetsCompanion copyWith({
    Value<int>? id,
    Value<int>? downloadId,
    Value<String>? kind,
    Value<String>? filePath,
    Value<int>? bytes,
    Value<String?>? contentHash,
    Value<int>? updatedAt,
  }) {
    return DownloadAssetsCompanion(
      id: id ?? this.id,
      downloadId: downloadId ?? this.downloadId,
      kind: kind ?? this.kind,
      filePath: filePath ?? this.filePath,
      bytes: bytes ?? this.bytes,
      contentHash: contentHash ?? this.contentHash,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (downloadId.present) {
      map['download_id'] = Variable<int>(downloadId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<int>(bytes.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadAssetsCompanion(')
          ..write('id: $id, ')
          ..write('downloadId: $downloadId, ')
          ..write('kind: $kind, ')
          ..write('filePath: $filePath, ')
          ..write('bytes: $bytes, ')
          ..write('contentHash: $contentHash, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $PlayEventsTable extends PlayEvents
    with TableInfo<$PlayEventsTable, PlayEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _trackUriMeta = const VerificationMeta(
    'trackUri',
  );
  @override
  late final GeneratedColumn<String> trackUri = GeneratedColumn<String>(
    'track_uri',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<int> endedAt = GeneratedColumn<int>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _listenedMsMeta = const VerificationMeta(
    'listenedMs',
  );
  @override
  late final GeneratedColumn<int> listenedMs = GeneratedColumn<int>(
    'listened_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    eventId,
    trackUri,
    startedAt,
    endedAt,
    positionMs,
    listenedMs,
    durationMs,
    completed,
    sessionId,
    deviceId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'play_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlayEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('track_uri')) {
      context.handle(
        _trackUriMeta,
        trackUri.isAcceptableOrUnknown(data['track_uri']!, _trackUriMeta),
      );
    } else if (isInserting) {
      context.missing(_trackUriMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    }
    if (data.containsKey('listened_ms')) {
      context.handle(
        _listenedMsMeta,
        listenedMs.isAcceptableOrUnknown(data['listened_ms']!, _listenedMsMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlayEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlayEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      trackUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_uri'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ended_at'],
      ),
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      listenedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}listened_ms'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PlayEventsTable createAlias(String alias) {
    return $PlayEventsTable(attachedDatabase, alias);
  }
}

class PlayEventRow extends DataClass implements Insertable<PlayEventRow> {
  final int id;

  /// Stable event id for export/import and future sync.
  final String eventId;

  /// Canonical pool key (`tracks.uri`).
  final String trackUri;
  final int startedAt;
  final int? endedAt;

  /// Last known playback position at the end of the session.
  final int positionMs;

  /// Wall-clock time spent listening during this session.
  final int listenedMs;

  /// Track duration at event time, when known.
  final int? durationMs;

  /// Whether the track reached a natural end (or the configured threshold).
  final bool completed;
  final String? sessionId;
  final String? deviceId;
  final int createdAt;
  const PlayEventRow({
    required this.id,
    required this.eventId,
    required this.trackUri,
    required this.startedAt,
    this.endedAt,
    required this.positionMs,
    required this.listenedMs,
    this.durationMs,
    required this.completed,
    this.sessionId,
    this.deviceId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['event_id'] = Variable<String>(eventId);
    map['track_uri'] = Variable<String>(trackUri);
    map['started_at'] = Variable<int>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<int>(endedAt);
    }
    map['position_ms'] = Variable<int>(positionMs);
    map['listened_ms'] = Variable<int>(listenedMs);
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    map['completed'] = Variable<bool>(completed);
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<String>(sessionId);
    }
    if (!nullToAbsent || deviceId != null) {
      map['device_id'] = Variable<String>(deviceId);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  PlayEventsCompanion toCompanion(bool nullToAbsent) {
    return PlayEventsCompanion(
      id: Value(id),
      eventId: Value(eventId),
      trackUri: Value(trackUri),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      positionMs: Value(positionMs),
      listenedMs: Value(listenedMs),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      completed: Value(completed),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      deviceId: deviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceId),
      createdAt: Value(createdAt),
    );
  }

  factory PlayEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlayEventRow(
      id: serializer.fromJson<int>(json['id']),
      eventId: serializer.fromJson<String>(json['eventId']),
      trackUri: serializer.fromJson<String>(json['trackUri']),
      startedAt: serializer.fromJson<int>(json['startedAt']),
      endedAt: serializer.fromJson<int?>(json['endedAt']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      listenedMs: serializer.fromJson<int>(json['listenedMs']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      completed: serializer.fromJson<bool>(json['completed']),
      sessionId: serializer.fromJson<String?>(json['sessionId']),
      deviceId: serializer.fromJson<String?>(json['deviceId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'eventId': serializer.toJson<String>(eventId),
      'trackUri': serializer.toJson<String>(trackUri),
      'startedAt': serializer.toJson<int>(startedAt),
      'endedAt': serializer.toJson<int?>(endedAt),
      'positionMs': serializer.toJson<int>(positionMs),
      'listenedMs': serializer.toJson<int>(listenedMs),
      'durationMs': serializer.toJson<int?>(durationMs),
      'completed': serializer.toJson<bool>(completed),
      'sessionId': serializer.toJson<String?>(sessionId),
      'deviceId': serializer.toJson<String?>(deviceId),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  PlayEventRow copyWith({
    int? id,
    String? eventId,
    String? trackUri,
    int? startedAt,
    Value<int?> endedAt = const Value.absent(),
    int? positionMs,
    int? listenedMs,
    Value<int?> durationMs = const Value.absent(),
    bool? completed,
    Value<String?> sessionId = const Value.absent(),
    Value<String?> deviceId = const Value.absent(),
    int? createdAt,
  }) => PlayEventRow(
    id: id ?? this.id,
    eventId: eventId ?? this.eventId,
    trackUri: trackUri ?? this.trackUri,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    positionMs: positionMs ?? this.positionMs,
    listenedMs: listenedMs ?? this.listenedMs,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    completed: completed ?? this.completed,
    sessionId: sessionId.present ? sessionId.value : this.sessionId,
    deviceId: deviceId.present ? deviceId.value : this.deviceId,
    createdAt: createdAt ?? this.createdAt,
  );
  PlayEventRow copyWithCompanion(PlayEventsCompanion data) {
    return PlayEventRow(
      id: data.id.present ? data.id.value : this.id,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      trackUri: data.trackUri.present ? data.trackUri.value : this.trackUri,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      listenedMs: data.listenedMs.present
          ? data.listenedMs.value
          : this.listenedMs,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      completed: data.completed.present ? data.completed.value : this.completed,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlayEventRow(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('trackUri: $trackUri, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('positionMs: $positionMs, ')
          ..write('listenedMs: $listenedMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('completed: $completed, ')
          ..write('sessionId: $sessionId, ')
          ..write('deviceId: $deviceId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    eventId,
    trackUri,
    startedAt,
    endedAt,
    positionMs,
    listenedMs,
    durationMs,
    completed,
    sessionId,
    deviceId,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayEventRow &&
          other.id == this.id &&
          other.eventId == this.eventId &&
          other.trackUri == this.trackUri &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.positionMs == this.positionMs &&
          other.listenedMs == this.listenedMs &&
          other.durationMs == this.durationMs &&
          other.completed == this.completed &&
          other.sessionId == this.sessionId &&
          other.deviceId == this.deviceId &&
          other.createdAt == this.createdAt);
}

class PlayEventsCompanion extends UpdateCompanion<PlayEventRow> {
  final Value<int> id;
  final Value<String> eventId;
  final Value<String> trackUri;
  final Value<int> startedAt;
  final Value<int?> endedAt;
  final Value<int> positionMs;
  final Value<int> listenedMs;
  final Value<int?> durationMs;
  final Value<bool> completed;
  final Value<String?> sessionId;
  final Value<String?> deviceId;
  final Value<int> createdAt;
  const PlayEventsCompanion({
    this.id = const Value.absent(),
    this.eventId = const Value.absent(),
    this.trackUri = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.listenedMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.completed = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PlayEventsCompanion.insert({
    this.id = const Value.absent(),
    required String eventId,
    required String trackUri,
    required int startedAt,
    this.endedAt = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.listenedMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.completed = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.deviceId = const Value.absent(),
    required int createdAt,
  }) : eventId = Value(eventId),
       trackUri = Value(trackUri),
       startedAt = Value(startedAt),
       createdAt = Value(createdAt);
  static Insertable<PlayEventRow> custom({
    Expression<int>? id,
    Expression<String>? eventId,
    Expression<String>? trackUri,
    Expression<int>? startedAt,
    Expression<int>? endedAt,
    Expression<int>? positionMs,
    Expression<int>? listenedMs,
    Expression<int>? durationMs,
    Expression<bool>? completed,
    Expression<String>? sessionId,
    Expression<String>? deviceId,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventId != null) 'event_id': eventId,
      if (trackUri != null) 'track_uri': trackUri,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (positionMs != null) 'position_ms': positionMs,
      if (listenedMs != null) 'listened_ms': listenedMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (completed != null) 'completed': completed,
      if (sessionId != null) 'session_id': sessionId,
      if (deviceId != null) 'device_id': deviceId,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PlayEventsCompanion copyWith({
    Value<int>? id,
    Value<String>? eventId,
    Value<String>? trackUri,
    Value<int>? startedAt,
    Value<int?>? endedAt,
    Value<int>? positionMs,
    Value<int>? listenedMs,
    Value<int?>? durationMs,
    Value<bool>? completed,
    Value<String?>? sessionId,
    Value<String?>? deviceId,
    Value<int>? createdAt,
  }) {
    return PlayEventsCompanion(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      trackUri: trackUri ?? this.trackUri,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      positionMs: positionMs ?? this.positionMs,
      listenedMs: listenedMs ?? this.listenedMs,
      durationMs: durationMs ?? this.durationMs,
      completed: completed ?? this.completed,
      sessionId: sessionId ?? this.sessionId,
      deviceId: deviceId ?? this.deviceId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (trackUri.present) {
      map['track_uri'] = Variable<String>(trackUri.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<int>(endedAt.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (listenedMs.present) {
      map['listened_ms'] = Variable<int>(listenedMs.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayEventsCompanion(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('trackUri: $trackUri, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('positionMs: $positionMs, ')
          ..write('listenedMs: $listenedMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('completed: $completed, ')
          ..write('sessionId: $sessionId, ')
          ..write('deviceId: $deviceId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $TrackStatsTable extends TrackStats
    with TableInfo<$TrackStatsTable, TrackStatRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrackStatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackUriMeta = const VerificationMeta(
    'trackUri',
  );
  @override
  late final GeneratedColumn<String> trackUri = GeneratedColumn<String>(
    'track_uri',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playCountMeta = const VerificationMeta(
    'playCount',
  );
  @override
  late final GeneratedColumn<int> playCount = GeneratedColumn<int>(
    'play_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalMsMeta = const VerificationMeta(
    'totalMs',
  );
  @override
  late final GeneratedColumn<int> totalMs = GeneratedColumn<int>(
    'total_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastPlayedAtMeta = const VerificationMeta(
    'lastPlayedAt',
  );
  @override
  late final GeneratedColumn<int> lastPlayedAt = GeneratedColumn<int>(
    'last_played_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    trackUri,
    playCount,
    totalMs,
    lastPlayedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'track_stats';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrackStatRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('track_uri')) {
      context.handle(
        _trackUriMeta,
        trackUri.isAcceptableOrUnknown(data['track_uri']!, _trackUriMeta),
      );
    } else if (isInserting) {
      context.missing(_trackUriMeta);
    }
    if (data.containsKey('play_count')) {
      context.handle(
        _playCountMeta,
        playCount.isAcceptableOrUnknown(data['play_count']!, _playCountMeta),
      );
    }
    if (data.containsKey('total_ms')) {
      context.handle(
        _totalMsMeta,
        totalMs.isAcceptableOrUnknown(data['total_ms']!, _totalMsMeta),
      );
    }
    if (data.containsKey('last_played_at')) {
      context.handle(
        _lastPlayedAtMeta,
        lastPlayedAt.isAcceptableOrUnknown(
          data['last_played_at']!,
          _lastPlayedAtMeta,
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
  Set<GeneratedColumn> get $primaryKey => {trackUri};
  @override
  TrackStatRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackStatRow(
      trackUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_uri'],
      )!,
      playCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}play_count'],
      )!,
      totalMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_ms'],
      )!,
      lastPlayedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_played_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TrackStatsTable createAlias(String alias) {
    return $TrackStatsTable(attachedDatabase, alias);
  }
}

class TrackStatRow extends DataClass implements Insertable<TrackStatRow> {
  final String trackUri;
  final int playCount;
  final int totalMs;
  final int? lastPlayedAt;
  final int updatedAt;
  const TrackStatRow({
    required this.trackUri,
    required this.playCount,
    required this.totalMs,
    this.lastPlayedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_uri'] = Variable<String>(trackUri);
    map['play_count'] = Variable<int>(playCount);
    map['total_ms'] = Variable<int>(totalMs);
    if (!nullToAbsent || lastPlayedAt != null) {
      map['last_played_at'] = Variable<int>(lastPlayedAt);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  TrackStatsCompanion toCompanion(bool nullToAbsent) {
    return TrackStatsCompanion(
      trackUri: Value(trackUri),
      playCount: Value(playCount),
      totalMs: Value(totalMs),
      lastPlayedAt: lastPlayedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPlayedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TrackStatRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackStatRow(
      trackUri: serializer.fromJson<String>(json['trackUri']),
      playCount: serializer.fromJson<int>(json['playCount']),
      totalMs: serializer.fromJson<int>(json['totalMs']),
      lastPlayedAt: serializer.fromJson<int?>(json['lastPlayedAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackUri': serializer.toJson<String>(trackUri),
      'playCount': serializer.toJson<int>(playCount),
      'totalMs': serializer.toJson<int>(totalMs),
      'lastPlayedAt': serializer.toJson<int?>(lastPlayedAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  TrackStatRow copyWith({
    String? trackUri,
    int? playCount,
    int? totalMs,
    Value<int?> lastPlayedAt = const Value.absent(),
    int? updatedAt,
  }) => TrackStatRow(
    trackUri: trackUri ?? this.trackUri,
    playCount: playCount ?? this.playCount,
    totalMs: totalMs ?? this.totalMs,
    lastPlayedAt: lastPlayedAt.present ? lastPlayedAt.value : this.lastPlayedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TrackStatRow copyWithCompanion(TrackStatsCompanion data) {
    return TrackStatRow(
      trackUri: data.trackUri.present ? data.trackUri.value : this.trackUri,
      playCount: data.playCount.present ? data.playCount.value : this.playCount,
      totalMs: data.totalMs.present ? data.totalMs.value : this.totalMs,
      lastPlayedAt: data.lastPlayedAt.present
          ? data.lastPlayedAt.value
          : this.lastPlayedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackStatRow(')
          ..write('trackUri: $trackUri, ')
          ..write('playCount: $playCount, ')
          ..write('totalMs: $totalMs, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(trackUri, playCount, totalMs, lastPlayedAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackStatRow &&
          other.trackUri == this.trackUri &&
          other.playCount == this.playCount &&
          other.totalMs == this.totalMs &&
          other.lastPlayedAt == this.lastPlayedAt &&
          other.updatedAt == this.updatedAt);
}

class TrackStatsCompanion extends UpdateCompanion<TrackStatRow> {
  final Value<String> trackUri;
  final Value<int> playCount;
  final Value<int> totalMs;
  final Value<int?> lastPlayedAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const TrackStatsCompanion({
    this.trackUri = const Value.absent(),
    this.playCount = const Value.absent(),
    this.totalMs = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrackStatsCompanion.insert({
    required String trackUri,
    this.playCount = const Value.absent(),
    this.totalMs = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : trackUri = Value(trackUri),
       updatedAt = Value(updatedAt);
  static Insertable<TrackStatRow> custom({
    Expression<String>? trackUri,
    Expression<int>? playCount,
    Expression<int>? totalMs,
    Expression<int>? lastPlayedAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (trackUri != null) 'track_uri': trackUri,
      if (playCount != null) 'play_count': playCount,
      if (totalMs != null) 'total_ms': totalMs,
      if (lastPlayedAt != null) 'last_played_at': lastPlayedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrackStatsCompanion copyWith({
    Value<String>? trackUri,
    Value<int>? playCount,
    Value<int>? totalMs,
    Value<int?>? lastPlayedAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return TrackStatsCompanion(
      trackUri: trackUri ?? this.trackUri,
      playCount: playCount ?? this.playCount,
      totalMs: totalMs ?? this.totalMs,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackUri.present) {
      map['track_uri'] = Variable<String>(trackUri.value);
    }
    if (playCount.present) {
      map['play_count'] = Variable<int>(playCount.value);
    }
    if (totalMs.present) {
      map['total_ms'] = Variable<int>(totalMs.value);
    }
    if (lastPlayedAt.present) {
      map['last_played_at'] = Variable<int>(lastPlayedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackStatsCompanion(')
          ..write('trackUri: $trackUri, ')
          ..write('playCount: $playCount, ')
          ..write('totalMs: $totalMs, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DailyStatsTable extends DailyStats
    with TableInfo<$DailyStatsTable, DailyStatRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyStatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dayStartMeta = const VerificationMeta(
    'dayStart',
  );
  @override
  late final GeneratedColumn<int> dayStart = GeneratedColumn<int>(
    'day_start',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackUriMeta = const VerificationMeta(
    'trackUri',
  );
  @override
  late final GeneratedColumn<String> trackUri = GeneratedColumn<String>(
    'track_uri',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playCountMeta = const VerificationMeta(
    'playCount',
  );
  @override
  late final GeneratedColumn<int> playCount = GeneratedColumn<int>(
    'play_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalMsMeta = const VerificationMeta(
    'totalMs',
  );
  @override
  late final GeneratedColumn<int> totalMs = GeneratedColumn<int>(
    'total_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    dayStart,
    trackUri,
    playCount,
    totalMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_stats';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailyStatRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('day_start')) {
      context.handle(
        _dayStartMeta,
        dayStart.isAcceptableOrUnknown(data['day_start']!, _dayStartMeta),
      );
    } else if (isInserting) {
      context.missing(_dayStartMeta);
    }
    if (data.containsKey('track_uri')) {
      context.handle(
        _trackUriMeta,
        trackUri.isAcceptableOrUnknown(data['track_uri']!, _trackUriMeta),
      );
    } else if (isInserting) {
      context.missing(_trackUriMeta);
    }
    if (data.containsKey('play_count')) {
      context.handle(
        _playCountMeta,
        playCount.isAcceptableOrUnknown(data['play_count']!, _playCountMeta),
      );
    }
    if (data.containsKey('total_ms')) {
      context.handle(
        _totalMsMeta,
        totalMs.isAcceptableOrUnknown(data['total_ms']!, _totalMsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {dayStart, trackUri};
  @override
  DailyStatRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyStatRow(
      dayStart: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_start'],
      )!,
      trackUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_uri'],
      )!,
      playCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}play_count'],
      )!,
      totalMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_ms'],
      )!,
    );
  }

  @override
  $DailyStatsTable createAlias(String alias) {
    return $DailyStatsTable(attachedDatabase, alias);
  }
}

class DailyStatRow extends DataClass implements Insertable<DailyStatRow> {
  /// Local-day start in epoch milliseconds.
  final int dayStart;
  final String trackUri;
  final int playCount;
  final int totalMs;
  const DailyStatRow({
    required this.dayStart,
    required this.trackUri,
    required this.playCount,
    required this.totalMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['day_start'] = Variable<int>(dayStart);
    map['track_uri'] = Variable<String>(trackUri);
    map['play_count'] = Variable<int>(playCount);
    map['total_ms'] = Variable<int>(totalMs);
    return map;
  }

  DailyStatsCompanion toCompanion(bool nullToAbsent) {
    return DailyStatsCompanion(
      dayStart: Value(dayStart),
      trackUri: Value(trackUri),
      playCount: Value(playCount),
      totalMs: Value(totalMs),
    );
  }

  factory DailyStatRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyStatRow(
      dayStart: serializer.fromJson<int>(json['dayStart']),
      trackUri: serializer.fromJson<String>(json['trackUri']),
      playCount: serializer.fromJson<int>(json['playCount']),
      totalMs: serializer.fromJson<int>(json['totalMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dayStart': serializer.toJson<int>(dayStart),
      'trackUri': serializer.toJson<String>(trackUri),
      'playCount': serializer.toJson<int>(playCount),
      'totalMs': serializer.toJson<int>(totalMs),
    };
  }

  DailyStatRow copyWith({
    int? dayStart,
    String? trackUri,
    int? playCount,
    int? totalMs,
  }) => DailyStatRow(
    dayStart: dayStart ?? this.dayStart,
    trackUri: trackUri ?? this.trackUri,
    playCount: playCount ?? this.playCount,
    totalMs: totalMs ?? this.totalMs,
  );
  DailyStatRow copyWithCompanion(DailyStatsCompanion data) {
    return DailyStatRow(
      dayStart: data.dayStart.present ? data.dayStart.value : this.dayStart,
      trackUri: data.trackUri.present ? data.trackUri.value : this.trackUri,
      playCount: data.playCount.present ? data.playCount.value : this.playCount,
      totalMs: data.totalMs.present ? data.totalMs.value : this.totalMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyStatRow(')
          ..write('dayStart: $dayStart, ')
          ..write('trackUri: $trackUri, ')
          ..write('playCount: $playCount, ')
          ..write('totalMs: $totalMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(dayStart, trackUri, playCount, totalMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyStatRow &&
          other.dayStart == this.dayStart &&
          other.trackUri == this.trackUri &&
          other.playCount == this.playCount &&
          other.totalMs == this.totalMs);
}

class DailyStatsCompanion extends UpdateCompanion<DailyStatRow> {
  final Value<int> dayStart;
  final Value<String> trackUri;
  final Value<int> playCount;
  final Value<int> totalMs;
  final Value<int> rowid;
  const DailyStatsCompanion({
    this.dayStart = const Value.absent(),
    this.trackUri = const Value.absent(),
    this.playCount = const Value.absent(),
    this.totalMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DailyStatsCompanion.insert({
    required int dayStart,
    required String trackUri,
    this.playCount = const Value.absent(),
    this.totalMs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : dayStart = Value(dayStart),
       trackUri = Value(trackUri);
  static Insertable<DailyStatRow> custom({
    Expression<int>? dayStart,
    Expression<String>? trackUri,
    Expression<int>? playCount,
    Expression<int>? totalMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (dayStart != null) 'day_start': dayStart,
      if (trackUri != null) 'track_uri': trackUri,
      if (playCount != null) 'play_count': playCount,
      if (totalMs != null) 'total_ms': totalMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DailyStatsCompanion copyWith({
    Value<int>? dayStart,
    Value<String>? trackUri,
    Value<int>? playCount,
    Value<int>? totalMs,
    Value<int>? rowid,
  }) {
    return DailyStatsCompanion(
      dayStart: dayStart ?? this.dayStart,
      trackUri: trackUri ?? this.trackUri,
      playCount: playCount ?? this.playCount,
      totalMs: totalMs ?? this.totalMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dayStart.present) {
      map['day_start'] = Variable<int>(dayStart.value);
    }
    if (trackUri.present) {
      map['track_uri'] = Variable<String>(trackUri.value);
    }
    if (playCount.present) {
      map['play_count'] = Variable<int>(playCount.value);
    }
    if (totalMs.present) {
      map['total_ms'] = Variable<int>(totalMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyStatsCompanion(')
          ..write('dayStart: $dayStart, ')
          ..write('trackUri: $trackUri, ')
          ..write('playCount: $playCount, ')
          ..write('totalMs: $totalMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LyricsCacheTable extends LyricsCache
    with TableInfo<$LyricsCacheTable, LyricsCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LyricsCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackUriMeta = const VerificationMeta(
    'trackUri',
  );
  @override
  late final GeneratedColumn<String> trackUri = GeneratedColumn<String>(
    'track_uri',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _translationMeta = const VerificationMeta(
    'translation',
  );
  @override
  late final GeneratedColumn<String> translation = GeneratedColumn<String>(
    'translation',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _offsetMsMeta = const VerificationMeta(
    'offsetMs',
  );
  @override
  late final GeneratedColumn<int> offsetMs = GeneratedColumn<int>(
    'offset_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<int> fetchedAt = GeneratedColumn<int>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<int> expiresAt = GeneratedColumn<int>(
    'expires_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    trackUri,
    provider,
    format,
    content,
    translation,
    offsetMs,
    contentHash,
    fetchedAt,
    expiresAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lyrics_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<LyricsCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('track_uri')) {
      context.handle(
        _trackUriMeta,
        trackUri.isAcceptableOrUnknown(data['track_uri']!, _trackUriMeta),
      );
    } else if (isInserting) {
      context.missing(_trackUriMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('translation')) {
      context.handle(
        _translationMeta,
        translation.isAcceptableOrUnknown(
          data['translation']!,
          _translationMeta,
        ),
      );
    }
    if (data.containsKey('offset_ms')) {
      context.handle(
        _offsetMsMeta,
        offsetMs.isAcceptableOrUnknown(data['offset_ms']!, _offsetMsMeta),
      );
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trackUri, provider};
  @override
  LyricsCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LyricsCacheRow(
      trackUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_uri'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      translation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}translation'],
      ),
      offsetMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}offset_ms'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      ),
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fetched_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expires_at'],
      ),
    );
  }

  @override
  $LyricsCacheTable createAlias(String alias) {
    return $LyricsCacheTable(attachedDatabase, alias);
  }
}

class LyricsCacheRow extends DataClass implements Insertable<LyricsCacheRow> {
  final String trackUri;
  final String provider;

  /// `lrc` / `yrc` / `ass` / `json`.
  final String format;
  final String content;
  final String? translation;
  final int offsetMs;
  final String? contentHash;
  final int fetchedAt;
  final int? expiresAt;
  const LyricsCacheRow({
    required this.trackUri,
    required this.provider,
    required this.format,
    required this.content,
    this.translation,
    required this.offsetMs,
    this.contentHash,
    required this.fetchedAt,
    this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_uri'] = Variable<String>(trackUri);
    map['provider'] = Variable<String>(provider);
    map['format'] = Variable<String>(format);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || translation != null) {
      map['translation'] = Variable<String>(translation);
    }
    map['offset_ms'] = Variable<int>(offsetMs);
    if (!nullToAbsent || contentHash != null) {
      map['content_hash'] = Variable<String>(contentHash);
    }
    map['fetched_at'] = Variable<int>(fetchedAt);
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<int>(expiresAt);
    }
    return map;
  }

  LyricsCacheCompanion toCompanion(bool nullToAbsent) {
    return LyricsCacheCompanion(
      trackUri: Value(trackUri),
      provider: Value(provider),
      format: Value(format),
      content: Value(content),
      translation: translation == null && nullToAbsent
          ? const Value.absent()
          : Value(translation),
      offsetMs: Value(offsetMs),
      contentHash: contentHash == null && nullToAbsent
          ? const Value.absent()
          : Value(contentHash),
      fetchedAt: Value(fetchedAt),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
    );
  }

  factory LyricsCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LyricsCacheRow(
      trackUri: serializer.fromJson<String>(json['trackUri']),
      provider: serializer.fromJson<String>(json['provider']),
      format: serializer.fromJson<String>(json['format']),
      content: serializer.fromJson<String>(json['content']),
      translation: serializer.fromJson<String?>(json['translation']),
      offsetMs: serializer.fromJson<int>(json['offsetMs']),
      contentHash: serializer.fromJson<String?>(json['contentHash']),
      fetchedAt: serializer.fromJson<int>(json['fetchedAt']),
      expiresAt: serializer.fromJson<int?>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackUri': serializer.toJson<String>(trackUri),
      'provider': serializer.toJson<String>(provider),
      'format': serializer.toJson<String>(format),
      'content': serializer.toJson<String>(content),
      'translation': serializer.toJson<String?>(translation),
      'offsetMs': serializer.toJson<int>(offsetMs),
      'contentHash': serializer.toJson<String?>(contentHash),
      'fetchedAt': serializer.toJson<int>(fetchedAt),
      'expiresAt': serializer.toJson<int?>(expiresAt),
    };
  }

  LyricsCacheRow copyWith({
    String? trackUri,
    String? provider,
    String? format,
    String? content,
    Value<String?> translation = const Value.absent(),
    int? offsetMs,
    Value<String?> contentHash = const Value.absent(),
    int? fetchedAt,
    Value<int?> expiresAt = const Value.absent(),
  }) => LyricsCacheRow(
    trackUri: trackUri ?? this.trackUri,
    provider: provider ?? this.provider,
    format: format ?? this.format,
    content: content ?? this.content,
    translation: translation.present ? translation.value : this.translation,
    offsetMs: offsetMs ?? this.offsetMs,
    contentHash: contentHash.present ? contentHash.value : this.contentHash,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
  );
  LyricsCacheRow copyWithCompanion(LyricsCacheCompanion data) {
    return LyricsCacheRow(
      trackUri: data.trackUri.present ? data.trackUri.value : this.trackUri,
      provider: data.provider.present ? data.provider.value : this.provider,
      format: data.format.present ? data.format.value : this.format,
      content: data.content.present ? data.content.value : this.content,
      translation: data.translation.present
          ? data.translation.value
          : this.translation,
      offsetMs: data.offsetMs.present ? data.offsetMs.value : this.offsetMs,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LyricsCacheRow(')
          ..write('trackUri: $trackUri, ')
          ..write('provider: $provider, ')
          ..write('format: $format, ')
          ..write('content: $content, ')
          ..write('translation: $translation, ')
          ..write('offsetMs: $offsetMs, ')
          ..write('contentHash: $contentHash, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    trackUri,
    provider,
    format,
    content,
    translation,
    offsetMs,
    contentHash,
    fetchedAt,
    expiresAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LyricsCacheRow &&
          other.trackUri == this.trackUri &&
          other.provider == this.provider &&
          other.format == this.format &&
          other.content == this.content &&
          other.translation == this.translation &&
          other.offsetMs == this.offsetMs &&
          other.contentHash == this.contentHash &&
          other.fetchedAt == this.fetchedAt &&
          other.expiresAt == this.expiresAt);
}

class LyricsCacheCompanion extends UpdateCompanion<LyricsCacheRow> {
  final Value<String> trackUri;
  final Value<String> provider;
  final Value<String> format;
  final Value<String> content;
  final Value<String?> translation;
  final Value<int> offsetMs;
  final Value<String?> contentHash;
  final Value<int> fetchedAt;
  final Value<int?> expiresAt;
  final Value<int> rowid;
  const LyricsCacheCompanion({
    this.trackUri = const Value.absent(),
    this.provider = const Value.absent(),
    this.format = const Value.absent(),
    this.content = const Value.absent(),
    this.translation = const Value.absent(),
    this.offsetMs = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LyricsCacheCompanion.insert({
    required String trackUri,
    required String provider,
    required String format,
    required String content,
    this.translation = const Value.absent(),
    this.offsetMs = const Value.absent(),
    this.contentHash = const Value.absent(),
    required int fetchedAt,
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : trackUri = Value(trackUri),
       provider = Value(provider),
       format = Value(format),
       content = Value(content),
       fetchedAt = Value(fetchedAt);
  static Insertable<LyricsCacheRow> custom({
    Expression<String>? trackUri,
    Expression<String>? provider,
    Expression<String>? format,
    Expression<String>? content,
    Expression<String>? translation,
    Expression<int>? offsetMs,
    Expression<String>? contentHash,
    Expression<int>? fetchedAt,
    Expression<int>? expiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (trackUri != null) 'track_uri': trackUri,
      if (provider != null) 'provider': provider,
      if (format != null) 'format': format,
      if (content != null) 'content': content,
      if (translation != null) 'translation': translation,
      if (offsetMs != null) 'offset_ms': offsetMs,
      if (contentHash != null) 'content_hash': contentHash,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LyricsCacheCompanion copyWith({
    Value<String>? trackUri,
    Value<String>? provider,
    Value<String>? format,
    Value<String>? content,
    Value<String?>? translation,
    Value<int>? offsetMs,
    Value<String?>? contentHash,
    Value<int>? fetchedAt,
    Value<int?>? expiresAt,
    Value<int>? rowid,
  }) {
    return LyricsCacheCompanion(
      trackUri: trackUri ?? this.trackUri,
      provider: provider ?? this.provider,
      format: format ?? this.format,
      content: content ?? this.content,
      translation: translation ?? this.translation,
      offsetMs: offsetMs ?? this.offsetMs,
      contentHash: contentHash ?? this.contentHash,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackUri.present) {
      map['track_uri'] = Variable<String>(trackUri.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (translation.present) {
      map['translation'] = Variable<String>(translation.value);
    }
    if (offsetMs.present) {
      map['offset_ms'] = Variable<int>(offsetMs.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<int>(fetchedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<int>(expiresAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LyricsCacheCompanion(')
          ..write('trackUri: $trackUri, ')
          ..write('provider: $provider, ')
          ..write('format: $format, ')
          ..write('content: $content, ')
          ..write('translation: $translation, ')
          ..write('offsetMs: $offsetMs, ')
          ..write('contentHash: $contentHash, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TracksTable tracks = $TracksTable(this);
  late final $ScanRootsTable scanRoots = $ScanRootsTable(this);
  late final $AudioCacheTable audioCache = $AudioCacheTable(this);
  late final $CoverCacheTable coverCache = $CoverCacheTable(this);
  late final $PlaybackStatesTable playbackStates = $PlaybackStatesTable(this);
  late final $PlaylistsTable playlists = $PlaylistsTable(this);
  late final $PlaylistTracksTable playlistTracks = $PlaylistTracksTable(this);
  late final $DownloadsTable downloads = $DownloadsTable(this);
  late final $DownloadAssetsTable downloadAssets = $DownloadAssetsTable(this);
  late final $PlayEventsTable playEvents = $PlayEventsTable(this);
  late final $TrackStatsTable trackStats = $TrackStatsTable(this);
  late final $DailyStatsTable dailyStats = $DailyStatsTable(this);
  late final $LyricsCacheTable lyricsCache = $LyricsCacheTable(this);
  late final Index idxAudioCacheLru = Index(
    'idx_audio_cache_lru',
    'CREATE INDEX IF NOT EXISTS idx_audio_cache_lru ON audio_cache (pinned, last_accessed_at)',
  );
  late final Index idxAudioCacheContentHash = Index(
    'idx_audio_cache_content_hash',
    'CREATE INDEX IF NOT EXISTS idx_audio_cache_content_hash ON audio_cache (content_hash)',
  );
  late final Index idxAudioCacheFilePath = Index(
    'idx_audio_cache_file_path',
    'CREATE INDEX IF NOT EXISTS idx_audio_cache_file_path ON audio_cache (file_path)',
  );
  late final Index idxAudioCacheTrackUri = Index(
    'idx_audio_cache_track_uri',
    'CREATE INDEX IF NOT EXISTS idx_audio_cache_track_uri ON audio_cache (track_uri)',
  );
  late final Index idxCoverCacheLru = Index(
    'idx_cover_cache_lru',
    'CREATE INDEX IF NOT EXISTS idx_cover_cache_lru ON cover_cache (last_accessed_at)',
  );
  late final Index idxCoverCacheContentHash = Index(
    'idx_cover_cache_content_hash',
    'CREATE INDEX IF NOT EXISTS idx_cover_cache_content_hash ON cover_cache (content_hash)',
  );
  late final Index idxCoverCacheFilePath = Index(
    'idx_cover_cache_file_path',
    'CREATE INDEX IF NOT EXISTS idx_cover_cache_file_path ON cover_cache (file_path)',
  );
  late final Index idxPlaylistsPublicId = Index(
    'idx_playlists_public_id',
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_playlists_public_id ON playlists (public_id)',
  );
  late final Index idxPlaylistTracksOrder = Index(
    'idx_playlist_tracks_order',
    'CREATE INDEX IF NOT EXISTS idx_playlist_tracks_order ON playlist_tracks (playlist_id, added_at DESC, id DESC)',
  );
  late final Index idxPlaylistTracksPosition = Index(
    'idx_playlist_tracks_position',
    'CREATE INDEX IF NOT EXISTS idx_playlist_tracks_position ON playlist_tracks (playlist_id, position ASC, id ASC)',
  );
  late final Index idxDownloadsTrackStatus = Index(
    'idx_downloads_track_status',
    'CREATE INDEX IF NOT EXISTS idx_downloads_track_status ON downloads (track_uri, status)',
  );
  late final Index idxDownloadsStatusCreated = Index(
    'idx_downloads_status_created',
    'CREATE INDEX IF NOT EXISTS idx_downloads_status_created ON downloads (status, created_at)',
  );
  late final Index idxDownloadAssetsDownload = Index(
    'idx_download_assets_download',
    'CREATE INDEX IF NOT EXISTS idx_download_assets_download ON download_assets (download_id)',
  );
  late final Index idxPlayEventsTrackStarted = Index(
    'idx_play_events_track_started',
    'CREATE INDEX IF NOT EXISTS idx_play_events_track_started ON play_events (track_uri, started_at)',
  );
  late final Index idxPlayEventsStarted = Index(
    'idx_play_events_started',
    'CREATE INDEX IF NOT EXISTS idx_play_events_started ON play_events (started_at)',
  );
  late final Index idxTrackStatsLastPlayed = Index(
    'idx_track_stats_last_played',
    'CREATE INDEX IF NOT EXISTS idx_track_stats_last_played ON track_stats (last_played_at)',
  );
  late final Index idxDailyStatsDay = Index(
    'idx_daily_stats_day',
    'CREATE INDEX IF NOT EXISTS idx_daily_stats_day ON daily_stats (day_start)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    tracks,
    scanRoots,
    audioCache,
    coverCache,
    playbackStates,
    playlists,
    playlistTracks,
    downloads,
    downloadAssets,
    playEvents,
    trackStats,
    dailyStats,
    lyricsCache,
    idxAudioCacheLru,
    idxAudioCacheContentHash,
    idxAudioCacheFilePath,
    idxAudioCacheTrackUri,
    idxCoverCacheLru,
    idxCoverCacheContentHash,
    idxCoverCacheFilePath,
    idxPlaylistsPublicId,
    idxPlaylistTracksOrder,
    idxPlaylistTracksPosition,
    idxDownloadsTrackStatus,
    idxDownloadsStatusCreated,
    idxDownloadAssetsDownload,
    idxPlayEventsTrackStarted,
    idxPlayEventsStarted,
    idxTrackStatsLastPlayed,
    idxDailyStatsDay,
  ];
}

typedef $$TracksTableCreateCompanionBuilder = TracksCompanion Function({
  Value<int> id,
  required String source,
  required String sourceTrackId,
  required String uri,
  required String title,
  Value<String?> artist,
  Value<String?> album,
  Value<String?> albumArtist,
  Value<int?> trackNo,
  Value<int?> discNo,
  Value<int?> year,
  Value<int?> durationMs,
  Value<int?> bitrate,
  Value<int?> sampleRate,
  Value<String?> genre,
  Value<String?> coverPath,
  Value<String?> coverUrl,
  Value<int?> lastSeenAt,
  Value<int?> sizeBytes,
  Value<int?> mtimeMs,
  Value<String?> scanRoot,
  Value<int?> missingAt,
  Value<int?> deletedAt,
  required int createdAt,
  required int updatedAt,
});
typedef $$TracksTableUpdateCompanionBuilder = TracksCompanion Function({
  Value<int> id,
  Value<String> source,
  Value<String> sourceTrackId,
  Value<String> uri,
  Value<String> title,
  Value<String?> artist,
  Value<String?> album,
  Value<String?> albumArtist,
  Value<int?> trackNo,
  Value<int?> discNo,
  Value<int?> year,
  Value<int?> durationMs,
  Value<int?> bitrate,
  Value<int?> sampleRate,
  Value<String?> genre,
  Value<String?> coverPath,
  Value<String?> coverUrl,
  Value<int?> lastSeenAt,
  Value<int?> sizeBytes,
  Value<int?> mtimeMs,
  Value<String?> scanRoot,
  Value<int?> missingAt,
  Value<int?> deletedAt,
  Value<int> createdAt,
  Value<int> updatedAt,
});

class $$TracksTableFilterComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceTrackId => $composableBuilder(
    column: $table.sourceTrackId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uri => $composableBuilder(
    column: $table.uri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumArtist => $composableBuilder(
    column: $table.albumArtist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trackNo => $composableBuilder(
    column: $table.trackNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get discNo => $composableBuilder(
    column: $table.discNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bitrate => $composableBuilder(
    column: $table.bitrate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mtimeMs => $composableBuilder(
    column: $table.mtimeMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scanRoot => $composableBuilder(
    column: $table.scanRoot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get missingAt => $composableBuilder(
    column: $table.missingAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TracksTableOrderingComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceTrackId => $composableBuilder(
    column: $table.sourceTrackId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uri => $composableBuilder(
    column: $table.uri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumArtist => $composableBuilder(
    column: $table.albumArtist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trackNo => $composableBuilder(
    column: $table.trackNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get discNo => $composableBuilder(
    column: $table.discNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bitrate => $composableBuilder(
    column: $table.bitrate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mtimeMs => $composableBuilder(
    column: $table.mtimeMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scanRoot => $composableBuilder(
    column: $table.scanRoot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get missingAt => $composableBuilder(
    column: $table.missingAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TracksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get sourceTrackId => $composableBuilder(
    column: $table.sourceTrackId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get uri =>
      $composableBuilder(column: $table.uri, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<String> get albumArtist => $composableBuilder(
    column: $table.albumArtist,
    builder: (column) => column,
  );

  GeneratedColumn<int> get trackNo =>
      $composableBuilder(column: $table.trackNo, builder: (column) => column);

  GeneratedColumn<int> get discNo =>
      $composableBuilder(column: $table.discNo, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bitrate =>
      $composableBuilder(column: $table.bitrate, builder: (column) => column);

  GeneratedColumn<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<int> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<int> get mtimeMs =>
      $composableBuilder(column: $table.mtimeMs, builder: (column) => column);

  GeneratedColumn<String> get scanRoot =>
      $composableBuilder(column: $table.scanRoot, builder: (column) => column);

  GeneratedColumn<int> get missingAt =>
      $composableBuilder(column: $table.missingAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TracksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TracksTable,
          TrackRow,
          $$TracksTableFilterComposer,
          $$TracksTableOrderingComposer,
          $$TracksTableAnnotationComposer,
          $$TracksTableCreateCompanionBuilder,
          $$TracksTableUpdateCompanionBuilder,
          (TrackRow, BaseReferences<_$AppDatabase, $TracksTable, TrackRow>),
          TrackRow,
          PrefetchHooks Function()
        > {
  $$TracksTableTableManager(_$AppDatabase db, $TracksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> sourceTrackId = const Value.absent(),
                Value<String> uri = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> artist = const Value.absent(),
                Value<String?> album = const Value.absent(),
                Value<String?> albumArtist = const Value.absent(),
                Value<int?> trackNo = const Value.absent(),
                Value<int?> discNo = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<int?> bitrate = const Value.absent(),
                Value<int?> sampleRate = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<int?> lastSeenAt = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<int?> mtimeMs = const Value.absent(),
                Value<String?> scanRoot = const Value.absent(),
                Value<int?> missingAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => TracksCompanion(
                id: id,
                source: source,
                sourceTrackId: sourceTrackId,
                uri: uri,
                title: title,
                artist: artist,
                album: album,
                albumArtist: albumArtist,
                trackNo: trackNo,
                discNo: discNo,
                year: year,
                durationMs: durationMs,
                bitrate: bitrate,
                sampleRate: sampleRate,
                genre: genre,
                coverPath: coverPath,
                coverUrl: coverUrl,
                lastSeenAt: lastSeenAt,
                sizeBytes: sizeBytes,
                mtimeMs: mtimeMs,
                scanRoot: scanRoot,
                missingAt: missingAt,
                deletedAt: deletedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String source,
                required String sourceTrackId,
                required String uri,
                required String title,
                Value<String?> artist = const Value.absent(),
                Value<String?> album = const Value.absent(),
                Value<String?> albumArtist = const Value.absent(),
                Value<int?> trackNo = const Value.absent(),
                Value<int?> discNo = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<int?> bitrate = const Value.absent(),
                Value<int?> sampleRate = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<int?> lastSeenAt = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<int?> mtimeMs = const Value.absent(),
                Value<String?> scanRoot = const Value.absent(),
                Value<int?> missingAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                required int createdAt,
                required int updatedAt,
              }) => TracksCompanion.insert(
                id: id,
                source: source,
                sourceTrackId: sourceTrackId,
                uri: uri,
                title: title,
                artist: artist,
                album: album,
                albumArtist: albumArtist,
                trackNo: trackNo,
                discNo: discNo,
                year: year,
                durationMs: durationMs,
                bitrate: bitrate,
                sampleRate: sampleRate,
                genre: genre,
                coverPath: coverPath,
                coverUrl: coverUrl,
                lastSeenAt: lastSeenAt,
                sizeBytes: sizeBytes,
                mtimeMs: mtimeMs,
                scanRoot: scanRoot,
                missingAt: missingAt,
                deletedAt: deletedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TracksTable, TrackRow>(table),
                  BaseReferences<_$AppDatabase, $TracksTable, TrackRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TracksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TracksTable,
      TrackRow,
      $$TracksTableFilterComposer,
      $$TracksTableOrderingComposer,
      $$TracksTableAnnotationComposer,
      $$TracksTableCreateCompanionBuilder,
      $$TracksTableUpdateCompanionBuilder,
      (TrackRow, BaseReferences<_$AppDatabase, $TracksTable, TrackRow>),
      TrackRow,
      PrefetchHooks Function()
    >;
typedef $$ScanRootsTableCreateCompanionBuilder = ScanRootsCompanion Function({
  Value<int> id,
  required String path,
  required String kind,
  required int addedAt,
});
typedef $$ScanRootsTableUpdateCompanionBuilder = ScanRootsCompanion Function({
  Value<int> id,
  Value<String> path,
  Value<String> kind,
  Value<int> addedAt,
});

class $$ScanRootsTableFilterComposer
    extends Composer<_$AppDatabase, $ScanRootsTable> {
  $$ScanRootsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScanRootsTableOrderingComposer
    extends Composer<_$AppDatabase, $ScanRootsTable> {
  $$ScanRootsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScanRootsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScanRootsTable> {
  $$ScanRootsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$ScanRootsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScanRootsTable,
          ScanRootRow,
          $$ScanRootsTableFilterComposer,
          $$ScanRootsTableOrderingComposer,
          $$ScanRootsTableAnnotationComposer,
          $$ScanRootsTableCreateCompanionBuilder,
          $$ScanRootsTableUpdateCompanionBuilder,
          (
            ScanRootRow,
            BaseReferences<_$AppDatabase, $ScanRootsTable, ScanRootRow>,
          ),
          ScanRootRow,
          PrefetchHooks Function()
        > {
  $$ScanRootsTableTableManager(_$AppDatabase db, $ScanRootsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScanRootsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScanRootsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScanRootsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
              }) => ScanRootsCompanion(
                id: id,
                path: path,
                kind: kind,
                addedAt: addedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String path,
                required String kind,
                required int addedAt,
              }) => ScanRootsCompanion.insert(
                id: id,
                path: path,
                kind: kind,
                addedAt: addedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ScanRootsTable, ScanRootRow>(table),
                  BaseReferences<_$AppDatabase, $ScanRootsTable, ScanRootRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScanRootsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScanRootsTable,
      ScanRootRow,
      $$ScanRootsTableFilterComposer,
      $$ScanRootsTableOrderingComposer,
      $$ScanRootsTableAnnotationComposer,
      $$ScanRootsTableCreateCompanionBuilder,
      $$ScanRootsTableUpdateCompanionBuilder,
      (
        ScanRootRow,
        BaseReferences<_$AppDatabase, $ScanRootsTable, ScanRootRow>,
      ),
      ScanRootRow,
      PrefetchHooks Function()
    >;
typedef $$AudioCacheTableCreateCompanionBuilder = AudioCacheCompanion Function({
  Value<int> id,
  required String source,
  required String sourceTrackId,
  Value<String?> trackUri,
  required String filePath,
  required int bytes,
  required String qualityId,
  Value<bool> pinned,
  required int cachedAt,
  required int lastAccessedAt,
  Value<String?> contentHash,
  Value<String?> coverPath,
  Value<int> coverBytes,
});
typedef $$AudioCacheTableUpdateCompanionBuilder = AudioCacheCompanion Function({
  Value<int> id,
  Value<String> source,
  Value<String> sourceTrackId,
  Value<String?> trackUri,
  Value<String> filePath,
  Value<int> bytes,
  Value<String> qualityId,
  Value<bool> pinned,
  Value<int> cachedAt,
  Value<int> lastAccessedAt,
  Value<String?> contentHash,
  Value<String?> coverPath,
  Value<int> coverBytes,
});

class $$AudioCacheTableFilterComposer
    extends Composer<_$AppDatabase, $AudioCacheTable> {
  $$AudioCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceTrackId => $composableBuilder(
    column: $table.sourceTrackId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackUri => $composableBuilder(
    column: $table.trackUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get qualityId => $composableBuilder(
    column: $table.qualityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get coverBytes => $composableBuilder(
    column: $table.coverBytes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AudioCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $AudioCacheTable> {
  $$AudioCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceTrackId => $composableBuilder(
    column: $table.sourceTrackId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackUri => $composableBuilder(
    column: $table.trackUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get qualityId => $composableBuilder(
    column: $table.qualityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get coverBytes => $composableBuilder(
    column: $table.coverBytes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AudioCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $AudioCacheTable> {
  $$AudioCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get sourceTrackId => $composableBuilder(
    column: $table.sourceTrackId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get trackUri =>
      $composableBuilder(column: $table.trackUri, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<String> get qualityId =>
      $composableBuilder(column: $table.qualityId, builder: (column) => column);

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  GeneratedColumn<int> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  GeneratedColumn<int> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<int> get coverBytes => $composableBuilder(
    column: $table.coverBytes,
    builder: (column) => column,
  );
}

class $$AudioCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AudioCacheTable,
          AudioCacheRow,
          $$AudioCacheTableFilterComposer,
          $$AudioCacheTableOrderingComposer,
          $$AudioCacheTableAnnotationComposer,
          $$AudioCacheTableCreateCompanionBuilder,
          $$AudioCacheTableUpdateCompanionBuilder,
          (
            AudioCacheRow,
            BaseReferences<_$AppDatabase, $AudioCacheTable, AudioCacheRow>,
          ),
          AudioCacheRow,
          PrefetchHooks Function()
        > {
  $$AudioCacheTableTableManager(_$AppDatabase db, $AudioCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AudioCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AudioCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AudioCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> sourceTrackId = const Value.absent(),
                Value<String?> trackUri = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<int> bytes = const Value.absent(),
                Value<String> qualityId = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<int> cachedAt = const Value.absent(),
                Value<int> lastAccessedAt = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<int> coverBytes = const Value.absent(),
              }) => AudioCacheCompanion(
                id: id,
                source: source,
                sourceTrackId: sourceTrackId,
                trackUri: trackUri,
                filePath: filePath,
                bytes: bytes,
                qualityId: qualityId,
                pinned: pinned,
                cachedAt: cachedAt,
                lastAccessedAt: lastAccessedAt,
                contentHash: contentHash,
                coverPath: coverPath,
                coverBytes: coverBytes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String source,
                required String sourceTrackId,
                Value<String?> trackUri = const Value.absent(),
                required String filePath,
                required int bytes,
                required String qualityId,
                Value<bool> pinned = const Value.absent(),
                required int cachedAt,
                required int lastAccessedAt,
                Value<String?> contentHash = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<int> coverBytes = const Value.absent(),
              }) => AudioCacheCompanion.insert(
                id: id,
                source: source,
                sourceTrackId: sourceTrackId,
                trackUri: trackUri,
                filePath: filePath,
                bytes: bytes,
                qualityId: qualityId,
                pinned: pinned,
                cachedAt: cachedAt,
                lastAccessedAt: lastAccessedAt,
                contentHash: contentHash,
                coverPath: coverPath,
                coverBytes: coverBytes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AudioCacheTable, AudioCacheRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $AudioCacheTable,
                    AudioCacheRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AudioCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AudioCacheTable,
      AudioCacheRow,
      $$AudioCacheTableFilterComposer,
      $$AudioCacheTableOrderingComposer,
      $$AudioCacheTableAnnotationComposer,
      $$AudioCacheTableCreateCompanionBuilder,
      $$AudioCacheTableUpdateCompanionBuilder,
      (
        AudioCacheRow,
        BaseReferences<_$AppDatabase, $AudioCacheTable, AudioCacheRow>,
      ),
      AudioCacheRow,
      PrefetchHooks Function()
    >;
typedef $$CoverCacheTableCreateCompanionBuilder = CoverCacheCompanion Function({
  Value<int> id,
  required String urlHash,
  required String filePath,
  required String contentHash,
  required int bytes,
  required int cachedAt,
  required int lastAccessedAt,
});
typedef $$CoverCacheTableUpdateCompanionBuilder = CoverCacheCompanion Function({
  Value<int> id,
  Value<String> urlHash,
  Value<String> filePath,
  Value<String> contentHash,
  Value<int> bytes,
  Value<int> cachedAt,
  Value<int> lastAccessedAt,
});

class $$CoverCacheTableFilterComposer
    extends Composer<_$AppDatabase, $CoverCacheTable> {
  $$CoverCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get urlHash => $composableBuilder(
    column: $table.urlHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CoverCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $CoverCacheTable> {
  $$CoverCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get urlHash => $composableBuilder(
    column: $table.urlHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CoverCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $CoverCacheTable> {
  $$CoverCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get urlHash =>
      $composableBuilder(column: $table.urlHash, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<int> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  GeneratedColumn<int> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => column,
  );
}

class $$CoverCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CoverCacheTable,
          CoverCacheRow,
          $$CoverCacheTableFilterComposer,
          $$CoverCacheTableOrderingComposer,
          $$CoverCacheTableAnnotationComposer,
          $$CoverCacheTableCreateCompanionBuilder,
          $$CoverCacheTableUpdateCompanionBuilder,
          (
            CoverCacheRow,
            BaseReferences<_$AppDatabase, $CoverCacheTable, CoverCacheRow>,
          ),
          CoverCacheRow,
          PrefetchHooks Function()
        > {
  $$CoverCacheTableTableManager(_$AppDatabase db, $CoverCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CoverCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CoverCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CoverCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> urlHash = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<int> bytes = const Value.absent(),
                Value<int> cachedAt = const Value.absent(),
                Value<int> lastAccessedAt = const Value.absent(),
              }) => CoverCacheCompanion(
                id: id,
                urlHash: urlHash,
                filePath: filePath,
                contentHash: contentHash,
                bytes: bytes,
                cachedAt: cachedAt,
                lastAccessedAt: lastAccessedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String urlHash,
                required String filePath,
                required String contentHash,
                required int bytes,
                required int cachedAt,
                required int lastAccessedAt,
              }) => CoverCacheCompanion.insert(
                id: id,
                urlHash: urlHash,
                filePath: filePath,
                contentHash: contentHash,
                bytes: bytes,
                cachedAt: cachedAt,
                lastAccessedAt: lastAccessedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CoverCacheTable, CoverCacheRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CoverCacheTable,
                    CoverCacheRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CoverCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CoverCacheTable,
      CoverCacheRow,
      $$CoverCacheTableFilterComposer,
      $$CoverCacheTableOrderingComposer,
      $$CoverCacheTableAnnotationComposer,
      $$CoverCacheTableCreateCompanionBuilder,
      $$CoverCacheTableUpdateCompanionBuilder,
      (
        CoverCacheRow,
        BaseReferences<_$AppDatabase, $CoverCacheTable, CoverCacheRow>,
      ),
      CoverCacheRow,
      PrefetchHooks Function()
    >;
typedef $$PlaybackStatesTableCreateCompanionBuilder =
    PlaybackStatesCompanion Function({
      Value<int> id,
      required String queueJson,
      required int currentIndex,
      required int positionMs,
      required String repeatMode,
      required bool shuffleEnabled,
      required int updatedAt,
    });
typedef $$PlaybackStatesTableUpdateCompanionBuilder =
    PlaybackStatesCompanion Function({
      Value<int> id,
      Value<String> queueJson,
      Value<int> currentIndex,
      Value<int> positionMs,
      Value<String> repeatMode,
      Value<bool> shuffleEnabled,
      Value<int> updatedAt,
    });

class $$PlaybackStatesTableFilterComposer
    extends Composer<_$AppDatabase, $PlaybackStatesTable> {
  $$PlaybackStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get queueJson => $composableBuilder(
    column: $table.queueJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentIndex => $composableBuilder(
    column: $table.currentIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repeatMode => $composableBuilder(
    column: $table.repeatMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get shuffleEnabled => $composableBuilder(
    column: $table.shuffleEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlaybackStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaybackStatesTable> {
  $$PlaybackStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get queueJson => $composableBuilder(
    column: $table.queueJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentIndex => $composableBuilder(
    column: $table.currentIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repeatMode => $composableBuilder(
    column: $table.repeatMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get shuffleEnabled => $composableBuilder(
    column: $table.shuffleEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaybackStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaybackStatesTable> {
  $$PlaybackStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get queueJson =>
      $composableBuilder(column: $table.queueJson, builder: (column) => column);

  GeneratedColumn<int> get currentIndex => $composableBuilder(
    column: $table.currentIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get repeatMode => $composableBuilder(
    column: $table.repeatMode,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get shuffleEnabled => $composableBuilder(
    column: $table.shuffleEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PlaybackStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaybackStatesTable,
          PlaybackStateRow,
          $$PlaybackStatesTableFilterComposer,
          $$PlaybackStatesTableOrderingComposer,
          $$PlaybackStatesTableAnnotationComposer,
          $$PlaybackStatesTableCreateCompanionBuilder,
          $$PlaybackStatesTableUpdateCompanionBuilder,
          (
            PlaybackStateRow,
            BaseReferences<
              _$AppDatabase,
              $PlaybackStatesTable,
              PlaybackStateRow
            >,
          ),
          PlaybackStateRow,
          PrefetchHooks Function()
        > {
  $$PlaybackStatesTableTableManager(
    _$AppDatabase db,
    $PlaybackStatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaybackStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaybackStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> queueJson = const Value.absent(),
                Value<int> currentIndex = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<String> repeatMode = const Value.absent(),
                Value<bool> shuffleEnabled = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => PlaybackStatesCompanion(
                id: id,
                queueJson: queueJson,
                currentIndex: currentIndex,
                positionMs: positionMs,
                repeatMode: repeatMode,
                shuffleEnabled: shuffleEnabled,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String queueJson,
                required int currentIndex,
                required int positionMs,
                required String repeatMode,
                required bool shuffleEnabled,
                required int updatedAt,
              }) => PlaybackStatesCompanion.insert(
                id: id,
                queueJson: queueJson,
                currentIndex: currentIndex,
                positionMs: positionMs,
                repeatMode: repeatMode,
                shuffleEnabled: shuffleEnabled,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaybackStatesTable, PlaybackStateRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PlaybackStatesTable,
                    PlaybackStateRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlaybackStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaybackStatesTable,
      PlaybackStateRow,
      $$PlaybackStatesTableFilterComposer,
      $$PlaybackStatesTableOrderingComposer,
      $$PlaybackStatesTableAnnotationComposer,
      $$PlaybackStatesTableCreateCompanionBuilder,
      $$PlaybackStatesTableUpdateCompanionBuilder,
      (
        PlaybackStateRow,
        BaseReferences<_$AppDatabase, $PlaybackStatesTable, PlaybackStateRow>,
      ),
      PlaybackStateRow,
      PrefetchHooks Function()
    >;
typedef $$PlaylistsTableCreateCompanionBuilder = PlaylistsCompanion Function({
  Value<int> id,
  Value<String?> publicId,
  required String name,
  required String kind,
  Value<String?> description,
  Value<String?> coverPath,
  Value<String?> coverUrl,
  required int createdAt,
  required int updatedAt,
});
typedef $$PlaylistsTableUpdateCompanionBuilder = PlaylistsCompanion Function({
  Value<int> id,
  Value<String?> publicId,
  Value<String> name,
  Value<String> kind,
  Value<String?> description,
  Value<String?> coverPath,
  Value<String?> coverUrl,
  Value<int> createdAt,
  Value<int> updatedAt,
});

class $$PlaylistsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publicId => $composableBuilder(
    column: $table.publicId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlaylistsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publicId => $composableBuilder(
    column: $table.publicId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaylistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get publicId =>
      $composableBuilder(column: $table.publicId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PlaylistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaylistsTable,
          PlaylistRow,
          $$PlaylistsTableFilterComposer,
          $$PlaylistsTableOrderingComposer,
          $$PlaylistsTableAnnotationComposer,
          $$PlaylistsTableCreateCompanionBuilder,
          $$PlaylistsTableUpdateCompanionBuilder,
          (
            PlaylistRow,
            BaseReferences<_$AppDatabase, $PlaylistsTable, PlaylistRow>,
          ),
          PlaylistRow,
          PrefetchHooks Function()
        > {
  $$PlaylistsTableTableManager(_$AppDatabase db, $PlaylistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> publicId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => PlaylistsCompanion(
                id: id,
                publicId: publicId,
                name: name,
                kind: kind,
                description: description,
                coverPath: coverPath,
                coverUrl: coverUrl,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> publicId = const Value.absent(),
                required String name,
                required String kind,
                Value<String?> description = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                required int createdAt,
                required int updatedAt,
              }) => PlaylistsCompanion.insert(
                id: id,
                publicId: publicId,
                name: name,
                kind: kind,
                description: description,
                coverPath: coverPath,
                coverUrl: coverUrl,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistsTable, PlaylistRow>(table),
                  BaseReferences<_$AppDatabase, $PlaylistsTable, PlaylistRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlaylistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaylistsTable,
      PlaylistRow,
      $$PlaylistsTableFilterComposer,
      $$PlaylistsTableOrderingComposer,
      $$PlaylistsTableAnnotationComposer,
      $$PlaylistsTableCreateCompanionBuilder,
      $$PlaylistsTableUpdateCompanionBuilder,
      (
        PlaylistRow,
        BaseReferences<_$AppDatabase, $PlaylistsTable, PlaylistRow>,
      ),
      PlaylistRow,
      PrefetchHooks Function()
    >;
typedef $$PlaylistTracksTableCreateCompanionBuilder =
    PlaylistTracksCompanion Function({
      Value<int> id,
      required int playlistId,
      required String uri,
      required int addedAt,
      Value<int> position,
      Value<int> updatedAt,
      Value<int?> deletedAt,
    });
typedef $$PlaylistTracksTableUpdateCompanionBuilder =
    PlaylistTracksCompanion Function({
      Value<int> id,
      Value<int> playlistId,
      Value<String> uri,
      Value<int> addedAt,
      Value<int> position,
      Value<int> updatedAt,
      Value<int?> deletedAt,
    });

class $$PlaylistTracksTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistTracksTable> {
  $$PlaylistTracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uri => $composableBuilder(
    column: $table.uri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlaylistTracksTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistTracksTable> {
  $$PlaylistTracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uri => $composableBuilder(
    column: $table.uri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaylistTracksTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistTracksTable> {
  $$PlaylistTracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get uri =>
      $composableBuilder(column: $table.uri, builder: (column) => column);

  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$PlaylistTracksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaylistTracksTable,
          PlaylistTrackRow,
          $$PlaylistTracksTableFilterComposer,
          $$PlaylistTracksTableOrderingComposer,
          $$PlaylistTracksTableAnnotationComposer,
          $$PlaylistTracksTableCreateCompanionBuilder,
          $$PlaylistTracksTableUpdateCompanionBuilder,
          (
            PlaylistTrackRow,
            BaseReferences<
              _$AppDatabase,
              $PlaylistTracksTable,
              PlaylistTrackRow
            >,
          ),
          PlaylistTrackRow,
          PrefetchHooks Function()
        > {
  $$PlaylistTracksTableTableManager(
    _$AppDatabase db,
    $PlaylistTracksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistTracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistTracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistTracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> playlistId = const Value.absent(),
                Value<String> uri = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
              }) => PlaylistTracksCompanion(
                id: id,
                playlistId: playlistId,
                uri: uri,
                addedAt: addedAt,
                position: position,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int playlistId,
                required String uri,
                required int addedAt,
                Value<int> position = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
              }) => PlaylistTracksCompanion.insert(
                id: id,
                playlistId: playlistId,
                uri: uri,
                addedAt: addedAt,
                position: position,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistTracksTable, PlaylistTrackRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PlaylistTracksTable,
                    PlaylistTrackRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlaylistTracksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaylistTracksTable,
      PlaylistTrackRow,
      $$PlaylistTracksTableFilterComposer,
      $$PlaylistTracksTableOrderingComposer,
      $$PlaylistTracksTableAnnotationComposer,
      $$PlaylistTracksTableCreateCompanionBuilder,
      $$PlaylistTracksTableUpdateCompanionBuilder,
      (
        PlaylistTrackRow,
        BaseReferences<_$AppDatabase, $PlaylistTracksTable, PlaylistTrackRow>,
      ),
      PlaylistTrackRow,
      PrefetchHooks Function()
    >;
typedef $$DownloadsTableCreateCompanionBuilder = DownloadsCompanion Function({
  Value<int> id,
  required String publicId,
  required String trackUri,
  required String status,
  Value<String?> qualityId,
  Value<String?> filePath,
  Value<int> bytesDone,
  Value<int?> bytesTotal,
  Value<String?> error,
  required int createdAt,
  required int updatedAt,
  Value<int?> completedAt,
});
typedef $$DownloadsTableUpdateCompanionBuilder = DownloadsCompanion Function({
  Value<int> id,
  Value<String> publicId,
  Value<String> trackUri,
  Value<String> status,
  Value<String?> qualityId,
  Value<String?> filePath,
  Value<int> bytesDone,
  Value<int?> bytesTotal,
  Value<String?> error,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> completedAt,
});

class $$DownloadsTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publicId => $composableBuilder(
    column: $table.publicId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackUri => $composableBuilder(
    column: $table.trackUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get qualityId => $composableBuilder(
    column: $table.qualityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytesDone => $composableBuilder(
    column: $table.bytesDone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytesTotal => $composableBuilder(
    column: $table.bytesTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadsTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publicId => $composableBuilder(
    column: $table.publicId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackUri => $composableBuilder(
    column: $table.trackUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get qualityId => $composableBuilder(
    column: $table.qualityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytesDone => $composableBuilder(
    column: $table.bytesDone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytesTotal => $composableBuilder(
    column: $table.bytesTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get publicId =>
      $composableBuilder(column: $table.publicId, builder: (column) => column);

  GeneratedColumn<String> get trackUri =>
      $composableBuilder(column: $table.trackUri, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get qualityId =>
      $composableBuilder(column: $table.qualityId, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get bytesDone =>
      $composableBuilder(column: $table.bytesDone, builder: (column) => column);

  GeneratedColumn<int> get bytesTotal => $composableBuilder(
    column: $table.bytesTotal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$DownloadsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadsTable,
          DownloadRow,
          $$DownloadsTableFilterComposer,
          $$DownloadsTableOrderingComposer,
          $$DownloadsTableAnnotationComposer,
          $$DownloadsTableCreateCompanionBuilder,
          $$DownloadsTableUpdateCompanionBuilder,
          (
            DownloadRow,
            BaseReferences<_$AppDatabase, $DownloadsTable, DownloadRow>,
          ),
          DownloadRow,
          PrefetchHooks Function()
        > {
  $$DownloadsTableTableManager(_$AppDatabase db, $DownloadsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> publicId = const Value.absent(),
                Value<String> trackUri = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> qualityId = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<int> bytesDone = const Value.absent(),
                Value<int?> bytesTotal = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
              }) => DownloadsCompanion(
                id: id,
                publicId: publicId,
                trackUri: trackUri,
                status: status,
                qualityId: qualityId,
                filePath: filePath,
                bytesDone: bytesDone,
                bytesTotal: bytesTotal,
                error: error,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String publicId,
                required String trackUri,
                required String status,
                Value<String?> qualityId = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<int> bytesDone = const Value.absent(),
                Value<int?> bytesTotal = const Value.absent(),
                Value<String?> error = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> completedAt = const Value.absent(),
              }) => DownloadsCompanion.insert(
                id: id,
                publicId: publicId,
                trackUri: trackUri,
                status: status,
                qualityId: qualityId,
                filePath: filePath,
                bytesDone: bytesDone,
                bytesTotal: bytesTotal,
                error: error,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DownloadsTable, DownloadRow>(table),
                  BaseReferences<_$AppDatabase, $DownloadsTable, DownloadRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadsTable,
      DownloadRow,
      $$DownloadsTableFilterComposer,
      $$DownloadsTableOrderingComposer,
      $$DownloadsTableAnnotationComposer,
      $$DownloadsTableCreateCompanionBuilder,
      $$DownloadsTableUpdateCompanionBuilder,
      (
        DownloadRow,
        BaseReferences<_$AppDatabase, $DownloadsTable, DownloadRow>,
      ),
      DownloadRow,
      PrefetchHooks Function()
    >;
typedef $$DownloadAssetsTableCreateCompanionBuilder =
    DownloadAssetsCompanion Function({
      Value<int> id,
      required int downloadId,
      required String kind,
      required String filePath,
      required int bytes,
      Value<String?> contentHash,
      required int updatedAt,
    });
typedef $$DownloadAssetsTableUpdateCompanionBuilder =
    DownloadAssetsCompanion Function({
      Value<int> id,
      Value<int> downloadId,
      Value<String> kind,
      Value<String> filePath,
      Value<int> bytes,
      Value<String?> contentHash,
      Value<int> updatedAt,
    });

class $$DownloadAssetsTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadAssetsTable> {
  $$DownloadAssetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get downloadId => $composableBuilder(
    column: $table.downloadId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadAssetsTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadAssetsTable> {
  $$DownloadAssetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadId => $composableBuilder(
    column: $table.downloadId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadAssetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadAssetsTable> {
  $$DownloadAssetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get downloadId => $composableBuilder(
    column: $table.downloadId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DownloadAssetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadAssetsTable,
          DownloadAssetRow,
          $$DownloadAssetsTableFilterComposer,
          $$DownloadAssetsTableOrderingComposer,
          $$DownloadAssetsTableAnnotationComposer,
          $$DownloadAssetsTableCreateCompanionBuilder,
          $$DownloadAssetsTableUpdateCompanionBuilder,
          (
            DownloadAssetRow,
            BaseReferences<
              _$AppDatabase,
              $DownloadAssetsTable,
              DownloadAssetRow
            >,
          ),
          DownloadAssetRow,
          PrefetchHooks Function()
        > {
  $$DownloadAssetsTableTableManager(
    _$AppDatabase db,
    $DownloadAssetsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadAssetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadAssetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadAssetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> downloadId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<int> bytes = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => DownloadAssetsCompanion(
                id: id,
                downloadId: downloadId,
                kind: kind,
                filePath: filePath,
                bytes: bytes,
                contentHash: contentHash,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int downloadId,
                required String kind,
                required String filePath,
                required int bytes,
                Value<String?> contentHash = const Value.absent(),
                required int updatedAt,
              }) => DownloadAssetsCompanion.insert(
                id: id,
                downloadId: downloadId,
                kind: kind,
                filePath: filePath,
                bytes: bytes,
                contentHash: contentHash,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DownloadAssetsTable, DownloadAssetRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $DownloadAssetsTable,
                    DownloadAssetRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadAssetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadAssetsTable,
      DownloadAssetRow,
      $$DownloadAssetsTableFilterComposer,
      $$DownloadAssetsTableOrderingComposer,
      $$DownloadAssetsTableAnnotationComposer,
      $$DownloadAssetsTableCreateCompanionBuilder,
      $$DownloadAssetsTableUpdateCompanionBuilder,
      (
        DownloadAssetRow,
        BaseReferences<_$AppDatabase, $DownloadAssetsTable, DownloadAssetRow>,
      ),
      DownloadAssetRow,
      PrefetchHooks Function()
    >;
typedef $$PlayEventsTableCreateCompanionBuilder = PlayEventsCompanion Function({
  Value<int> id,
  required String eventId,
  required String trackUri,
  required int startedAt,
  Value<int?> endedAt,
  Value<int> positionMs,
  Value<int> listenedMs,
  Value<int?> durationMs,
  Value<bool> completed,
  Value<String?> sessionId,
  Value<String?> deviceId,
  required int createdAt,
});
typedef $$PlayEventsTableUpdateCompanionBuilder = PlayEventsCompanion Function({
  Value<int> id,
  Value<String> eventId,
  Value<String> trackUri,
  Value<int> startedAt,
  Value<int?> endedAt,
  Value<int> positionMs,
  Value<int> listenedMs,
  Value<int?> durationMs,
  Value<bool> completed,
  Value<String?> sessionId,
  Value<String?> deviceId,
  Value<int> createdAt,
});

class $$PlayEventsTableFilterComposer
    extends Composer<_$AppDatabase, $PlayEventsTable> {
  $$PlayEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackUri => $composableBuilder(
    column: $table.trackUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get listenedMs => $composableBuilder(
    column: $table.listenedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlayEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlayEventsTable> {
  $$PlayEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackUri => $composableBuilder(
    column: $table.trackUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get listenedMs => $composableBuilder(
    column: $table.listenedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlayEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlayEventsTable> {
  $$PlayEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get trackUri =>
      $composableBuilder(column: $table.trackUri, builder: (column) => column);

  GeneratedColumn<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get listenedMs => $composableBuilder(
    column: $table.listenedMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PlayEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlayEventsTable,
          PlayEventRow,
          $$PlayEventsTableFilterComposer,
          $$PlayEventsTableOrderingComposer,
          $$PlayEventsTableAnnotationComposer,
          $$PlayEventsTableCreateCompanionBuilder,
          $$PlayEventsTableUpdateCompanionBuilder,
          (
            PlayEventRow,
            BaseReferences<_$AppDatabase, $PlayEventsTable, PlayEventRow>,
          ),
          PlayEventRow,
          PrefetchHooks Function()
        > {
  $$PlayEventsTableTableManager(_$AppDatabase db, $PlayEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlayEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlayEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlayEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> eventId = const Value.absent(),
                Value<String> trackUri = const Value.absent(),
                Value<int> startedAt = const Value.absent(),
                Value<int?> endedAt = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int> listenedMs = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<String?> sessionId = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
              }) => PlayEventsCompanion(
                id: id,
                eventId: eventId,
                trackUri: trackUri,
                startedAt: startedAt,
                endedAt: endedAt,
                positionMs: positionMs,
                listenedMs: listenedMs,
                durationMs: durationMs,
                completed: completed,
                sessionId: sessionId,
                deviceId: deviceId,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String eventId,
                required String trackUri,
                required int startedAt,
                Value<int?> endedAt = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int> listenedMs = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<String?> sessionId = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                required int createdAt,
              }) => PlayEventsCompanion.insert(
                id: id,
                eventId: eventId,
                trackUri: trackUri,
                startedAt: startedAt,
                endedAt: endedAt,
                positionMs: positionMs,
                listenedMs: listenedMs,
                durationMs: durationMs,
                completed: completed,
                sessionId: sessionId,
                deviceId: deviceId,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlayEventsTable, PlayEventRow>(table),
                  BaseReferences<_$AppDatabase, $PlayEventsTable, PlayEventRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlayEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlayEventsTable,
      PlayEventRow,
      $$PlayEventsTableFilterComposer,
      $$PlayEventsTableOrderingComposer,
      $$PlayEventsTableAnnotationComposer,
      $$PlayEventsTableCreateCompanionBuilder,
      $$PlayEventsTableUpdateCompanionBuilder,
      (
        PlayEventRow,
        BaseReferences<_$AppDatabase, $PlayEventsTable, PlayEventRow>,
      ),
      PlayEventRow,
      PrefetchHooks Function()
    >;
typedef $$TrackStatsTableCreateCompanionBuilder = TrackStatsCompanion Function({
  required String trackUri,
  Value<int> playCount,
  Value<int> totalMs,
  Value<int?> lastPlayedAt,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$TrackStatsTableUpdateCompanionBuilder = TrackStatsCompanion Function({
  Value<String> trackUri,
  Value<int> playCount,
  Value<int> totalMs,
  Value<int?> lastPlayedAt,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$TrackStatsTableFilterComposer
    extends Composer<_$AppDatabase, $TrackStatsTable> {
  $$TrackStatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get trackUri => $composableBuilder(
    column: $table.trackUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playCount => $composableBuilder(
    column: $table.playCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalMs => $composableBuilder(
    column: $table.totalMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TrackStatsTableOrderingComposer
    extends Composer<_$AppDatabase, $TrackStatsTable> {
  $$TrackStatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get trackUri => $composableBuilder(
    column: $table.trackUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playCount => $composableBuilder(
    column: $table.playCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalMs => $composableBuilder(
    column: $table.totalMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TrackStatsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrackStatsTable> {
  $$TrackStatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get trackUri =>
      $composableBuilder(column: $table.trackUri, builder: (column) => column);

  GeneratedColumn<int> get playCount =>
      $composableBuilder(column: $table.playCount, builder: (column) => column);

  GeneratedColumn<int> get totalMs =>
      $composableBuilder(column: $table.totalMs, builder: (column) => column);

  GeneratedColumn<int> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TrackStatsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TrackStatsTable,
          TrackStatRow,
          $$TrackStatsTableFilterComposer,
          $$TrackStatsTableOrderingComposer,
          $$TrackStatsTableAnnotationComposer,
          $$TrackStatsTableCreateCompanionBuilder,
          $$TrackStatsTableUpdateCompanionBuilder,
          (
            TrackStatRow,
            BaseReferences<_$AppDatabase, $TrackStatsTable, TrackStatRow>,
          ),
          TrackStatRow,
          PrefetchHooks Function()
        > {
  $$TrackStatsTableTableManager(_$AppDatabase db, $TrackStatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrackStatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrackStatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrackStatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> trackUri = const Value.absent(),
                Value<int> playCount = const Value.absent(),
                Value<int> totalMs = const Value.absent(),
                Value<int?> lastPlayedAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrackStatsCompanion(
                trackUri: trackUri,
                playCount: playCount,
                totalMs: totalMs,
                lastPlayedAt: lastPlayedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String trackUri,
                Value<int> playCount = const Value.absent(),
                Value<int> totalMs = const Value.absent(),
                Value<int?> lastPlayedAt = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TrackStatsCompanion.insert(
                trackUri: trackUri,
                playCount: playCount,
                totalMs: totalMs,
                lastPlayedAt: lastPlayedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TrackStatsTable, TrackStatRow>(table),
                  BaseReferences<_$AppDatabase, $TrackStatsTable, TrackStatRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TrackStatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TrackStatsTable,
      TrackStatRow,
      $$TrackStatsTableFilterComposer,
      $$TrackStatsTableOrderingComposer,
      $$TrackStatsTableAnnotationComposer,
      $$TrackStatsTableCreateCompanionBuilder,
      $$TrackStatsTableUpdateCompanionBuilder,
      (
        TrackStatRow,
        BaseReferences<_$AppDatabase, $TrackStatsTable, TrackStatRow>,
      ),
      TrackStatRow,
      PrefetchHooks Function()
    >;
typedef $$DailyStatsTableCreateCompanionBuilder = DailyStatsCompanion Function({
  required int dayStart,
  required String trackUri,
  Value<int> playCount,
  Value<int> totalMs,
  Value<int> rowid,
});
typedef $$DailyStatsTableUpdateCompanionBuilder = DailyStatsCompanion Function({
  Value<int> dayStart,
  Value<String> trackUri,
  Value<int> playCount,
  Value<int> totalMs,
  Value<int> rowid,
});

class $$DailyStatsTableFilterComposer
    extends Composer<_$AppDatabase, $DailyStatsTable> {
  $$DailyStatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get dayStart => $composableBuilder(
    column: $table.dayStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackUri => $composableBuilder(
    column: $table.trackUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playCount => $composableBuilder(
    column: $table.playCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalMs => $composableBuilder(
    column: $table.totalMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DailyStatsTableOrderingComposer
    extends Composer<_$AppDatabase, $DailyStatsTable> {
  $$DailyStatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get dayStart => $composableBuilder(
    column: $table.dayStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackUri => $composableBuilder(
    column: $table.trackUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playCount => $composableBuilder(
    column: $table.playCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalMs => $composableBuilder(
    column: $table.totalMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DailyStatsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailyStatsTable> {
  $$DailyStatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get dayStart =>
      $composableBuilder(column: $table.dayStart, builder: (column) => column);

  GeneratedColumn<String> get trackUri =>
      $composableBuilder(column: $table.trackUri, builder: (column) => column);

  GeneratedColumn<int> get playCount =>
      $composableBuilder(column: $table.playCount, builder: (column) => column);

  GeneratedColumn<int> get totalMs =>
      $composableBuilder(column: $table.totalMs, builder: (column) => column);
}

class $$DailyStatsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailyStatsTable,
          DailyStatRow,
          $$DailyStatsTableFilterComposer,
          $$DailyStatsTableOrderingComposer,
          $$DailyStatsTableAnnotationComposer,
          $$DailyStatsTableCreateCompanionBuilder,
          $$DailyStatsTableUpdateCompanionBuilder,
          (
            DailyStatRow,
            BaseReferences<_$AppDatabase, $DailyStatsTable, DailyStatRow>,
          ),
          DailyStatRow,
          PrefetchHooks Function()
        > {
  $$DailyStatsTableTableManager(_$AppDatabase db, $DailyStatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyStatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyStatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailyStatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> dayStart = const Value.absent(),
                Value<String> trackUri = const Value.absent(),
                Value<int> playCount = const Value.absent(),
                Value<int> totalMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyStatsCompanion(
                dayStart: dayStart,
                trackUri: trackUri,
                playCount: playCount,
                totalMs: totalMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int dayStart,
                required String trackUri,
                Value<int> playCount = const Value.absent(),
                Value<int> totalMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyStatsCompanion.insert(
                dayStart: dayStart,
                trackUri: trackUri,
                playCount: playCount,
                totalMs: totalMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DailyStatsTable, DailyStatRow>(table),
                  BaseReferences<_$AppDatabase, $DailyStatsTable, DailyStatRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DailyStatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailyStatsTable,
      DailyStatRow,
      $$DailyStatsTableFilterComposer,
      $$DailyStatsTableOrderingComposer,
      $$DailyStatsTableAnnotationComposer,
      $$DailyStatsTableCreateCompanionBuilder,
      $$DailyStatsTableUpdateCompanionBuilder,
      (
        DailyStatRow,
        BaseReferences<_$AppDatabase, $DailyStatsTable, DailyStatRow>,
      ),
      DailyStatRow,
      PrefetchHooks Function()
    >;
typedef $$LyricsCacheTableCreateCompanionBuilder =
    LyricsCacheCompanion Function({
      required String trackUri,
      required String provider,
      required String format,
      required String content,
      Value<String?> translation,
      Value<int> offsetMs,
      Value<String?> contentHash,
      required int fetchedAt,
      Value<int?> expiresAt,
      Value<int> rowid,
    });
typedef $$LyricsCacheTableUpdateCompanionBuilder =
    LyricsCacheCompanion Function({
      Value<String> trackUri,
      Value<String> provider,
      Value<String> format,
      Value<String> content,
      Value<String?> translation,
      Value<int> offsetMs,
      Value<String?> contentHash,
      Value<int> fetchedAt,
      Value<int?> expiresAt,
      Value<int> rowid,
    });

class $$LyricsCacheTableFilterComposer
    extends Composer<_$AppDatabase, $LyricsCacheTable> {
  $$LyricsCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get trackUri => $composableBuilder(
    column: $table.trackUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get offsetMs => $composableBuilder(
    column: $table.offsetMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LyricsCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $LyricsCacheTable> {
  $$LyricsCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get trackUri => $composableBuilder(
    column: $table.trackUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get offsetMs => $composableBuilder(
    column: $table.offsetMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LyricsCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $LyricsCacheTable> {
  $$LyricsCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get trackUri =>
      $composableBuilder(column: $table.trackUri, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => column,
  );

  GeneratedColumn<int> get offsetMs =>
      $composableBuilder(column: $table.offsetMs, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  GeneratedColumn<int> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$LyricsCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LyricsCacheTable,
          LyricsCacheRow,
          $$LyricsCacheTableFilterComposer,
          $$LyricsCacheTableOrderingComposer,
          $$LyricsCacheTableAnnotationComposer,
          $$LyricsCacheTableCreateCompanionBuilder,
          $$LyricsCacheTableUpdateCompanionBuilder,
          (
            LyricsCacheRow,
            BaseReferences<_$AppDatabase, $LyricsCacheTable, LyricsCacheRow>,
          ),
          LyricsCacheRow,
          PrefetchHooks Function()
        > {
  $$LyricsCacheTableTableManager(_$AppDatabase db, $LyricsCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LyricsCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LyricsCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LyricsCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> trackUri = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String?> translation = const Value.absent(),
                Value<int> offsetMs = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
                Value<int> fetchedAt = const Value.absent(),
                Value<int?> expiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LyricsCacheCompanion(
                trackUri: trackUri,
                provider: provider,
                format: format,
                content: content,
                translation: translation,
                offsetMs: offsetMs,
                contentHash: contentHash,
                fetchedAt: fetchedAt,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String trackUri,
                required String provider,
                required String format,
                required String content,
                Value<String?> translation = const Value.absent(),
                Value<int> offsetMs = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
                required int fetchedAt,
                Value<int?> expiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LyricsCacheCompanion.insert(
                trackUri: trackUri,
                provider: provider,
                format: format,
                content: content,
                translation: translation,
                offsetMs: offsetMs,
                contentHash: contentHash,
                fetchedAt: fetchedAt,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LyricsCacheTable, LyricsCacheRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LyricsCacheTable,
                    LyricsCacheRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LyricsCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LyricsCacheTable,
      LyricsCacheRow,
      $$LyricsCacheTableFilterComposer,
      $$LyricsCacheTableOrderingComposer,
      $$LyricsCacheTableAnnotationComposer,
      $$LyricsCacheTableCreateCompanionBuilder,
      $$LyricsCacheTableUpdateCompanionBuilder,
      (
        LyricsCacheRow,
        BaseReferences<_$AppDatabase, $LyricsCacheTable, LyricsCacheRow>,
      ),
      LyricsCacheRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TracksTableTableManager get tracks =>
      $$TracksTableTableManager(_db, _db.tracks);
  $$ScanRootsTableTableManager get scanRoots =>
      $$ScanRootsTableTableManager(_db, _db.scanRoots);
  $$AudioCacheTableTableManager get audioCache =>
      $$AudioCacheTableTableManager(_db, _db.audioCache);
  $$CoverCacheTableTableManager get coverCache =>
      $$CoverCacheTableTableManager(_db, _db.coverCache);
  $$PlaybackStatesTableTableManager get playbackStates =>
      $$PlaybackStatesTableTableManager(_db, _db.playbackStates);
  $$PlaylistsTableTableManager get playlists =>
      $$PlaylistsTableTableManager(_db, _db.playlists);
  $$PlaylistTracksTableTableManager get playlistTracks =>
      $$PlaylistTracksTableTableManager(_db, _db.playlistTracks);
  $$DownloadsTableTableManager get downloads =>
      $$DownloadsTableTableManager(_db, _db.downloads);
  $$DownloadAssetsTableTableManager get downloadAssets =>
      $$DownloadAssetsTableTableManager(_db, _db.downloadAssets);
  $$PlayEventsTableTableManager get playEvents =>
      $$PlayEventsTableTableManager(_db, _db.playEvents);
  $$TrackStatsTableTableManager get trackStats =>
      $$TrackStatsTableTableManager(_db, _db.trackStats);
  $$DailyStatsTableTableManager get dailyStats =>
      $$DailyStatsTableTableManager(_db, _db.dailyStats);
  $$LyricsCacheTableTableManager get lyricsCache =>
      $$LyricsCacheTableTableManager(_db, _db.lyricsCache);
}
