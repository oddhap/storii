import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/rxdart.dart';
import 'package:storii/app/models/enums.dart';
import 'package:storii/app/providers/settings_provider.dart';
import 'package:storii/features/downloads/logic/auto_delete_service.dart';
import 'package:storii/features/downloads/logic/download_queue.dart';
import 'package:storii/features/downloads/models/download_item.dart';
import 'package:storii/shared/helpers/abs_model_extensions.dart';
import 'package:storii/storage/local/downloads_store.dart';

import '../../../helpers/init_globals.dart';

class FakeDownloadsStore extends DownloadsStore {
  final _subject = BehaviorSubject<Map<String, DownloadItem>>.seeded({});
  final Map<String, DownloadItem> items = {};

  @override
  Stream<Map<String, DownloadItem>> build() => _subject.stream;

  @override
  Map<String, DownloadItem> getAll() => Map.from(items);

  @override
  Future<void> save(DownloadItem item) async {
    items[item.key] = item;
    _subject.add(Map.from(items));
  }

  @override
  Future<void> remove(String id) async {
    items.remove(id);
    _subject.add(Map.from(items));
  }

  Future<void> close() => _subject.close();
}

class FakeDownloadQueue extends DownloadQueue {
  final List<String> deleted = [];

  @override
  List<String> build() => [];

  @override
  Future<void> delete(String id, String? episodeId) async {
    deleted.add(mediaItemIdKey(id, episodeId));
  }
}

DownloadItem completedItem({String id = 'book-1', DateTime? autoDeleteAt}) {
  return DownloadItem(
    serverUrl: Uri.parse('http://localhost'),
    libraryItemId: id,
    userId: 'user-1',
    title: 'Test Book',
    author: 'Author',
    tracks: const [],
    status: DownloadStatus.completed,
    autoDeleteAt: autoDeleteAt,
  );
}

void main() {
  late FakeDownloadsStore store;
  late FakeDownloadQueue queue;

  setUpAll(() async {
    await initGlobals();
  });
  tearDownAll(disposeGlobals);

  setUp(() {
    store = FakeDownloadsStore();
    queue = FakeDownloadQueue();
  });

  tearDown(() => store.close());

  ProviderContainer createContainer({
    AutoDeleteFinishedDownloads mode = .afterDelay,
    Duration delay = const Duration(hours: 24),
  }) {
    return ProviderContainer(
      overrides: [
        downloadsStoreProvider.overrideWith(() => store),
        downloadQueueProvider.overrideWith(() => queue),
        autoDeleteFinishedDownloadsProvider.overrideWithValue(mode),
        autoDeleteFinishedDelayProvider.overrideWithValue(delay),
      ],
    );
  }

  test('marks a finished download for deletion after the delay', () async {
    final container = createContainer();
    addTearDown(container.dispose);
    container.listen(autoDeleteServiceProvider, (_, _) {});

    await store.save(completedItem());
    await pumpEventQueue();

    await container
        .read(autoDeleteServiceProvider.notifier)
        .onMarkedFinished('book-1', null);
    await pumpEventQueue();

    final item = store.items[mediaItemIdKey('book-1')]!;
    expect(item.autoDeleteAt, isNotNull);
    expect(item.autoDeleteAt!.isAfter(DateTime.now()), isTrue);
    expect(queue.deleted, isEmpty);
  });

  test('does not schedule when the setting is off', () async {
    final container = createContainer(mode: .off);
    addTearDown(container.dispose);
    container.listen(autoDeleteServiceProvider, (_, _) {});

    await store.save(completedItem());
    await pumpEventQueue();

    await container
        .read(autoDeleteServiceProvider.notifier)
        .onMarkedFinished('book-1', null);
    await pumpEventQueue();

    expect(store.items[mediaItemIdKey('book-1')]!.autoDeleteAt, isNull);
    expect(queue.deleted, isEmpty);
  });

  test('deletes immediately when set to immediately', () async {
    final container = createContainer(mode: .immediately);
    addTearDown(container.dispose);
    container.listen(autoDeleteServiceProvider, (_, _) {});

    await store.save(completedItem());
    await pumpEventQueue();

    await container
        .read(autoDeleteServiceProvider.notifier)
        .onMarkedFinished('book-1', null);
    await pumpEventQueue();

    expect(queue.deleted, [mediaItemIdKey('book-1')]);
  });

  test('deletes overdue downloads on startup', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    await store.save(
      completedItem(
        autoDeleteAt: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
    );
    container.listen(autoDeleteServiceProvider, (_, _) {});
    await pumpEventQueue();

    expect(queue.deleted, [mediaItemIdKey('book-1')]);
  });

  test('cancel clears a pending deletion', () async {
    final container = createContainer();
    addTearDown(container.dispose);
    container.listen(autoDeleteServiceProvider, (_, _) {});

    await store.save(
      completedItem(autoDeleteAt: DateTime.now().add(const Duration(hours: 1))),
    );
    await pumpEventQueue();

    await container
        .read(autoDeleteServiceProvider.notifier)
        .cancel('book-1', null);
    await pumpEventQueue();

    expect(store.items[mediaItemIdKey('book-1')]!.autoDeleteAt, isNull);
    expect(queue.deleted, isEmpty);
  });

  test('does not schedule items that are not downloaded', () async {
    final container = createContainer(mode: .immediately);
    addTearDown(container.dispose);
    container.listen(autoDeleteServiceProvider, (_, _) {});

    await container
        .read(autoDeleteServiceProvider.notifier)
        .onMarkedFinished('missing', null);
    await pumpEventQueue();

    expect(queue.deleted, isEmpty);
  });
}
