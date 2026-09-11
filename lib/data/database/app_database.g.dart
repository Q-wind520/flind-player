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
    lastSeenAt,
    sizeBytes,
    mtimeMs,
    scanRoot,
    missingAt,
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
    this.lastSeenAt,
    this.sizeBytes,
    this.mtimeMs,
    this.scanRoot,
    this.missingAt,
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
      lastSeenAt: serializer.fromJson<int?>(json['lastSeenAt']),
      sizeBytes: serializer.fromJson<int?>(json['sizeBytes']),
      mtimeMs: serializer.fromJson<int?>(json['mtimeMs']),
      scanRoot: serializer.fromJson<String?>(json['scanRoot']),
      missingAt: serializer.fromJson<int?>(json['missingAt']),
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
      'lastSeenAt': serializer.toJson<int?>(lastSeenAt),
      'sizeBytes': serializer.toJson<int?>(sizeBytes),
      'mtimeMs': serializer.toJson<int?>(mtimeMs),
      'scanRoot': serializer.toJson<String?>(scanRoot),
      'missingAt': serializer.toJson<int?>(missingAt),
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
    Value<int?> lastSeenAt = const Value.absent(),
    Value<int?> sizeBytes = const Value.absent(),
    Value<int?> mtimeMs = const Value.absent(),
    Value<String?> scanRoot = const Value.absent(),
    Value<int?> missingAt = const Value.absent(),
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
    lastSeenAt: lastSeenAt.present ? lastSeenAt.value : this.lastSeenAt,
    sizeBytes: sizeBytes.present ? sizeBytes.value : this.sizeBytes,
    mtimeMs: mtimeMs.present ? mtimeMs.value : this.mtimeMs,
    scanRoot: scanRoot.present ? scanRoot.value : this.scanRoot,
    missingAt: missingAt.present ? missingAt.value : this.missingAt,
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
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      mtimeMs: data.mtimeMs.present ? data.mtimeMs.value : this.mtimeMs,
      scanRoot: data.scanRoot.present ? data.scanRoot.value : this.scanRoot,
      missingAt: data.missingAt.present ? data.missingAt.value : this.missingAt,
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
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('mtimeMs: $mtimeMs, ')
          ..write('scanRoot: $scanRoot, ')
          ..write('missingAt: $missingAt, ')
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
    lastSeenAt,
    sizeBytes,
    mtimeMs,
    scanRoot,
    missingAt,
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
          other.lastSeenAt == this.lastSeenAt &&
          other.sizeBytes == this.sizeBytes &&
          other.mtimeMs == this.mtimeMs &&
          other.scanRoot == this.scanRoot &&
          other.missingAt == this.missingAt &&
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
  final Value<int?> lastSeenAt;
  final Value<int?> sizeBytes;
  final Value<int?> mtimeMs;
  final Value<String?> scanRoot;
  final Value<int?> missingAt;
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
    this.lastSeenAt = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.mtimeMs = const Value.absent(),
    this.scanRoot = const Value.absent(),
    this.missingAt = const Value.absent(),
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
    this.lastSeenAt = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.mtimeMs = const Value.absent(),
    this.scanRoot = const Value.absent(),
    this.missingAt = const Value.absent(),
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
    Expression<int>? lastSeenAt,
    Expression<int>? sizeBytes,
    Expression<int>? mtimeMs,
    Expression<String>? scanRoot,
    Expression<int>? missingAt,
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
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (mtimeMs != null) 'mtime_ms': mtimeMs,
      if (scanRoot != null) 'scan_root': scanRoot,
      if (missingAt != null) 'missing_at': missingAt,
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
    Value<int?>? lastSeenAt,
    Value<int?>? sizeBytes,
    Value<int?>? mtimeMs,
    Value<String?>? scanRoot,
    Value<int?>? missingAt,
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
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      mtimeMs: mtimeMs ?? this.mtimeMs,
      scanRoot: scanRoot ?? this.scanRoot,
      missingAt: missingAt ?? this.missingAt,
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
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('mtimeMs: $mtimeMs, ')
          ..write('scanRoot: $scanRoot, ')
          ..write('missingAt: $missingAt, ')
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

class $ScanStateTable extends ScanState
    with TableInfo<$ScanStateTable, ScanStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScanStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scan_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScanStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  ScanStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScanStateRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
    );
  }

  @override
  $ScanStateTable createAlias(String alias) {
    return $ScanStateTable(attachedDatabase, alias);
  }
}

class ScanStateRow extends DataClass implements Insertable<ScanStateRow> {
  final String key;
  final String? value;
  const ScanStateRow({required this.key, this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    return map;
  }

  ScanStateCompanion toCompanion(bool nullToAbsent) {
    return ScanStateCompanion(
      key: Value(key),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
    );
  }

  factory ScanStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScanStateRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String?>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String?>(value),
    };
  }

  ScanStateRow copyWith({
    String? key,
    Value<String?> value = const Value.absent(),
  }) => ScanStateRow(
    key: key ?? this.key,
    value: value.present ? value.value : this.value,
  );
  ScanStateRow copyWithCompanion(ScanStateCompanion data) {
    return ScanStateRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScanStateRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScanStateRow &&
          other.key == this.key &&
          other.value == this.value);
}

class ScanStateCompanion extends UpdateCompanion<ScanStateRow> {
  final Value<String> key;
  final Value<String?> value;
  final Value<int> rowid;
  const ScanStateCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScanStateCompanion.insert({
    required String key,
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<ScanStateRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScanStateCompanion copyWith({
    Value<String>? key,
    Value<String?>? value,
    Value<int>? rowid,
  }) {
    return ScanStateCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScanStateCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    source,
    sourceTrackId,
    filePath,
    bytes,
    qualityId,
    pinned,
    cachedAt,
    lastAccessedAt,
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
  const AudioCacheRow({
    required this.id,
    required this.source,
    required this.sourceTrackId,
    required this.filePath,
    required this.bytes,
    required this.qualityId,
    required this.pinned,
    required this.cachedAt,
    required this.lastAccessedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source'] = Variable<String>(source);
    map['source_track_id'] = Variable<String>(sourceTrackId);
    map['file_path'] = Variable<String>(filePath);
    map['bytes'] = Variable<int>(bytes);
    map['quality_id'] = Variable<String>(qualityId);
    map['pinned'] = Variable<bool>(pinned);
    map['cached_at'] = Variable<int>(cachedAt);
    map['last_accessed_at'] = Variable<int>(lastAccessedAt);
    return map;
  }

  AudioCacheCompanion toCompanion(bool nullToAbsent) {
    return AudioCacheCompanion(
      id: Value(id),
      source: Value(source),
      sourceTrackId: Value(sourceTrackId),
      filePath: Value(filePath),
      bytes: Value(bytes),
      qualityId: Value(qualityId),
      pinned: Value(pinned),
      cachedAt: Value(cachedAt),
      lastAccessedAt: Value(lastAccessedAt),
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
      filePath: serializer.fromJson<String>(json['filePath']),
      bytes: serializer.fromJson<int>(json['bytes']),
      qualityId: serializer.fromJson<String>(json['qualityId']),
      pinned: serializer.fromJson<bool>(json['pinned']),
      cachedAt: serializer.fromJson<int>(json['cachedAt']),
      lastAccessedAt: serializer.fromJson<int>(json['lastAccessedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'source': serializer.toJson<String>(source),
      'sourceTrackId': serializer.toJson<String>(sourceTrackId),
      'filePath': serializer.toJson<String>(filePath),
      'bytes': serializer.toJson<int>(bytes),
      'qualityId': serializer.toJson<String>(qualityId),
      'pinned': serializer.toJson<bool>(pinned),
      'cachedAt': serializer.toJson<int>(cachedAt),
      'lastAccessedAt': serializer.toJson<int>(lastAccessedAt),
    };
  }

  AudioCacheRow copyWith({
    int? id,
    String? source,
    String? sourceTrackId,
    String? filePath,
    int? bytes,
    String? qualityId,
    bool? pinned,
    int? cachedAt,
    int? lastAccessedAt,
  }) => AudioCacheRow(
    id: id ?? this.id,
    source: source ?? this.source,
    sourceTrackId: sourceTrackId ?? this.sourceTrackId,
    filePath: filePath ?? this.filePath,
    bytes: bytes ?? this.bytes,
    qualityId: qualityId ?? this.qualityId,
    pinned: pinned ?? this.pinned,
    cachedAt: cachedAt ?? this.cachedAt,
    lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
  );
  AudioCacheRow copyWithCompanion(AudioCacheCompanion data) {
    return AudioCacheRow(
      id: data.id.present ? data.id.value : this.id,
      source: data.source.present ? data.source.value : this.source,
      sourceTrackId: data.sourceTrackId.present
          ? data.sourceTrackId.value
          : this.sourceTrackId,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      qualityId: data.qualityId.present ? data.qualityId.value : this.qualityId,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
      lastAccessedAt: data.lastAccessedAt.present
          ? data.lastAccessedAt.value
          : this.lastAccessedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AudioCacheRow(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('sourceTrackId: $sourceTrackId, ')
          ..write('filePath: $filePath, ')
          ..write('bytes: $bytes, ')
          ..write('qualityId: $qualityId, ')
          ..write('pinned: $pinned, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('lastAccessedAt: $lastAccessedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    source,
    sourceTrackId,
    filePath,
    bytes,
    qualityId,
    pinned,
    cachedAt,
    lastAccessedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AudioCacheRow &&
          other.id == this.id &&
          other.source == this.source &&
          other.sourceTrackId == this.sourceTrackId &&
          other.filePath == this.filePath &&
          other.bytes == this.bytes &&
          other.qualityId == this.qualityId &&
          other.pinned == this.pinned &&
          other.cachedAt == this.cachedAt &&
          other.lastAccessedAt == this.lastAccessedAt);
}

class AudioCacheCompanion extends UpdateCompanion<AudioCacheRow> {
  final Value<int> id;
  final Value<String> source;
  final Value<String> sourceTrackId;
  final Value<String> filePath;
  final Value<int> bytes;
  final Value<String> qualityId;
  final Value<bool> pinned;
  final Value<int> cachedAt;
  final Value<int> lastAccessedAt;
  const AudioCacheCompanion({
    this.id = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceTrackId = const Value.absent(),
    this.filePath = const Value.absent(),
    this.bytes = const Value.absent(),
    this.qualityId = const Value.absent(),
    this.pinned = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.lastAccessedAt = const Value.absent(),
  });
  AudioCacheCompanion.insert({
    this.id = const Value.absent(),
    required String source,
    required String sourceTrackId,
    required String filePath,
    required int bytes,
    required String qualityId,
    this.pinned = const Value.absent(),
    required int cachedAt,
    required int lastAccessedAt,
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
    Expression<String>? filePath,
    Expression<int>? bytes,
    Expression<String>? qualityId,
    Expression<bool>? pinned,
    Expression<int>? cachedAt,
    Expression<int>? lastAccessedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (source != null) 'source': source,
      if (sourceTrackId != null) 'source_track_id': sourceTrackId,
      if (filePath != null) 'file_path': filePath,
      if (bytes != null) 'bytes': bytes,
      if (qualityId != null) 'quality_id': qualityId,
      if (pinned != null) 'pinned': pinned,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (lastAccessedAt != null) 'last_accessed_at': lastAccessedAt,
    });
  }

  AudioCacheCompanion copyWith({
    Value<int>? id,
    Value<String>? source,
    Value<String>? sourceTrackId,
    Value<String>? filePath,
    Value<int>? bytes,
    Value<String>? qualityId,
    Value<bool>? pinned,
    Value<int>? cachedAt,
    Value<int>? lastAccessedAt,
  }) {
    return AudioCacheCompanion(
      id: id ?? this.id,
      source: source ?? this.source,
      sourceTrackId: sourceTrackId ?? this.sourceTrackId,
      filePath: filePath ?? this.filePath,
      bytes: bytes ?? this.bytes,
      qualityId: qualityId ?? this.qualityId,
      pinned: pinned ?? this.pinned,
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
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (sourceTrackId.present) {
      map['source_track_id'] = Variable<String>(sourceTrackId.value);
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AudioCacheCompanion(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('sourceTrackId: $sourceTrackId, ')
          ..write('filePath: $filePath, ')
          ..write('bytes: $bytes, ')
          ..write('qualityId: $qualityId, ')
          ..write('pinned: $pinned, ')
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

class $FavoritesTable extends Favorites
    with TableInfo<$FavoritesTable, FavoriteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoritesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _favoritedAtMeta = const VerificationMeta(
    'favoritedAt',
  );
  @override
  late final GeneratedColumn<int> favoritedAt = GeneratedColumn<int>(
    'favorited_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uri,
    source,
    sourceTrackId,
    title,
    artist,
    album,
    durationMs,
    coverPath,
    favoritedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorites';
  @override
  VerificationContext validateIntegrity(
    Insertable<FavoriteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uri')) {
      context.handle(
        _uriMeta,
        uri.isAcceptableOrUnknown(data['uri']!, _uriMeta),
      );
    } else if (isInserting) {
      context.missing(_uriMeta);
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
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('favorited_at')) {
      context.handle(
        _favoritedAtMeta,
        favoritedAt.isAcceptableOrUnknown(
          data['favorited_at']!,
          _favoritedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_favoritedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FavoriteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoriteRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uri'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      sourceTrackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_track_id'],
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
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      favoritedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}favorited_at'],
      )!,
    );
  }

  @override
  $FavoritesTable createAlias(String alias) {
    return $FavoritesTable(attachedDatabase, alias);
  }
}

class FavoriteRow extends DataClass implements Insertable<FavoriteRow> {
  final int id;

  /// Canonical source-namespaced key; the upsert conflict target.
  final String uri;

  /// Source identifier, e.g. `local` or `bilibili`.
  final String source;

  /// Source-specific identity (absolute path, or `bvid:cid`).
  final String sourceTrackId;
  final String title;
  final String? artist;
  final String? album;
  final int? durationMs;
  final String? coverPath;

  /// Unix timestamp when the track was favourited; the ordering key.
  final int favoritedAt;
  const FavoriteRow({
    required this.id,
    required this.uri,
    required this.source,
    required this.sourceTrackId,
    required this.title,
    this.artist,
    this.album,
    this.durationMs,
    this.coverPath,
    required this.favoritedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uri'] = Variable<String>(uri);
    map['source'] = Variable<String>(source);
    map['source_track_id'] = Variable<String>(sourceTrackId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || artist != null) {
      map['artist'] = Variable<String>(artist);
    }
    if (!nullToAbsent || album != null) {
      map['album'] = Variable<String>(album);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    map['favorited_at'] = Variable<int>(favoritedAt);
    return map;
  }

  FavoritesCompanion toCompanion(bool nullToAbsent) {
    return FavoritesCompanion(
      id: Value(id),
      uri: Value(uri),
      source: Value(source),
      sourceTrackId: Value(sourceTrackId),
      title: Value(title),
      artist: artist == null && nullToAbsent
          ? const Value.absent()
          : Value(artist),
      album: album == null && nullToAbsent
          ? const Value.absent()
          : Value(album),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      coverPath: coverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverPath),
      favoritedAt: Value(favoritedAt),
    );
  }

  factory FavoriteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoriteRow(
      id: serializer.fromJson<int>(json['id']),
      uri: serializer.fromJson<String>(json['uri']),
      source: serializer.fromJson<String>(json['source']),
      sourceTrackId: serializer.fromJson<String>(json['sourceTrackId']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String?>(json['artist']),
      album: serializer.fromJson<String?>(json['album']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      favoritedAt: serializer.fromJson<int>(json['favoritedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uri': serializer.toJson<String>(uri),
      'source': serializer.toJson<String>(source),
      'sourceTrackId': serializer.toJson<String>(sourceTrackId),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String?>(artist),
      'album': serializer.toJson<String?>(album),
      'durationMs': serializer.toJson<int?>(durationMs),
      'coverPath': serializer.toJson<String?>(coverPath),
      'favoritedAt': serializer.toJson<int>(favoritedAt),
    };
  }

  FavoriteRow copyWith({
    int? id,
    String? uri,
    String? source,
    String? sourceTrackId,
    String? title,
    Value<String?> artist = const Value.absent(),
    Value<String?> album = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    Value<String?> coverPath = const Value.absent(),
    int? favoritedAt,
  }) => FavoriteRow(
    id: id ?? this.id,
    uri: uri ?? this.uri,
    source: source ?? this.source,
    sourceTrackId: sourceTrackId ?? this.sourceTrackId,
    title: title ?? this.title,
    artist: artist.present ? artist.value : this.artist,
    album: album.present ? album.value : this.album,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    favoritedAt: favoritedAt ?? this.favoritedAt,
  );
  FavoriteRow copyWithCompanion(FavoritesCompanion data) {
    return FavoriteRow(
      id: data.id.present ? data.id.value : this.id,
      uri: data.uri.present ? data.uri.value : this.uri,
      source: data.source.present ? data.source.value : this.source,
      sourceTrackId: data.sourceTrackId.present
          ? data.sourceTrackId.value
          : this.sourceTrackId,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      album: data.album.present ? data.album.value : this.album,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      favoritedAt: data.favoritedAt.present
          ? data.favoritedAt.value
          : this.favoritedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteRow(')
          ..write('id: $id, ')
          ..write('uri: $uri, ')
          ..write('source: $source, ')
          ..write('sourceTrackId: $sourceTrackId, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('durationMs: $durationMs, ')
          ..write('coverPath: $coverPath, ')
          ..write('favoritedAt: $favoritedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uri,
    source,
    sourceTrackId,
    title,
    artist,
    album,
    durationMs,
    coverPath,
    favoritedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoriteRow &&
          other.id == this.id &&
          other.uri == this.uri &&
          other.source == this.source &&
          other.sourceTrackId == this.sourceTrackId &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.album == this.album &&
          other.durationMs == this.durationMs &&
          other.coverPath == this.coverPath &&
          other.favoritedAt == this.favoritedAt);
}

class FavoritesCompanion extends UpdateCompanion<FavoriteRow> {
  final Value<int> id;
  final Value<String> uri;
  final Value<String> source;
  final Value<String> sourceTrackId;
  final Value<String> title;
  final Value<String?> artist;
  final Value<String?> album;
  final Value<int?> durationMs;
  final Value<String?> coverPath;
  final Value<int> favoritedAt;
  const FavoritesCompanion({
    this.id = const Value.absent(),
    this.uri = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceTrackId = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.favoritedAt = const Value.absent(),
  });
  FavoritesCompanion.insert({
    this.id = const Value.absent(),
    required String uri,
    required String source,
    required String sourceTrackId,
    required String title,
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.coverPath = const Value.absent(),
    required int favoritedAt,
  }) : uri = Value(uri),
       source = Value(source),
       sourceTrackId = Value(sourceTrackId),
       title = Value(title),
       favoritedAt = Value(favoritedAt);
  static Insertable<FavoriteRow> custom({
    Expression<int>? id,
    Expression<String>? uri,
    Expression<String>? source,
    Expression<String>? sourceTrackId,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? album,
    Expression<int>? durationMs,
    Expression<String>? coverPath,
    Expression<int>? favoritedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uri != null) 'uri': uri,
      if (source != null) 'source': source,
      if (sourceTrackId != null) 'source_track_id': sourceTrackId,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (durationMs != null) 'duration_ms': durationMs,
      if (coverPath != null) 'cover_path': coverPath,
      if (favoritedAt != null) 'favorited_at': favoritedAt,
    });
  }

  FavoritesCompanion copyWith({
    Value<int>? id,
    Value<String>? uri,
    Value<String>? source,
    Value<String>? sourceTrackId,
    Value<String>? title,
    Value<String?>? artist,
    Value<String?>? album,
    Value<int?>? durationMs,
    Value<String?>? coverPath,
    Value<int>? favoritedAt,
  }) {
    return FavoritesCompanion(
      id: id ?? this.id,
      uri: uri ?? this.uri,
      source: source ?? this.source,
      sourceTrackId: sourceTrackId ?? this.sourceTrackId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      durationMs: durationMs ?? this.durationMs,
      coverPath: coverPath ?? this.coverPath,
      favoritedAt: favoritedAt ?? this.favoritedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uri.present) {
      map['uri'] = Variable<String>(uri.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (sourceTrackId.present) {
      map['source_track_id'] = Variable<String>(sourceTrackId.value);
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
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (favoritedAt.present) {
      map['favorited_at'] = Variable<int>(favoritedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoritesCompanion(')
          ..write('id: $id, ')
          ..write('uri: $uri, ')
          ..write('source: $source, ')
          ..write('sourceTrackId: $sourceTrackId, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('durationMs: $durationMs, ')
          ..write('coverPath: $coverPath, ')
          ..write('favoritedAt: $favoritedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TracksTable tracks = $TracksTable(this);
  late final $ScanRootsTable scanRoots = $ScanRootsTable(this);
  late final $ScanStateTable scanState = $ScanStateTable(this);
  late final $AudioCacheTable audioCache = $AudioCacheTable(this);
  late final $PlaybackStatesTable playbackStates = $PlaybackStatesTable(this);
  late final $FavoritesTable favorites = $FavoritesTable(this);
  late final Index idxAudioCacheLru = Index(
    'idx_audio_cache_lru',
    'CREATE INDEX IF NOT EXISTS idx_audio_cache_lru ON audio_cache (pinned, last_accessed_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    tracks,
    scanRoots,
    scanState,
    audioCache,
    playbackStates,
    favorites,
    idxAudioCacheLru,
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
  Value<int?> lastSeenAt,
  Value<int?> sizeBytes,
  Value<int?> mtimeMs,
  Value<String?> scanRoot,
  Value<int?> missingAt,
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
  Value<int?> lastSeenAt,
  Value<int?> sizeBytes,
  Value<int?> mtimeMs,
  Value<String?> scanRoot,
  Value<int?> missingAt,
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
                Value<int?> lastSeenAt = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<int?> mtimeMs = const Value.absent(),
                Value<String?> scanRoot = const Value.absent(),
                Value<int?> missingAt = const Value.absent(),
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
                lastSeenAt: lastSeenAt,
                sizeBytes: sizeBytes,
                mtimeMs: mtimeMs,
                scanRoot: scanRoot,
                missingAt: missingAt,
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
                Value<int?> lastSeenAt = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<int?> mtimeMs = const Value.absent(),
                Value<String?> scanRoot = const Value.absent(),
                Value<int?> missingAt = const Value.absent(),
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
                lastSeenAt: lastSeenAt,
                sizeBytes: sizeBytes,
                mtimeMs: mtimeMs,
                scanRoot: scanRoot,
                missingAt: missingAt,
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
typedef $$ScanStateTableCreateCompanionBuilder = ScanStateCompanion Function({
  required String key,
  Value<String?> value,
  Value<int> rowid,
});
typedef $$ScanStateTableUpdateCompanionBuilder = ScanStateCompanion Function({
  Value<String> key,
  Value<String?> value,
  Value<int> rowid,
});

class $$ScanStateTableFilterComposer
    extends Composer<_$AppDatabase, $ScanStateTable> {
  $$ScanStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScanStateTableOrderingComposer
    extends Composer<_$AppDatabase, $ScanStateTable> {
  $$ScanStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScanStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScanStateTable> {
  $$ScanStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$ScanStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScanStateTable,
          ScanStateRow,
          $$ScanStateTableFilterComposer,
          $$ScanStateTableOrderingComposer,
          $$ScanStateTableAnnotationComposer,
          $$ScanStateTableCreateCompanionBuilder,
          $$ScanStateTableUpdateCompanionBuilder,
          (
            ScanStateRow,
            BaseReferences<_$AppDatabase, $ScanStateTable, ScanStateRow>,
          ),
          ScanStateRow,
          PrefetchHooks Function()
        > {
  $$ScanStateTableTableManager(_$AppDatabase db, $ScanStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScanStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScanStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScanStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String?> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => ScanStateCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            Value<String?> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => ScanStateCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ScanStateTable, ScanStateRow>(table),
                  BaseReferences<_$AppDatabase, $ScanStateTable, ScanStateRow>(
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

typedef $$ScanStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScanStateTable,
      ScanStateRow,
      $$ScanStateTableFilterComposer,
      $$ScanStateTableOrderingComposer,
      $$ScanStateTableAnnotationComposer,
      $$ScanStateTableCreateCompanionBuilder,
      $$ScanStateTableUpdateCompanionBuilder,
      (
        ScanStateRow,
        BaseReferences<_$AppDatabase, $ScanStateTable, ScanStateRow>,
      ),
      ScanStateRow,
      PrefetchHooks Function()
    >;
typedef $$AudioCacheTableCreateCompanionBuilder = AudioCacheCompanion Function({
  Value<int> id,
  required String source,
  required String sourceTrackId,
  required String filePath,
  required int bytes,
  required String qualityId,
  Value<bool> pinned,
  required int cachedAt,
  required int lastAccessedAt,
});
typedef $$AudioCacheTableUpdateCompanionBuilder = AudioCacheCompanion Function({
  Value<int> id,
  Value<String> source,
  Value<String> sourceTrackId,
  Value<String> filePath,
  Value<int> bytes,
  Value<String> qualityId,
  Value<bool> pinned,
  Value<int> cachedAt,
  Value<int> lastAccessedAt,
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
                Value<String> filePath = const Value.absent(),
                Value<int> bytes = const Value.absent(),
                Value<String> qualityId = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<int> cachedAt = const Value.absent(),
                Value<int> lastAccessedAt = const Value.absent(),
              }) => AudioCacheCompanion(
                id: id,
                source: source,
                sourceTrackId: sourceTrackId,
                filePath: filePath,
                bytes: bytes,
                qualityId: qualityId,
                pinned: pinned,
                cachedAt: cachedAt,
                lastAccessedAt: lastAccessedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String source,
                required String sourceTrackId,
                required String filePath,
                required int bytes,
                required String qualityId,
                Value<bool> pinned = const Value.absent(),
                required int cachedAt,
                required int lastAccessedAt,
              }) => AudioCacheCompanion.insert(
                id: id,
                source: source,
                sourceTrackId: sourceTrackId,
                filePath: filePath,
                bytes: bytes,
                qualityId: qualityId,
                pinned: pinned,
                cachedAt: cachedAt,
                lastAccessedAt: lastAccessedAt,
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
typedef $$FavoritesTableCreateCompanionBuilder = FavoritesCompanion Function({
  Value<int> id,
  required String uri,
  required String source,
  required String sourceTrackId,
  required String title,
  Value<String?> artist,
  Value<String?> album,
  Value<int?> durationMs,
  Value<String?> coverPath,
  required int favoritedAt,
});
typedef $$FavoritesTableUpdateCompanionBuilder = FavoritesCompanion Function({
  Value<int> id,
  Value<String> uri,
  Value<String> source,
  Value<String> sourceTrackId,
  Value<String> title,
  Value<String?> artist,
  Value<String?> album,
  Value<int?> durationMs,
  Value<String?> coverPath,
  Value<int> favoritedAt,
});

class $$FavoritesTableFilterComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableFilterComposer({
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

  ColumnFilters<String> get uri => $composableBuilder(
    column: $table.uri,
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

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get favoritedAt => $composableBuilder(
    column: $table.favoritedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FavoritesTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableOrderingComposer({
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

  ColumnOrderings<String> get uri => $composableBuilder(
    column: $table.uri,
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

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get favoritedAt => $composableBuilder(
    column: $table.favoritedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FavoritesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uri =>
      $composableBuilder(column: $table.uri, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get sourceTrackId => $composableBuilder(
    column: $table.sourceTrackId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<int> get favoritedAt => $composableBuilder(
    column: $table.favoritedAt,
    builder: (column) => column,
  );
}

class $$FavoritesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavoritesTable,
          FavoriteRow,
          $$FavoritesTableFilterComposer,
          $$FavoritesTableOrderingComposer,
          $$FavoritesTableAnnotationComposer,
          $$FavoritesTableCreateCompanionBuilder,
          $$FavoritesTableUpdateCompanionBuilder,
          (
            FavoriteRow,
            BaseReferences<_$AppDatabase, $FavoritesTable, FavoriteRow>,
          ),
          FavoriteRow,
          PrefetchHooks Function()
        > {
  $$FavoritesTableTableManager(_$AppDatabase db, $FavoritesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoritesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoritesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoritesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uri = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> sourceTrackId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> artist = const Value.absent(),
                Value<String?> album = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<int> favoritedAt = const Value.absent(),
              }) => FavoritesCompanion(
                id: id,
                uri: uri,
                source: source,
                sourceTrackId: sourceTrackId,
                title: title,
                artist: artist,
                album: album,
                durationMs: durationMs,
                coverPath: coverPath,
                favoritedAt: favoritedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uri,
                required String source,
                required String sourceTrackId,
                required String title,
                Value<String?> artist = const Value.absent(),
                Value<String?> album = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                required int favoritedAt,
              }) => FavoritesCompanion.insert(
                id: id,
                uri: uri,
                source: source,
                sourceTrackId: sourceTrackId,
                title: title,
                artist: artist,
                album: album,
                durationMs: durationMs,
                coverPath: coverPath,
                favoritedAt: favoritedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FavoritesTable, FavoriteRow>(table),
                  BaseReferences<_$AppDatabase, $FavoritesTable, FavoriteRow>(
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

typedef $$FavoritesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavoritesTable,
      FavoriteRow,
      $$FavoritesTableFilterComposer,
      $$FavoritesTableOrderingComposer,
      $$FavoritesTableAnnotationComposer,
      $$FavoritesTableCreateCompanionBuilder,
      $$FavoritesTableUpdateCompanionBuilder,
      (
        FavoriteRow,
        BaseReferences<_$AppDatabase, $FavoritesTable, FavoriteRow>,
      ),
      FavoriteRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TracksTableTableManager get tracks =>
      $$TracksTableTableManager(_db, _db.tracks);
  $$ScanRootsTableTableManager get scanRoots =>
      $$ScanRootsTableTableManager(_db, _db.scanRoots);
  $$ScanStateTableTableManager get scanState =>
      $$ScanStateTableTableManager(_db, _db.scanState);
  $$AudioCacheTableTableManager get audioCache =>
      $$AudioCacheTableTableManager(_db, _db.audioCache);
  $$PlaybackStatesTableTableManager get playbackStates =>
      $$PlaybackStatesTableTableManager(_db, _db.playbackStates);
  $$FavoritesTableTableManager get favorites =>
      $$FavoritesTableTableManager(_db, _db.favorites);
}
