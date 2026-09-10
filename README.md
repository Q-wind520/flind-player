# Flind Player

A cross-platform music player built with Flutter.

## Platforms

| Platform | Priority |
| -------- | -------- |
| Android  | Primary  |
| Linux    | Primary  |
| Windows  | Secondary |
| macOS    | Secondary |
| iOS      | Secondary |
| Web      | Deferred (v2) |

## Identifiers

- Dart package: `flind_player`
- Android applicationId: `top.qwind.app.flind_player`
- iOS/macOS bundle ID: `top.qwind.app.flindPlayer`
- Linux application ID: `top.qwind.app.flind_player`

## Getting started

```bash
flutter pub get
flutter run -d linux
```

## Documentation

- [`docs/architecture.md`](docs/architecture.md) - architecture, layering, decisions (ADR), milestones, risks
- [`docs/bilibili-source.md`](docs/bilibili-source.md) - Bilibili adapter: endpoints, WBI signing, auth, rate limiting
- [`docs/local-library.md`](docs/local-library.md) - local library: scanning, metadata, drift schema, offline cache

## Status

Scaffold initialized and architecture designed. Next milestone: **M0** (skeleton + Riverpod wiring + drift + local file playback).

## License

Licensed under the GNU General Public License v3.0 - see [LICENSE](LICENSE) for the full text.
