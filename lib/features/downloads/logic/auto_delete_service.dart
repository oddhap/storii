import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:storii/app/logs/log_service.dart';
import 'package:storii/app/providers/settings_provider.dart';
import 'package:storii/features/downloads/logic/download_queue.dart';
import 'package:storii/features/downloads/models/download_item.dart';
import 'package:storii/shared/helpers/abs_model_extensions.dart';
import 'package:storii/shared/helpers/app_error.dart';
import 'package:storii/storage/local/downloads_store.dart';

part 'auto_delete_service.g.dart';

@Riverpod(keepAlive: true)
class AutoDeleteService extends _$AutoDeleteService {
  final Map<String, Timer> _timers = {};
  final Map<String, DateTime> _scheduledAt = {};
  final Set<String> _inFlight = {};

  @override
  void build() {
    ref.onDispose(() {
      for (final timer in _timers.values) {
        timer.cancel();
      }
      _timers.clear();
      _scheduledAt.clear();
      _inFlight.clear();
    });

    ref.listen(downloadsStoreProvider, (_, next) {
      _reschedule(next.value ?? const {});
    });
    ref.listen(autoDeleteFinishedDownloadsProvider, (_, next) {
      if (next == .off) unawaited(_cancelAllPending());
      _reschedule(ref.read(downloadsStoreProvider).value ?? const {});
    });

    _reschedule(ref.read(downloadsStoreProvider).value ?? const {});
    if (ref.read(autoDeleteFinishedDownloadsProvider) == .off) {
      unawaited(_cancelAllPending());
    }
  }

  Future<void> onMarkedFinished(String libraryItemId, String? episodeId) async {
    final mode = ref.read(autoDeleteFinishedDownloadsProvider);
    if (mode == .off) return;

    final item = _find(libraryItemId, episodeId);
    if (item == null || !item.isComplete) return;

    final delay = mode == .immediately
        ? Duration.zero
        : ref.read(autoDeleteFinishedDelayProvider);
    final autoDeleteAt = DateTime.now().add(delay);

    await ref
        .read(downloadsStoreProvider.notifier)
        .save(item.copyWith(autoDeleteAt: autoDeleteAt));
  }

  Future<void> cancel(String libraryItemId, String? episodeId) async {
    final item = _find(libraryItemId, episodeId);
    if (item == null || item.autoDeleteAt == null) return;

    await ref
        .read(downloadsStoreProvider.notifier)
        .save(item.copyWith(autoDeleteAt: null));
  }

  DownloadItem? _find(String libraryItemId, String? episodeId) {
    final key = mediaItemIdKey(libraryItemId, episodeId);
    return ref.read(downloadsStoreProvider).value?[key];
  }

  Future<void> _cancelAllPending() async {
    final store = ref.read(downloadsStoreProvider.notifier);
    final downloads = ref.read(downloadsStoreProvider).value ?? const {};
    await Future.wait(
      downloads.values
          .where((item) => item.autoDeleteAt != null)
          .map((item) => store.save(item.copyWith(autoDeleteAt: null))),
    );
  }

  void _reschedule(Map<String, DownloadItem> downloads) {
    if (ref.read(autoDeleteFinishedDownloadsProvider) == .off) {
      _timers.keys.toList().forEach(_clear);
      return;
    }

    final now = DateTime.now();

    for (final item in downloads.values) {
      final at = item.autoDeleteAt;
      if (at == null || !item.isComplete) {
        _clear(item.key);
        continue;
      }
      if (_timers.containsKey(item.key) && _scheduledAt[item.key] == at) {
        continue;
      }

      _clear(item.key);
      final remaining = at.difference(now);
      if (remaining <= Duration.zero) {
        if (_inFlight.add(item.key)) unawaited(_delete(item));
        continue;
      }

      _scheduledAt[item.key] = at;
      _timers[item.key] = Timer(remaining, () {
        _clear(item.key);
        if (_inFlight.add(item.key)) unawaited(_delete(item));
      });
    }

    _timers.keys
        .toList()
        .where((key) => !downloads.containsKey(key))
        .forEach(_clear);
  }

  void _clear(String key) {
    _timers.remove(key)?.cancel();
    _scheduledAt.remove(key);
  }

  Future<void> _delete(DownloadItem item) async {
    try {
      await ref
          .read(downloadQueueProvider.notifier)
          .delete(item.libraryItemId, item.episodeId);
      LogService.log(
        'Auto-deleted finished download: ${item.title}',
        source: 'AutoDeleteService',
      );
    } catch (e, st) {
      final error = AppError.from(e, st);
      LogService.log(
        'Failed to auto-delete finished download: ${error.message}',
        source: 'AutoDeleteService',
        level: .error,
        originalError: error.originalError,
        stackTrace: error.stackTrace,
      );
    } finally {
      _inFlight.remove(item.key);
    }
  }
}
