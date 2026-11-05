import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/library_view.dart';

void main() {
  test('scopes expose the agreed defaults', () {
    expect(LibraryViewScope.all.defaultView, LibraryView.cards);
    expect(LibraryViewScope.favorites.defaultView, LibraryView.cards);
    expect(LibraryViewScope.playlists.defaultView, LibraryView.cards);
    expect(LibraryViewScope.playlistDetail.defaultView, LibraryView.list);
  });

  test('every scope offers cards and list', () {
    for (final scope in LibraryViewScope.values) {
      expect(
        scope.allowedViews,
        {LibraryView.cards, LibraryView.list},
        reason: '${scope.name} must offer both views',
      );
    }
  });

  test('sanitize keeps an allowed view', () {
    expect(LibraryViewScope.all.sanitize(LibraryView.list), LibraryView.list);
    expect(
      LibraryViewScope.playlistDetail.sanitize(LibraryView.cards),
      LibraryView.cards,
    );
  });

  test('LibraryViews.viewOf returns the stored value or the default', () {
    const views = LibraryViews({
      LibraryViewScope.all: LibraryView.list,
    });
    expect(views.viewOf(LibraryViewScope.all), LibraryView.list);
    expect(views.viewOf(LibraryViewScope.favorites), LibraryView.cards);
  });

  test('withView keeps other scopes', () {
    final views = LibraryViews.defaults
        .withView(LibraryViewScope.all, LibraryView.list)
        .withView(LibraryViewScope.playlists, LibraryView.cards);
    expect(views.viewOf(LibraryViewScope.all), LibraryView.list);
    expect(views.viewOf(LibraryViewScope.playlists), LibraryView.cards);
  });
}
