import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/library_view.dart';

void main() {
  test('scopes expose the agreed defaults', () {
    expect(LibraryViewScope.all.defaultView, LibraryView.waterfall);
    expect(LibraryViewScope.favorites.defaultView, LibraryView.showcase);
    expect(LibraryViewScope.playlists.defaultView, LibraryView.showcase);
    expect(LibraryViewScope.playlistDetail.defaultView, LibraryView.list);
  });

  test('the playlists scope only allows showcase and list', () {
    expect(
      LibraryViewScope.playlists.allowedViews,
      {LibraryView.showcase, LibraryView.list},
    );
    expect(
      LibraryViewScope.playlists.sanitize(LibraryView.waterfall),
      LibraryView.showcase,
    );
  });

  test('sanitize keeps an allowed view and falls back otherwise', () {
    expect(
      LibraryViewScope.all.sanitize(LibraryView.list),
      LibraryView.list,
    );
    expect(
      LibraryViewScope.playlistDetail.sanitize(LibraryView.waterfall),
      LibraryView.waterfall,
    );
  });

  test('LibraryViews.viewOf returns the stored value or the default', () {
    const views = LibraryViews({
      LibraryViewScope.all: LibraryView.list,
    });
    expect(views.viewOf(LibraryViewScope.all), LibraryView.list);
    expect(views.viewOf(LibraryViewScope.favorites), LibraryView.showcase);
  });

  test('withView sanitizes and keeps other scopes', () {
    final views = LibraryViews.defaults
        .withView(LibraryViewScope.all, LibraryView.list)
        .withView(LibraryViewScope.playlists, LibraryView.waterfall);
    expect(views.viewOf(LibraryViewScope.all), LibraryView.list);
    // waterfall is not allowed for the playlists scope -> falls back.
    expect(views.viewOf(LibraryViewScope.playlists), LibraryView.showcase);
  });
}
