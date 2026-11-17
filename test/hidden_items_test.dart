import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/hidden_items.dart';
import 'package:flutter_test/flutter_test.dart';

BaseItemDto track(String id, {String? albumId, List<String>? tags}) => BaseItemDto(
  id: BaseItemId(id),
  name: id,
  type: 'Audio',
  albumId: albumId == null ? null : BaseItemId(albumId),
  tags: tags,
);

Set<BaseItemId> ids(List<String> raw) => raw.map(BaseItemId.new).toSet();

void expectKept((List<String>, int) actual, List<String> items, int start) {
  expect(actual.$1, items);
  expect(actual.$2, start);
}

void main() {
  group('isItemHidden', () {
    test('is false for an item that is not hidden', () {
      expect(isItemHidden(track('a', albumId: 'x', tags: ['live']), ids(['b'])), isFalse);
    });

    test('is true for an item in the hidden ids', () {
      expect(isItemHidden(track('a'), ids(['a'])), isTrue);
    });

    test('is true for an item with the hidden tag, ignoring case', () {
      expect(isItemHidden(track('a', tags: ['Hidden']), {}), isTrue);
    });

    test('is true for a track whose album is hidden', () {
      expect(isItemHidden(track('a', albumId: 'x'), ids(['x'])), isTrue);
    });
  });

  group('hasHiddenTag', () {
    test('is true only for the hidden tag, ignoring case', () {
      expect(hasHiddenTag(track('a', tags: ['live', 'HIDDEN'])), isTrue);
      expect(hasHiddenTag(track('a', tags: ['live'])), isFalse);
      expect(hasHiddenTag(track('a')), isFalse);
    });

    test('ignores local and album hides', () {
      expect(hasHiddenTag(track('a', albumId: 'x')), isFalse);
    });
  });

  group('withoutHidden', () {
    bool hidden(String item) => item.startsWith('h');

    test('leaves a list without hidden items unchanged', () {
      expectKept(withoutHidden(['a', 'b', 'c'], hidden, startIndex: 1), ['a', 'b', 'c'], 1);
    });

    test('shifts the start index past removed items before it', () {
      expectKept(withoutHidden(['h1', 'a', 'h2', 'b'], hidden, startIndex: 3), ['a', 'b'], 1);
    });

    test('removes hidden items after the start', () {
      expectKept(withoutHidden(['a', 'h1', 'b'], hidden), ['a', 'b'], 0);
    });

    test('keeps a hidden start item that was picked on purpose', () {
      expectKept(withoutHidden(['a', 'h1', 'b'], hidden, startIndex: 1, keepStart: true), ['a', 'h1', 'b'], 1);
    });

    test('moves a hidden start to the next visible item', () {
      expectKept(withoutHidden(['h1', 'h2', 'a', 'b'], hidden), ['a', 'b'], 0);
      expectKept(withoutHidden(['a', 'h1', 'b'], hidden, startIndex: 1), ['a', 'b'], 1);
    });

    test('starts at the beginning when nothing visible follows the start', () {
      expectKept(withoutHidden(['a', 'h1'], hidden, startIndex: 1), ['a'], 0);
    });

    test('returns an empty list when everything is hidden', () {
      expectKept(withoutHidden(['h1', 'h2'], hidden), <String>[], 0);
    });
  });

  group('visibleEntries', () {
    bool hidden(String item) => item.startsWith('h');

    test('drops hidden items but keeps the original index of the rest', () {
      expect(visibleEntries(['a', 'h1', 'b', 'h2', 'c'], hidden, HiddenItemsDisplay.remove), [
        (0, 'a'),
        (2, 'b'),
        (4, 'c'),
      ]);
    });

    test('keeps every item when hidden items are greyed out', () {
      expect(visibleEntries(['a', 'h1'], hidden, HiddenItemsDisplay.greyOut), [(0, 'a'), (1, 'h1')]);
    });
  });

  group('withHiddenTag', () {
    test('adds the tag and keeps every other field', () {
      final json = {
        'Id': 'a',
        'Name': 'Song',
        'Tags': ['live'],
        'LockedFields': ['Name'],
      };
      expect(withHiddenTag(json, true), {
        'Id': 'a',
        'Name': 'Song',
        'Tags': ['live', 'hidden'],
        'LockedFields': ['Name'],
      });
    });

    test('adds the tag when the item has no tags', () {
      expect(withHiddenTag({'Id': 'a'}, true), {
        'Id': 'a',
        'Tags': ['hidden'],
      });
    });

    test('does not add the tag twice', () {
      expect(
        withHiddenTag({
          'Tags': ['Hidden'],
        }, true),
        {
          'Tags': ['Hidden'],
        },
      );
    });

    test('removes every spelling of the tag', () {
      expect(
        withHiddenTag({
          'Tags': ['hidden', 'live', 'HIDDEN'],
        }, false),
        {
          'Tags': ['live'],
        },
      );
    });

    test('does not modify the original map', () {
      final json = {
        'Tags': ['live'],
      };
      withHiddenTag(json, true);
      expect(json, {
        'Tags': ['live'],
      });
    });
  });

  group('resolveHideAction', () {
    HideAction resolve({
      bool isAdmin = false,
      bool isOffline = false,
      HideScope scope = HideScope.ask,
      bool noticeShown = false,
    }) => resolveHideAction(isAdmin: isAdmin, isOffline: isOffline, scope: scope, localNoticeShown: noticeShown);

    test('tells non-admins the first time that hiding only affects this device', () {
      expect(resolve(), HideAction.showLocalNotice);
      expect(resolve(noticeShown: true), HideAction.hideLocal);
    });

    test('ignores the scope setting for non-admins', () {
      expect(resolve(scope: HideScope.everyone, noticeShown: true), HideAction.hideLocal);
    });

    test('asks admins until they choose a scope', () {
      expect(resolve(isAdmin: true), HideAction.askScope);
      expect(resolve(isAdmin: true, scope: HideScope.thisDevice), HideAction.hideLocal);
      expect(resolve(isAdmin: true, scope: HideScope.everyone), HideAction.hideOnServer);
    });

    test('hides locally for admins while offline', () {
      expect(resolve(isAdmin: true, isOffline: true), HideAction.hideLocal);
      expect(resolve(isAdmin: true, isOffline: true, scope: HideScope.everyone), HideAction.hideLocal);
    });
  });

  group('resolveUnhideAction', () {
    UnhideAction resolve({bool isAdmin = false, bool isOffline = false, bool inLocal = false, bool hasTag = false}) =>
        resolveUnhideAction(isAdmin: isAdmin, isOffline: isOffline, inLocal: inLocal, hasTag: hasTag);

    test('clears a local hide for anyone', () {
      expect(resolve(inLocal: true), (clearLocal: true, clearTag: false, blocked: null));
    });

    test('clears the server tag and any local hide for online admins', () {
      expect(resolve(isAdmin: true, inLocal: true, hasTag: true), (clearLocal: true, clearTag: true, blocked: null));
    });

    test('is blocked for non-admins when the server tag hides the item', () {
      expect(resolve(inLocal: true, hasTag: true), (
        clearLocal: false,
        clearTag: false,
        blocked: UnhideBlocked.serverAdminOnly,
      ));
    });

    test('is blocked for admins offline when the server tag hides the item', () {
      expect(resolve(isAdmin: true, isOffline: true, hasTag: true), (
        clearLocal: false,
        clearTag: false,
        blocked: UnhideBlocked.offline,
      ));
    });

    test('is blocked when only the album is hidden', () {
      expect(resolve(), (clearLocal: false, clearTag: false, blocked: UnhideBlocked.hiddenViaAlbum));
    });
  });

  group('excludeIdsFor', () {
    test('excludes every hidden id when there are few', () {
      final hidden = ids(['a', 'b']);
      final result = excludeIdsFor(hidden, limit: 50);
      expect(result.exclude, hidden.toList());
      expect(result.fetchLimit, 50);
    });

    test('caps the excluded ids and fetches extra to make up for the rest', () {
      final hidden = ids(List.generate(maxExcludedIds + 20, (i) => '$i'));
      final result = excludeIdsFor(hidden, limit: 50);
      expect(result.exclude, hasLength(maxExcludedIds));
      expect(result.fetchLimit, 70);
    });

    test('fetches at most twice the limit', () {
      final hidden = ids(List.generate(maxExcludedIds + 500, (i) => '$i'));
      expect(excludeIdsFor(hidden, limit: 50).fetchLimit, 100);
    });
  });
}
