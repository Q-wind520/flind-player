import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/library_view.dart';
import 'package:flind_player/data/providers/settings_repository_provider.dart';
import 'package:flind_player/features/library/library_view_provider.dart';

import 'support/fake_settings_repository.dart';

/// Implements only the library-view slice: the rest of the settings surface is
/// left unimplemented (throwing) so accidental cross-slice use is caught.
class _FakeSettings extends FakeSettingsBase with FakeLibrarySettings {}

void main() {
  test('build reads the persisted views', () async {
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(_FakeSettings()),
      ],
    );
    addTearDown(container.dispose);

    final views = await container.read(libraryViewsProvider.future);
    expect(views.viewOf(LibraryViewScope.all), LibraryView.cards);
  });

  test('setView persists and emits the new value', () async {
    final fake = _FakeSettings();
    final container = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    await container.read(libraryViewsProvider.future);
    await container
        .read(libraryViewsProvider.notifier)
        .setView(LibraryViewScope.all, LibraryView.list);

    final views = container.read(libraryViewsProvider).value!;
    expect(views.viewOf(LibraryViewScope.all), LibraryView.list);
  });

  test('setView persists cards for the playlists scope', () async {
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(_FakeSettings()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(libraryViewsProvider.future);
    await container
        .read(libraryViewsProvider.notifier)
        .setView(LibraryViewScope.playlists, LibraryView.cards);

    final views = container.read(libraryViewsProvider).value!;
    expect(views.viewOf(LibraryViewScope.playlists), LibraryView.cards);
  });
}
