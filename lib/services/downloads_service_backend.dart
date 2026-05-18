import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:chopper/chopper.dart';
import 'package:collection/collection.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:flutter/scheduler.dart';
import 'package:get_it/get_it.dart';
import 'package:isar/isar.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path_helper;
import 'package:uuid/uuid.dart';

import '../models/finamp_models.dart';
import '../models/jellyfin_models.dart';
import '../screens/downloads_screen.dart';
import 'finamp_settings_helper.dart';
import 'finamp_user_helper.dart';
import 'jellyfin_api_helper.dart';
import 'animated_music_service.dart';

part 'downloads_service_backend.g.dart';

/// This determines the target directory for new downloads, during migrations from the old download system, and during repairs.
/// Must not be changed without migrations. Additionally, directory cleaning in downloads repair should cover all folders ever used.
const FINAMP_BASE_DOWNLOAD_DIRECTORY = "songs";

const FINAMP_BASE_IMAGES_DIRECTORY = "images";

class IsarPersistentStorage implements PersistentStorage {
  final _isar = GetIt.instance<Isar>();

  @override
  Future<void> storeTaskRecord(TaskRecord record) => _store(IsarTaskDataType.taskRecord, record.taskId, record);

  @override
  Future<TaskRecord?> retrieveTaskRecord(String taskId) => _get(IsarTaskDataType.taskRecord, taskId);

  @override
  Future<List<TaskRecord>> retrieveAllTaskRecords() => _getAll(IsarTaskDataType.taskRecord);

  @override
  Future<void> removeTaskRecord(String? taskId) => _remove(IsarTaskDataType.taskRecord, taskId);

  @override
  Future<void> storePausedTask(Task task) => _store(IsarTaskDataType.pausedTask, task.taskId, task);

  @override
  Future<Task?> retrievePausedTask(String taskId) => _get(IsarTaskDataType.pausedTask, taskId);

  @override
  Future<List<Task>> retrieveAllPausedTasks() => _getAll(IsarTaskDataType.pausedTask);

  @override
  Future<void> removePausedTask(String? taskId) => _remove(IsarTaskDataType.pausedTask, taskId);

  @override
  Future<void> storeResumeData(ResumeData resumeData) =>
      _store(IsarTaskDataType.resumeData, resumeData.taskId, resumeData);

  @override
  Future<ResumeData?> retrieveResumeData(String taskId) => _get(IsarTaskDataType.resumeData, taskId);

  @override
  Future<List<ResumeData>> retrieveAllResumeData() => _getAll(IsarTaskDataType.resumeData);

  @override
  Future<void> removeResumeData(String? taskId) => _remove(IsarTaskDataType.resumeData, taskId);

  @override
  (String, int) get currentDatabaseVersion => ("FinampIsar", 1);

  @override
  // This should come from finamp settings if migration needed
  Future<(String, int)> get storedDatabaseVersion => Future.value(("FinampIsar", 1));

  @override
  Future<void> initialize() async {
    // Isar database gets opened by main
  }

  Future<void> _store(IsarTaskDataType type, String id, dynamic data) async {
    type.check(data); // Verify the data object has the correct type
    String json = jsonEncode(data.toJson());
    _isar.writeTxnSync(() {
      _isar.isarTaskDatas.putSync(IsarTaskData(IsarTaskData.getHash(type, id), type, json, 0), saveLinks: false);
    });
  }

  Future<T?> _get<T>(IsarTaskDataType<T> type, String id) async {
    var item = _isar.isarTaskDatas.getSync(IsarTaskData.getHash(type, id));
    return (item == null) ? null : type.fromJson(jsonDecode(item.jsonData) as Map<String, dynamic>);
  }

  Future<List<T>> _getAll<T>(IsarTaskDataType<T> type) async {
    var items = _isar.isarTaskDatas.where().typeEqualTo(type).findAllSync();
    return items.map((e) => type.fromJson(jsonDecode(e.jsonData) as Map<String, dynamic>)).toList();
  }

  Future<void> _remove(IsarTaskDataType type, String? id) async {
    _isar.writeTxnSync(() {
      if (id != null) {
        _isar.isarTaskDatas.deleteSync(IsarTaskData.getHash(type, id));
      } else {
        _isar.isarTaskDatas.where().typeEqualTo(type).deleteAllSync();
      }
    });
  }
}

class MissingServerItemException implements Exception {
  MissingServerItemException(this.item);

  final DownloadStub item;

  @override
  String toString() {
    return "MissingServerItemException(id: ${item.id}, name:${item.name})";
  }
}

/// A wrapper for storing various types of download related data in isar as JSON.
/// Do not confuse the id of this type with the ids that the content types have.
/// They will not match.
@collection
class IsarTaskData<T> {
  IsarTaskData(this.id, this.type, this.jsonData, this.age);

  /// Id of IsarTaskData.  Do not confuse with id of DownloadItem.
  final Id id;
  String jsonData;
  @Enumerated(EnumType.ordinal)
  @Index()
  final IsarTaskDataType<T> type;

  // This allows prioritization and uniqueness checking by delete buffer
  // It is also used as a retry counter by sync buffer.
  final int age;

  static int globalAge = 0;

  IsarTaskData.build(String stringId, this.type, T data, {int? age})
    : id = IsarTaskData.getHash(type, stringId),
      jsonData = _toJson(data),
      age = age ?? globalAge++;

  static int getHash(IsarTaskDataType type, String id) => _fastHash(type.name + id);

  @ignore
  T get data => type.fromJson(jsonDecode(jsonData) as Map<String, dynamic>);

  set data(T item) => jsonData = _toJson(item);

  static String _toJson(dynamic item) {
    switch (item) {
      case int id:
        return jsonEncode({"id": id});
      case _:
        return jsonEncode((item as dynamic).toJson());
    }
  }

  /// FNV-1a 64bit hash algorithm optimized for Dart Strings
  /// Provided by Isar documentation
  /// Do not use directly, use getHash
  static int _fastHash(String string) {
    var hash = 0xcbf29ce484222325;

    var i = 0;
    while (i < string.length) {
      final codeUnit = string.codeUnitAt(i++);
      hash ^= codeUnit >> 8;
      hash *= 0x100000001b3;
      hash ^= codeUnit & 0xFF;
      hash *= 0x100000001b3;
    }

    return hash;
  }

  @override
  bool operator ==(Object other) {
    return other is IsarTaskData && other.id == id;
  }

  @override
  @ignore
  int get hashCode => id;
}

/// Type enum for IsarTaskData
/// Enumerated by Isar, do not modify order or delete existing entries.
enum IsarTaskDataType<T> {
  pausedTask<Task>(Task.createFromJson),
  taskRecord<TaskRecord>(TaskRecord.fromJson),
  resumeData<ResumeData>(ResumeData.fromJson),
  deleteNode<int>(_deleteFromJson),
  syncNode<SyncNode>(SyncNode.fromJson);

  const IsarTaskDataType(this.fromJson);

  static int _deleteFromJson(Map<String, dynamic> map) {
    return map["id"] as int;
  }

  final T Function(Map<String, dynamic>) fromJson;

  void check(T data) {}
}

@JsonSerializable(explicitToJson: true, anyMap: true, converters: [BaseItemIdConverter()])
class SyncNode {
  SyncNode({required this.stubIsarId, required this.required, required this.viewId});

  int stubIsarId;
  bool required;
  BaseItemId? viewId;

  factory SyncNode.fromJson(Map<String, dynamic> json) => _$SyncNodeFromJson(json);

  Map<String, dynamic> toJson() => _$SyncNodeToJson(this);
}

/// This is a TaskQueue for FileDownloader that enqueues DownloadItems that are in
/// enqueued state.They should already have the file path calculated.
class IsarTaskQueue implements TaskQueue {
  static final _enqueueLog = Logger('IsarTaskQueue');
  final DownloadsService _downloadsService;
  final _jellyfinApiData = GetIt.instance<JellyfinApiHelper>();
  final _finampUserHelper = GetIt.instance<FinampUserHelper>();

  IsarTaskQueue(this._downloadsService);

  /// Set of tasks that are believed to be actively running
  final _activeDownloads = <int>{}; // by TaskId

  Completer<void>? _callbacksComplete;

  final _isar = GetIt.instance<Isar>();

  /// Initialize the queue and start stored downloads.
  /// Should only be called after background_downloader and downloadsService are
  /// fully set up.
  Future<void> initializeQueue() async {
    _activeDownloads.addAll(
      (await FileDownloader().allTasks(includeTasksWaitingToRetry: true)).map((e) => int.parse(e.taskId)),
    );
    List<DownloadItem> completed = [];
    List<DownloadItem> needsEnqueue = [];
    for (var item
        in _isar.downloadItems
            .where()
            .stateEqualTo(DownloadItemState.enqueued)
            .or()
            .stateEqualTo(DownloadItemState.downloading)
            .filter()
            .typeEqualTo(DownloadItemType.track)
            .or()
            .typeEqualTo(DownloadItemType.image)
            .findAllSync()) {
      if (item.file?.existsSync() ?? false) {
        _activeDownloads.remove(item.isarId);
        completed.add(item);
      } else if (item.state == DownloadItemState.downloading) {
        if (!_activeDownloads.contains(item.isarId)) {
          needsEnqueue.add(item);
        }
      }
    }
    _isar.writeTxnSync(() {
      // Images marked as completed this way will not recieve updated extensions like ones
      // processed in status updates, but that's not really important
      for (var item in completed) {
        _downloadsService.updateItemState(item, DownloadItemState.complete);
        _enqueueLog.info("Marking download ${item.name} as complete on startup.");
      }
      for (var item in needsEnqueue) {
        _downloadsService.updateItemState(item, DownloadItemState.enqueued);
        _enqueueLog.info("Re-enqueueing download ${item.name} on startup.");
      }
    });
  }

  /// Execute all pending downloads.
  Future<void> executeDownloads() async {
    if (_callbacksComplete != null) {
      return _callbacksComplete!.future;
    }
    try {
      _callbacksComplete = Completer();
      unawaited(_advanceQueue());
      await _callbacksComplete!.future;
      _enqueueLog.info("All downloads enqueued.");
    } finally {
      _callbacksComplete = null;
    }
  }

  /// Advance the queue if possible and ready, no-op if not.
  /// Will loop until all downloads have been enqueued.  Will enqueue
  /// finampSettings.maxConcurrentDownloads at once.
  Future<void> _advanceQueue() async {
    try {
      while (true) {
        var nextTasks = _isar.downloadItems
            .where()
            .stateEqualTo(DownloadItemState.enqueued)
            .filter()
            .allOf(_activeDownloads, (q, element) => q.not().isarIdEqualTo(element))
            .limit(20)
            .findAllSync();
        if (nextTasks.isEmpty || !_downloadsService.allowDownloads || FinampSettingsHelper.finampSettings.isOffline) {
          return;
        }
        for (var task in nextTasks) {
          if (task.file == null) {
            _enqueueLog.severe("Received ${task.name} with no valid file path.");
            _isar.writeTxnSync(() {
              _downloadsService.updateItemState(task, DownloadItemState.failed);
            });
            continue;
          }
          while (_activeDownloads.length >= FinampSettingsHelper.finampSettings.maxConcurrentDownloads ||
              _finampUserHelper.currentUser == null) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
          await SchedulerBinding.instance.scheduleTask(() {
            _activeDownloads.add(task.isarId);
            try {
              // Base URL shouldn't be null at this point (user has to be logged in
              // to get to the point where they can add downloads).
              var url = switch (task.type) {
                DownloadItemType.track =>
                  _jellyfinApiData
                      .getTrackDownloadUrl(item: task.baseItem!, transcodingProfile: task.fileTranscodingProfile)
                      .toString(),
                DownloadItemType.image =>
                  _jellyfinApiData
                      .getImageUrl(
                        item: task.baseItem!,
                        // Download original file
                        quality: null,
                        format: null,
                      )
                      .toString(),
                  DownloadItemType.animatedCover =>
                GetIt.instance<AnimatedMusicService>().buildAnimatedCoverUrlForTrack(task.baseItem!.id).toString(),
              DownloadItemType.verticalBackgroundVideo =>
                GetIt.instance<AnimatedMusicService>().buildVerticalBackgroundUrlForTrack(task.baseItem!.id).toString(),
                _ => throw StateError("Invalid enqueue ${task.name} which is a ${task.type}"),
              };
              _enqueueLog.fine("Submitting download ${task.name} to background_downloader.");
              var downloadTask = DownloadTask(
                taskId: task.isarId.toString(),
                url: url,
                displayName: task.name,
                baseDirectory: task.fileDownloadLocation!.baseDirectory.baseDirectory,
                retries: 3,
                directory: path_helper.dirname(task.path!),
                headers: {"Authorization": _finampUserHelper.authorizationHeader},
                filename: path_helper.basename(task.path!),
              );
              return Future.sync(() async {
                //bool success = await FileDownloader().resume(downloadTask);
                //if (!success) {
                bool success = await FileDownloader().enqueue(downloadTask);
                //}
                if (!success) {
                  // We currently have no way to recover here.  The user must re-sync to clear
                  // the stuck download.
                  _enqueueLog.severe("Task ${task.name} failed to enqueue with background_downloader.");
                }
              });
            } catch (e) {
              _enqueueLog.severe("Error creating download task for ${task.name}: $e.", e);
              _isar.writeTxnSync(() {
                _downloadsService.updateItemState(task, DownloadItemState.failed);
              });
            }
            // Set priority high to prevent stalling
          }, Priority.animation + 50);
          // This helps prevent choking the method channel, see MemoryTaskQueue
          await Future.delayed(const Duration(milliseconds: 20));
        }
      }
    } finally {
      _callbacksComplete?.complete();
    }
  }

  /// Returns true if the internal queue state and downloader state match
  /// the state of the given item.  Download state should be reset if false.
  Future<bool> validateQueued(DownloadItem item) async {
    if (item.state == DownloadItemState.downloading || _activeDownloads.contains(item.isarId)) {
      var activeTasks = await FileDownloader().allTasks(includeTasksWaitingToRetry: true);
      var activeItemIds = activeTasks.map((e) => int.parse(e.taskId)).toList();
      if (!activeItemIds.contains(item.isarId)) {
        return false;
      }
    }
    return true;
  }

  /// Remove a download task from this queue and cancel any active download.
  Future<void> remove(DownloadItem item) async {
    if (item.state == DownloadItemState.enqueued || item.state == DownloadItemState.downloading) {
      _isar.writeTxnSync(() {
        var canonItem = _isar.downloadItems.getSync(item.isarId);
        if (canonItem != null) {
          _downloadsService.updateItemState(canonItem, DownloadItemState.notDownloaded);
        }
      });
    }
    if (_activeDownloads.contains(item.isarId)) {
      _activeDownloads.remove(item.isarId);
      await FileDownloader().cancelTaskWithId(item.isarId.toString());
    }
  }

  /// Called by FileDownloader whenever a download completes.
  /// Remove the completed task and allow the queue to advance.
  @override
  void taskFinished(Task task) {
    _activeDownloads.remove(int.parse(task.taskId));
  }

  // We do not currently pause or resume the downloads
  @override
  Future<void> pauseAll() async {}
  @override
  Future<void> resumeAll() async {}
}

/// A class for storing pending deletes in Isar.  This is used to save unlinked
/// but not yet deleted nodes so that they always get cleaned up, even if the
/// app suddenly shuts down.
class DownloadsDeleteService {
  final _isar = GetIt.instance<Isar>();
  final DownloadsService _downloadsService;
  final _deleteLogger = Logger("DeleteBuffer");

  final Set<int> _activeDeletes = {};
  Completer<void>? _callbacksComplete;

  DownloadsDeleteService(this._downloadsService) {
    IsarTaskData.globalAge = _isar.isarTaskDatas.where().typeEqualTo(type).sortByAgeDesc().findFirstSync()?.age ?? 0;
  }

  final type = IsarTaskDataType.deleteNode;

  final int _batchSize = 10;

  /// Add nodes to be deleted at a later time.  This should
  /// be called before nodes are unlinked to guarantee nodes cannot be lost.
  /// This should only be called inside an isar write transaction
  void addAll(Iterable<int> isarIds) {
    var items = isarIds.map((e) => IsarTaskData.build(e.toString(), type, e)).toList();
    _isar.isarTaskDatas.putAllSync(items, saveLinks: false);
  }

  /// Execute all pending deletes.
  Future<void> executeDeletes() async {
    if (_callbacksComplete != null) {
      return _callbacksComplete!.future;
    }
    try {
      _activeDeletes.clear();
      _callbacksComplete = Completer();
      unawaited(_advanceQueue());
      await _callbacksComplete!.future;
      _deleteLogger.info("All deletes complete.");
    } finally {
      _callbacksComplete = null;
    }
  }

  /// Execute all queued _syncdeletes.  Will call itself until there are max concurrent
  /// download workers running at once.  Uses age variable to determine if queued
  /// deletes have ben updated to avoid removing queue items that have been re-added
  /// and need re-calculation.
  Future<void> _advanceQueue() async {
    List<IsarTaskData<dynamic>> wrappedDeletes = [];
    while (true) {
      // Delete latency is always low, so run less deletes in parallel
      if (_activeDeletes.length * 4 >= FinampSettingsHelper.finampSettings.downloadWorkers * _batchSize ||
          _callbacksComplete == null) {
        return;
      }
      try {
        // This must be synchronous or we can get more than 5 threads and multiple threads
        // processing the same item
        wrappedDeletes = _isar.isarTaskDatas
            .where()
            .typeEqualTo(type)
            .filter()
            .allOf(_activeDeletes, (q, value) => q.not().idEqualTo(value))
            .sortByAge() // Try to process oldest deletes first as they are more likely to be deletable
            .limit(_batchSize)
            .findAllSync();
        if (wrappedDeletes.isEmpty) {
          assert(_isar.isarTaskDatas.where().typeEqualTo(type).countSync() >= _activeDeletes.length);
          if (_activeDeletes.isEmpty && _callbacksComplete != null) {
            _callbacksComplete!.complete(null);
          }
          return;
        }
        _activeDeletes.addAll(wrappedDeletes.map((e) => e.id));
        // Once we've claimed our item, try to launch another worker in case we have <5.
        unawaited(_advanceQueue());
        for (var delete in wrappedDeletes) {
          try {
            await SchedulerBinding.instance
            // Set priority high to prevent stalling
            .scheduleTask(() => syncDelete(delete.data as int), Priority.animation + 100);
          } catch (e, stack) {
            // we don't expect errors here, _syncDelete should already be catching everything
            // mark node as complete and continue
            GlobalSnackbar.error(e);
            _deleteLogger.severe("Uncaught error while syncDeleting ${delete.id}", e, stack);
          }
        }

        _isar.writeTxnSync(() {
          var canonDeletes = _isar.isarTaskDatas.getAllSync(wrappedDeletes.map((e) => e.id).toList());
          List<int> removable = [];
          // Items with unexpected ages have been re-added and need reprocessing
          for (int i = 0; i < canonDeletes.length; i++) {
            if (wrappedDeletes[i].age == canonDeletes[i]?.age) {
              removable.add(wrappedDeletes[i].id);
            }
          }
          _isar.isarTaskDatas.deleteAllSync(removable);
        });
      } finally {
        var currentIds = wrappedDeletes.map((e) => e.id);
        _activeDeletes.removeAll(currentIds);
      }
    }
  }

  /// This processes a node for potential deletion based on incoming info and requires links.
  /// Required nodes will not be altered.  Info track nodes will have downloaded files
  /// deleted and info links cleared.  Other types of info node will have requires links
  /// cleared.  Nodes with no incoming links at all are deleted.  All unlinked children
  /// are added to delete buffer fro recursive sync deleting.
  Future<void> syncDelete(int isarId) async {
    DownloadItem? canonItem;
    int requiredByCount = -1;
    int infoForCount = -1;
    _isar.writeTxnSync(() {
      canonItem = _isar.downloadItems.getSync(isarId);
      requiredByCount = canonItem?.requiredBy.filter().countSync() ?? -1;
      infoForCount = canonItem?.infoFor.filter().countSync() ?? -1;
      // If the node is still required, update download settings in case a required
      // link with a higher transcode profile was removed
      if (canonItem != null && requiredByCount > 0 && canonItem!.type != DownloadItemType.anchor) {
        _downloadsService.syncItemDownloadSettings(canonItem!);
        return;
      }
    });
    if (canonItem == null || requiredByCount > 0 || canonItem!.type == DownloadItemType.anchor) {
      return;
    }
    // images should always be downloaded, even if they only have info links
    // This allows deleting all require links for collections but retaining associated images
    if (canonItem!.type == DownloadItemType.image && infoForCount > 0) {
      return;
    }

    if (canonItem!.type.hasFiles) {
      await deleteDownload(canonItem!);
    }

    // Allow frame processing between file deletion and database work.
    await SchedulerBinding.instance
    // Set priority high to prevent stalling
    .scheduleTask(() {
      Set<int> childIds = {};
      _isar.writeTxnSync(() {
        DownloadItem? transactionItem = _isar.downloadItems.getSync(canonItem!.isarId);
        if (transactionItem == null) {
          return;
        }
        if (transactionItem.type.hasFiles) {
          if (transactionItem.state != DownloadItemState.notDownloaded) {
            _deleteLogger.severe("Could not delete ${transactionItem.name}, may still have files");
            return;
          }
        }
        infoForCount = transactionItem.infoFor.filter().countSync();
        requiredByCount = transactionItem.requiredBy.filter().countSync();
        if (requiredByCount != 0) {
          _deleteLogger.severe("Node ${transactionItem.id} became required during file deletion");
          return;
        }
        if (infoForCount > 0) {
          if (transactionItem.type == DownloadItemType.track) {
            // Non-required tracks cannot have info links to collections, but they
            // can still require their images.
            childIds.addAll(transactionItem.info.filter().isarIdProperty().findAllSync());
            addAll(childIds);
            transactionItem.info.resetSync();
          } else {
            childIds.addAll(transactionItem.requires.filter().isarIdProperty().findAllSync());
            addAll(childIds);
            transactionItem.requires.resetSync();
            if (!transactionItem.type.hasFiles &&
                transactionItem.baseItemType != BaseItemDtoType.album &&
                transactionItem.baseItemType != BaseItemDtoType.playlist) {
              // Only albums/playlists retain child lists in info state and can be considered downloaded.
              // All other collection types must be considered notDownloaded.
              _downloadsService.updateItemState(transactionItem, DownloadItemState.notDownloaded);
            }
          }
        } else {
          _deleteLogger.finer("Removing node for ${canonItem?.name}");
          childIds.addAll(transactionItem.info.filter().isarIdProperty().findAllSync());
          childIds.addAll(transactionItem.requires.filter().isarIdProperty().findAllSync());
          addAll(childIds);
          _isar.downloadItems.deleteSync(transactionItem.isarId);
        }
      });
    }, Priority.animation);
  }

  /// Removes any files associated with the item, cancels any pending downloads,
  /// and marks it as notDownloaded.  Used by [_syncDelete], as well as by
  /// [repairAllDownloads] and [_initiateDownload] to force a file into a known state.
  Future<void> deleteDownload(DownloadItem item) async {
    assert(item.type.hasFiles);
    if (item.state == DownloadItemState.notDownloaded) {
      return;
    }

    await _downloadsService.downloadTaskQueue.remove(item);
    if (item.file != null && item.file!.existsSync()) {
      try {
        await item.file!.delete();
        _deleteLogger.finer("Deleted file for ${item.name}");
      } on PathNotFoundException {
        _deleteLogger.finer("File ${item.file!.path} for ${item.name} missing during delete.");
      }
    }

    if (item.file != null && item.fileDownloadLocation!.useHumanReadableNames) {
      Directory trackDirectory = item.file!.parent;
      try {
        if (await trackDirectory.list().isEmpty) {
          _deleteLogger.info("${trackDirectory.path} is empty, deleting");
          await trackDirectory.delete();
        }
      } on PathNotFoundException {
        _deleteLogger.finer("Directory ${trackDirectory.path} missing during delete.");
      }
    }

    _isar.writeTxnSync(() {
      var transactionItem = _isar.downloadItems.getSync(item.isarId);
      if (transactionItem != null) {
        _downloadsService.updateItemState(transactionItem, DownloadItemState.notDownloaded);
      }

      if (item.type == DownloadItemType.track) {
        // delete corresponding lyrics if they exist, using the same ID
        if (_isar.downloadedLyrics.deleteSync(item.isarId)) {
          _deleteLogger.finer("Deleted lyrics for ${item.name}");
        }
      }
    });
  }
}

/// A class for storing pending syncs in Isar.  This allows syncing to resume
/// in the event of an app shutdown.  Completed lists are stored in memory,
/// so some nodes may get re-synced unnecessarily after an unexpected reboot
/// but this should have minimal impact.
class DownloadsSyncService {
  final _isar = GetIt.instance<Isar>();
  final DownloadsService _downloadsService;
  final _syncLogger = Logger("SyncBuffer");
  final _jellyfinApiData = GetIt.instance<JellyfinApiHelper>();
  final _finampUserHelper = GetIt.instance<FinampUserHelper>();

  /// Currently processing syncs.  Will be null if no syncs are executing.
  final Set<int> _activeSyncs = {};
  final Set<int> _requireCompleted = {};
  final Set<int> _infoCompleted = {};
  Completer<void>? _callbacksComplete;
  int _missingItemExceptions = 0;

  final int _batchSize = 10;

  DownloadsSyncService(this._downloadsService);

  final type = IsarTaskDataType.syncNode;

  bool get isRunning => _callbacksComplete != null;

  /// Add nodes to be synced at a later time.
  /// Must be called inside an Isar write transaction.
  void addAll(Iterable<int> required, Iterable<int> info, BaseItemId? viewId) {
    var items = required
        .map(
          (e) =>
              IsarTaskData.build("required $e", type, SyncNode(stubIsarId: e, required: true, viewId: viewId), age: 0),
        )
        .toList();
    items.addAll(
      info.map(
        (e) => IsarTaskData.build("info $e", type, SyncNode(stubIsarId: e, required: false, viewId: viewId), age: 1),
      ),
    );
    _isar.isarTaskDatas.putAllSync(items, saveLinks: false);
  }

  /// Execute all pending syncs.
  Future<void> executeSyncs() async {
    if (_callbacksComplete != null) {
      return _callbacksComplete!.future;
    }
    try {
      _requireCompleted.clear();
      _infoCompleted.clear();
      _activeSyncs.clear();
      _metadataCache = {};
      _childCache = {};
      _callbacksComplete = Completer();
      _missingItemExceptions = 0;
      unawaited(_advanceQueue());
      await _callbacksComplete!.future;
      _syncLogger.info("All syncs complete.");
      if (_missingItemExceptions > 0) {
        showSyncWarningSnackbar();
      }
    } finally {
      _callbacksComplete = null;
    }
  }

  /// Execute all queued _syncDownload.  Will call itself until there are max concurrent
  /// download workers running at once.  Will retry items that throw errors up to
  /// 5 times before skipping and alerting the user.
  /// TODO show a confirmation snackbar once all downloads are complete
  Future<void> _advanceQueue() async {
    List<IsarTaskData<dynamic>> wrappedSyncs = [];
    while (true) {
      if ((_downloadsService.fullSpeedSync ? _activeSyncs.length : (_activeSyncs.length * 2)) >=
              FinampSettingsHelper.finampSettings.downloadWorkers * _batchSize ||
          _callbacksComplete == null) {
        return;
      }
      try {
        // This must be synchronous or we can get more than 5 threads and multiple threads
        // processing the same item
        wrappedSyncs = _isar.isarTaskDatas
            .where()
            .typeEqualTo(type)
            .filter()
            .allOf(_activeSyncs, (q, value) => q.not().idEqualTo(value))
            .sortByAge() // Prioritize required nodes
            .limit(_batchSize)
            .findAllSync();
        if (wrappedSyncs.isEmpty ||
            !_downloadsService.allowSyncs ||
            FinampSettingsHelper.finampSettings.isOffline ||
            _finampUserHelper.currentUser == null) {
          assert(_isar.isarTaskDatas.where().typeEqualTo(type).countSync() >= _activeSyncs.length);
          if (_activeSyncs.isEmpty && _callbacksComplete != null) {
            _callbacksComplete!.complete(null);
          }
          return;
        }
        _activeSyncs.addAll(wrappedSyncs.map((e) => e.id));
        // Once we've claimed our item, try to launch another worker in case we have <5.
        unawaited(_advanceQueue());
        List<IsarTaskData<dynamic>> failedSyncs = [];
        for (var wrappedSync in wrappedSyncs) {
          SyncNode sync = wrappedSync.data as SyncNode;
          try {
            var item = _isar.downloadItems.getSync(sync.stubIsarId);
            if (item != null) {
              try {
                await SchedulerBinding.instance.scheduleTask(
                  () => _syncDownload(item, sync.required, _requireCompleted, _infoCompleted, sync.viewId),
                  // Set priority high to prevent stalling
                  Priority.animation + 100,
                );
              } catch (e) {
                // Re-enqueue failed syncs with lower priority
                if (wrappedSync.age > 7) {
                  _syncLogger.severe("Sync of ${item.name} repeatedly failed, skipping.");
                  _isar.writeTxnSync(() {
                    _downloadsService.updateItemState(item, DownloadItemState.syncFailed);
                  });
                  if (e is MissingServerItemException) {
                    _missingItemExceptions++;
                  } else {
                    rethrow;
                  }
                } else {
                  _syncLogger.finest("Sync of ${item.name} failed with error $e, retrying", e);
                  _requireCompleted.remove(sync.stubIsarId);
                  _infoCompleted.remove(sync.stubIsarId);
                  if (e is SocketException) {
                    // Connection issues should just be retried without lowering priority
                    // or progressing towards permanent failure
                    failedSyncs.add(wrappedSync);
                  } else {
                    failedSyncs.add(
                      IsarTaskData(wrappedSync.id, wrappedSync.type, wrappedSync.jsonData, wrappedSync.age + 2),
                    );
                  }
                }
                if (_finampUserHelper.currentUser == null) break;
              }
            }
          } catch (e, stack) {
            // mark node as complete and continue
            GlobalSnackbar.error(e);
            _syncLogger.severe(e, e, stack);
          }
        }

        _isar.writeTxnSync(() {
          _isar.isarTaskDatas.deleteAllSync(wrappedSyncs.map((e) => e.id).toList());
          _isar.isarTaskDatas.putAllSync(failedSyncs, saveLinks: false);
        });
      } finally {
        _activeSyncs.removeAll(wrappedSyncs.map((e) => e.id));
      }
    }
  }

  /// Syncs a downloaded item with the latest data from the server, then recursively
  /// syncs children.  The item should already be present in Isar.  Items can be synced
  /// as required or info.  Info collections will only have info child nodes, and info
  /// tracks will only have required nodes.  Info tracks will not be downloaded.
  /// Image/anchor nodes always process as required, so this flag has no effect.  Nodes
  /// processed as info may be required via another parent, so children/files only needed
  /// for required nodes should be left in place, and will be handled by [_syncDelete]
  /// if necessary.  See [repairAllDownloads] for more information on the structure
  /// of the node graph and which children are allowable for each node type.
  Future<void> _syncDownload(
    DownloadStub parent,
    bool asRequired,
    Set<int> requireCompleted,
    Set<int> infoCompleted,
    BaseItemId? viewId,
  ) async {
    switch (parent.type) {
      case DownloadItemType.collection:
        switch (parent.baseItemType) {
          case BaseItemDtoType.playlist:
          case BaseItemDtoType.artist:
          case BaseItemDtoType.genre:
            viewId = null;
          case BaseItemDtoType.library:
            viewId = BaseItemId(parent.id);
          case _:
            break;
        }
      case DownloadItemType.track:
        break;
      case DownloadItemType.image:
      case DownloadItemType.animatedCover:
      case DownloadItemType.verticalBackgroundVideo:
      case DownloadItemType.anchor:
        viewId = null;
        asRequired = true;
      case DownloadItemType.finampCollection:
        switch (parent.finampCollection!.type) {
          case FinampCollectionType.favorites:
          case FinampCollectionType.allPlaylists:
          case FinampCollectionType.latest5Albums:
          case FinampCollectionType.allPlaylistsMetadata:
            viewId = null;
          case FinampCollectionType.libraryImages:
          case FinampCollectionType.collectionWithLibraryFilter:
            viewId = parent.finampCollection!.library!.id;
        }
    }
    if (requireCompleted.contains(parent.isarId)) {
      return;
    } else if (infoCompleted.contains(parent.isarId) && !asRequired) {
      return;
    } else {
      if (asRequired) {
        requireCompleted.add(parent.isarId);
      } else {
        infoCompleted.add(parent.isarId);
      }
    }

    DownloadItem? isarParent;

    // Skip items that are unlikely to need syncing if allowed.  This cannot skip info-only items as we do not have
    // enough information to know if they have ever been synced, limiting utility with track and playlist downloads,
    // but it should be more effective with albums, libraries, artists, and genres, which should primarily result
    // in complete album downloads.
    if (FinampSettingsHelper.finampSettings.preferQuickSyncs && !_downloadsService.forceFullSync) {
      if (parent.type.requiresItem && !parent.baseItemType.expectChanges) {
        isarParent = _isar.downloadItems.getSync(parent.isarId);
        if (isarParent?.state == DownloadItemState.complete) {
          _syncLogger.finest("Skipping sync of ${parent.name}");
          return;
        }
      }
    }

    _syncLogger.finer("Syncing ${parent.baseItemType.name} ${parent.name} with required:$asRequired viewId:$viewId");

    //
    // Fetch latest metadata from server, if needed or not quicksyncing
    //
    // newBaseItem must be calculated before children are determined so that the latest
    // metadata can be used, especially imageId and blurhash.
    BaseItemDto? newBaseItem;
    //If we aren't quicksyncing, fetch the latest BaseItemDto to copy into Isar.
    if (parent.type.requiresItem) {
      bool expectNewItem = false;
      if (!FinampSettingsHelper.finampSettings.preferQuickSyncs ||
          _downloadsService.forceFullSync ||
          _needsMetadataUpdate(parent)) {
        newBaseItem = (await _getCollectionInfo(parent.baseItem!.id, parent.type, true))?.baseItem;
        expectNewItem = true;
      } else if (_metadataCache.containsKey(parent.baseItem!.id)) {
        // Opportunistically check for item updates if we've already fetched from the server
        newBaseItem = (await _metadataCache[parent.baseItem!.id])?.baseItem;
        expectNewItem = true;
      }
      // If we fail to get a valid baseItemDto from the server, for most items we just wait for all other items to unlink us.
      // For images, we may remain linked due to our blurhash/imageId still being used, so we attempt to find a
      // replacement baseItemDto whose blurhash/imageId match.
      if (expectNewItem) {
        if (parent.type == DownloadItemType.image) {
          if ((newBaseItem?.blurHash ?? newBaseItem?.imageId) != parent.id) {
            newBaseItem = await _updateImageBaseItem(parent);
          }
        } else {
          if (newBaseItem == null) {
            _syncLogger.warning("Could not fetch BaseItemDto ${parent.name} from server.");
            throw MissingServerItemException(parent);
          }
        }
      }
    }
    // We return the same BaseItemDto for all requests, so null out playlistItemId
    // as it will not usually be accurate.  Modifying without copying should be
    // fine as this item was generated within the download service, so this value
    // is not being used elsewhere.
    if (parent.baseItem?.playlistItemId != null || newBaseItem?.playlistItemId != null) {
      newBaseItem ??= parent.baseItem;
      newBaseItem?.playlistItemId = null;
    }

    //
    // Calculate needed children for item based on type and asRequired flag
    //
    bool updateRequiredChildren = true;
    Set<DownloadStub> requiredChildren = {};
    Set<DownloadStub> infoChildren = {};
    List<DownloadStub>? orderedChildItems;
    switch (parent.type) {
      case DownloadItemType.collection:
        var item = newBaseItem ?? parent.baseItem!;
        try {
          if (asRequired) {
            orderedChildItems = await _getCollectionChildren(parent);
            requiredChildren.addAll(orderedChildItems);
          }
          if (parent.baseItemType == BaseItemDtoType.album || parent.baseItemType == BaseItemDtoType.playlist) {
            orderedChildItems ??= await _getCollectionChildren(parent);
            infoChildren.addAll(orderedChildItems);
          }
          if (parent.baseItemType == BaseItemDtoType.album && viewId == null) {
            isarParent ??= _isar.downloadItems.getSync(parent.isarId);
            if (isarParent?.viewId == null) {
              // If we are an album and have no viewId, attempt to fetch from server
              viewId = await _getAlbumViewID(BaseItemId(parent.id));
            }
          }
        } catch (e) {
          _syncLogger.info("Error downloading children for ${item.name}: $e");
          rethrow;
        }
        // TODO alert user if image deduplication is broken.
        if ((item.blurHash ?? item.imageId) != null) {
          infoChildren.add(DownloadStub.fromItem(type: DownloadItemType.image, item: item));
        }
        if (parent.baseItemType == BaseItemDtoType.album) {
          // If we are an album, add the album artists as info children
          try {
            var collectionChildren = await Future.wait(
              (item.albumArtists?.map((e) => e.id) ?? []).map(
                (e) => _getCollectionInfo(e, DownloadItemType.collection, false),
              ),
            );
            infoChildren.addAll(collectionChildren.nonNulls);
          } catch (e) {
            _syncLogger.info("Failed to download metadata for ${item.name}: $e");
            rethrow;
          }
        }

      case DownloadItemType.track:
        var item = newBaseItem ?? parent.baseItem!;
        if ((item.blurHash ?? item.imageId) != null) {
          requiredChildren.add(DownloadStub.fromItem(type: DownloadItemType.image, item: item));
        }

        // Check if animated cover and vertical background video exist by making requests to the plugin endpoints
        final animatedMusicService = GetIt.instance<AnimatedMusicService>();

        // Check for animated cover
        final hasAnimatedCover = await animatedMusicService.hasAnimatedCover(item.id);
        if (hasAnimatedCover) {
          requiredChildren.add(DownloadStub.fromItem(type: DownloadItemType.animatedCover, item: item));
        }

        // Check for vertical background video
        final hasVerticalBackground = await animatedMusicService.hasVerticalBackgroundVideo(item.id);
        if (hasVerticalBackground) {
          requiredChildren.add(DownloadStub.fromItem(type: DownloadItemType.verticalBackgroundVideo, item: item));
        }

        if (viewId == null && item.albumId != null) {
          isarParent ??= _isar.downloadItems.getSync(parent.isarId);
          if (isarParent?.viewId == null) {
            // if both sync viewId and isar viewId are null, fetch from server
            viewId = await _getAlbumViewID(item.albumId!);
          }
        }
        if (asRequired) {
          List<BaseItemId> collectionIds = [];
          collectionIds.addAll(item.genreItems?.map((e) => e.id) ?? []);
          collectionIds.addAll(item.artistItems?.map((e) => e.id) ?? []);
          if (item.albumId != null) {
            collectionIds.add(item.albumId!);
          }
          try {
            var collectionChildren = await Future.wait(
              collectionIds.map((e) => _getCollectionInfo(e, DownloadItemType.collection, false)),
            );
            infoChildren.addAll(collectionChildren.nonNulls);
          } catch (e) {
            _syncLogger.info("Failed to download metadata for ${item.name}: $e");
            rethrow;
          }
        }
      case DownloadItemType.image:
      case DownloadItemType.animatedCover:
      case DownloadItemType.verticalBackgroundVideo:
        break;
      case DownloadItemType.anchor:
        var children = _isar.downloadItems.filter().requiredBy((q) => q.isarIdEqualTo(parent.isarId)).findAllSync();
        requiredChildren.addAll(children);
        // If trackOfflineFavorites is set and we have downloads, add an info link
        // to the favorites collection, otherwise remove it.
        if (children.isNotEmpty && FinampSettingsHelper.finampSettings.trackOfflineFavorites) {
          infoChildren.add(DownloadStub.fromFinampCollection(FinampCollection(type: FinampCollectionType.favorites)));
        }
        updateRequiredChildren = false;
      case DownloadItemType.finampCollection:
        try {
          if (asRequired) {
            orderedChildItems = await _getFinampCollectionChildren(parent);
            if (parent.finampCollection!.type == FinampCollectionType.allPlaylistsMetadata) {
              infoChildren.addAll(orderedChildItems);
            } else {
              requiredChildren.addAll(orderedChildItems);
            }
          } else {
            switch (parent.finampCollection!.type) {
              case FinampCollectionType.favorites:
                orderedChildItems = await _getFinampCollectionChildren(parent);
              case var type:
                throw "FinampCollection of type $type was info linked, cannot handle";
            }
          }
        } catch (e) {
          _syncLogger.info("Error downloading children for finampCollection ${parent.name}: $e");
          rethrow;
        }
    }

    //
    // Update item with latest metadata and previously calculated children.
    // For the anchor, just fetch current children.
    //
    // Allow database work to be scheduled instead of immediately processing
    // once network requests come back.
    await SchedulerBinding.instance.scheduleTask(() async {
      DownloadItem? canonParent;
      _isar.writeTxnSync(() {
        canonParent = _isar.downloadItems.getSync(parent.isarId);
        if (canonParent == null) {
          throw StateError("_syncDownload called on missing node ${parent.id}");
        }
        try {
          var newParent = canonParent!.copyWith(
            item: newBaseItem,
            viewId: viewId,
            orderedChildItems: orderedChildItems,
            // Force an update if we are in a downloads repair and haven't already processed this node
            forceCopy: _downloadsService.forceFullSync && (!asRequired || !infoCompleted.contains(parent.isarId)),
          );
          // copyWith returns null if no updates to important fields are needed
          if (newParent != null) {
            _syncLogger.fine("Updating BaseItemDto for ${parent.name}");
            _isar.downloadItems.putSync(newParent, saveLinks: false);
            canonParent = newParent;
          }
        } catch (e) {
          _syncLogger.warning(e);
        }

        viewId ??= canonParent!.viewId;

        // Run appropriate _updateChildren calls and store changes to allow skipping
        // unneeded syncs when nothing changed
        // _updatechildren output is inserted nodes, linked nodes, unlinked nodes
        (Set<int>, Set<int>, Set<int>) requiredChanges = ({}, {}, {});
        (Set<int>, Set<int>, Set<int>) infoChanges = ({}, {}, {});
        if (asRequired && updateRequiredChildren) {
          requiredChanges = _updateChildren(canonParent!, true, requiredChildren);
          infoChanges = _updateChildren(canonParent!, false, infoChildren);
        } else if (canonParent!.type == DownloadItemType.track) {
          // For info only tracks, we put image link into required so that we can delete
          // all info links in _syncDelete, so if not processing as required only
          // update that and ignore info links
          requiredChanges = _updateChildren(canonParent!, true, requiredChildren);
        } else {
          infoChanges = _updateChildren(canonParent!, false, infoChildren);
        }

        if (FinampSettingsHelper.finampSettings.preferQuickSyncs &&
            !_downloadsService.forceFullSync &&
            canonParent!.type == DownloadItemType.collection &&
            !canonParent!.baseItemType.expectChangesInChildren &&
            canonParent!.state == DownloadItemState.complete) {
          // When quicksyncing, unchanged tracks/albums do not need to be resynced.
          // Items we just linked may need download settings updated.
          var quicksyncRequiredIds = requiredChanges.$1.union(requiredChanges.$2);
          var quicksyncInfoIds = infoChanges.$1.union(infoChanges.$2);
          addAll(quicksyncRequiredIds, quicksyncInfoIds.difference(quicksyncRequiredIds), viewId);
        } else {
          addAll(
            requiredChildren.map((e) => e.isarId),
            infoChildren.difference(requiredChildren).map((e) => e.isarId),
            viewId,
          );
        }
        // If we are a collection, move out of syncFailed because we just completed a
        // successful sync.  tracks/images will be moved out by _initiateDownload.
        // If our linked children just changed, recalculate state with new children.
        if (!canonParent!.type.hasFiles &&
            (canonParent!.state == DownloadItemState.syncFailed ||
                requiredChanges.$1.isNotEmpty ||
                requiredChanges.$2.isNotEmpty ||
                requiredChanges.$3.isNotEmpty ||
                infoChanges.$1.isNotEmpty ||
                infoChanges.$2.isNotEmpty ||
                infoChanges.$3.isNotEmpty)) {
          _downloadsService.syncItemState(canonParent!, removeSyncFailed: true);
        }

        // sync download settings on all newly required children.  Newly inserted children
        // may be skipped, as they inherit the parent settings.  Children who exactly match
        // the parent's download settings already may be skipped.
        for (var child in _isar.downloadItems.getAllSync(requiredChanges.$2.toList()).nonNulls) {
          if (child.syncTranscodingProfile != canonParent!.syncTranscodingProfile) {
            _downloadsService.syncItemDownloadSettings(child);
          }
        }
      });

      //
      // Download item files if needed
      //
      if (canonParent != null && canonParent!.type.hasFiles && asRequired) {
        if (canonParent!.syncDownloadLocation == null) {
          _syncLogger.severe("could not download ${parent.name}, no download location found.");
          _isar.writeTxnSync(() {
            _downloadsService.updateItemState(canonParent!, DownloadItemState.failed);
          });
        } else {
          await _initiateDownload(canonParent!);
        }
      }
      // Set priority high to prevent stalling, but lower than creating network requests
    }, Priority.animation);
  }

  /// This updates the children of an item to exactly match the given set.
  /// Children not currently present in Isar are added.  Unlinked items
  /// are added to delete buffer to later have [_syncDelete] run on them.
  /// links argument should be parent.info or parent.requires.  Returns list of
  /// newly linked inserted nodes, list of newly linked nodes, and list of newly
  /// unlinked nodes.
  /// Used within [_syncDownload].
  /// This should only be called inside an isar write transaction.
  (Set<int>, Set<int>, Set<int>) _updateChildren(DownloadItem parent, bool required, Set<DownloadStub> children) {
    IsarLinks<DownloadItem> links = required ? parent.requires : parent.info;

    var oldChildIds = (links.filter().isarIdProperty().findAllSync()).toSet();
    var newChildIds = children.map((e) => e.isarId).toSet();
    var childIdsToUnlink = oldChildIds.difference(newChildIds);
    var missingChildIds = newChildIds.difference(oldChildIds);
    var childrenToUnlink = (_isar.downloadItems.getAllSync(childIdsToUnlink.toList())).nonNulls.toList();
    // anyOf filter allows all objects when given empty list, but we want no objects
    var childIdsToLink = (missingChildIds.isEmpty)
        ? <int>[]
        : _isar.downloadItems
              .where()
              .anyOf(missingChildIds, (q, int id) => q.isarIdEqualTo(id))
              .isarIdProperty()
              .findAllSync();
    // This is only used for IsarLink.update, which only cares about ID, so stubs are fine
    var childrenToLink = children
        .where((element) => childIdsToLink.contains(element.isarId))
        .map((e) => e.asItem(null))
        .toList();
    var childrenToPutAndLink = children
        .where((element) => missingChildIds.contains(element.isarId) && !childIdsToLink.contains(element.isarId))
        .map((e) => e.asItem(parent.syncTranscodingProfile))
        .toList();
    assert(childIdsToLink.length + childrenToPutAndLink.length == missingChildIds.length);
    assert(missingChildIds.length + oldChildIds.length - childrenToUnlink.length == children.length);
    if (oldChildIds.isNotEmpty && newChildIds.isEmpty) {
      _syncLogger.warning("Unlinking all ${required ? "required" : "info"} children of ${parent.name}");
    }
    _isar.downloadItems.putAllSync(childrenToPutAndLink, saveLinks: false);
    _downloadsService.deleteBuffer.addAll(childrenToUnlink.map((e) => e.isarId));
    if (missingChildIds.isNotEmpty || childrenToUnlink.isNotEmpty) {
      links.updateSync(link: childrenToLink + childrenToPutAndLink, unlink: childrenToUnlink);
      // Collection download state may need changing with different children
      _downloadsService.syncItemState(parent);
    }
    return (childrenToPutAndLink.map((e) => e.isarId).toSet(), childIdsToLink.toSet(), childIdsToUnlink);
  }

  /// Get BaseItemDto from the given collection ID.  Tries local cache, then
  /// Isar, then requests data from jellyfin in a batch with other calls
  /// to this method.  Used within [_syncDownload].
  Future<DownloadStub?> _getCollectionInfo(BaseItemId id, DownloadItemType type, bool forceServer) async {
    if (_metadataCache.containsKey(id)) {
      return _metadataCache[id];
    }
    Completer<DownloadStub?> itemFetch = Completer();
    try {
      DownloadStub? item;
      if (!forceServer) {
        item = _isar.downloadItems.getSync(DownloadStub.getHash(id.raw, type));
        if (item != null) {
          return item;
        }
      }
      _metadataCache[id] = itemFetch.future;
      item = await _jellyfinApiData
          .getItemByIdBatched(id, "${_jellyfinApiData.defaultFields},sortName,MediaSources,MediaStreams")
          .then((value) => value == null ? null : DownloadStub.fromItem(item: value, type: type));
      _downloadsService.resetConnectionErrors();
      itemFetch.complete(item);
      return itemFetch.future;
    } catch (e) {
      // Retries should try connecting again instead of re-using error
      unawaited(_metadataCache.remove(id));
      itemFetch.completeError(e);
      _downloadsService.incrementConnectionErrors();
      return itemFetch.future;
    }
  }

  // These cache downloaded metadata during _syncDownload
  Map<BaseItemId, Future<DownloadStub?>> _metadataCache = {};
  Map<String, Future<List<String>>> _childCache = {};

  /// Get ordered child items for the given collection DownloadStub.  Tries local
  /// cache, then requests data from jellyfin.  Used within [_syncDownload].
  Future<List<DownloadStub>> _getCollectionChildren(DownloadStub parent) async {
    DownloadItemType childType;
    BaseItemDtoType childFilter;
    String? fields;
    String? sortOrder;
    assert(parent.type == DownloadItemType.collection);
    assert(parent.baseItemType.downloadType == DownloadItemType.collection);
    switch (parent.baseItemType) {
      case BaseItemDtoType.playlist || BaseItemDtoType.album:
        childType = DownloadItemType.track;
        childFilter = BaseItemDtoType.track;
        fields = "${_jellyfinApiData.defaultFields},MediaSources,MediaStreams,SortName";
        sortOrder = "ParentIndexNumber,IndexNumber,SortName";
      case BaseItemDtoType.artist || BaseItemDtoType.genre || BaseItemDtoType.library:
        childType = DownloadItemType.collection;
        childFilter = BaseItemDtoType.album;
        fields = "${_jellyfinApiData.defaultFields},SortName";
      case _:
        _syncLogger.severe("Unknown collection type ${parent.baseItemType} for ${parent.name}");
        return Future.value([]);
    }
    var item = parent.baseItem!;

    if (_childCache.containsKey(item.id.raw)) {
      var childIds = await _childCache[item.id.raw]!;
      return Future.wait(
        childIds.map((e) => _metadataCache[BaseItemId(e)]).nonNulls,
      ).then((value) => value.nonNulls.toList());
    }
    Completer<List<String>> itemFetch = Completer();
    // This prevents errors in itemFetch being reported as unhandled.
    // They are handled by original caller in rethrow.
    unawaited(itemFetch.future.then((_) => null, onError: (_) => null));
    try {
      _childCache[item.id.raw] = itemFetch.future;
      var childItems =
          await _jellyfinApiData.getItems(
            parentItem: item,
            includeItemTypes: childFilter.jellyfinName,
            sortBy: sortOrder,
            fields: fields,
          ) ??
          [];
      _downloadsService.resetConnectionErrors();
      var childStubs = childItems.map((e) => DownloadStub.fromItem(type: childType, item: e)).toList();
      // If we are a library, we need to get orphan tracks to download in addition to
      // tracks which are contained in albums.
      if (parent.baseItemType == BaseItemDtoType.library) {
        var trackChildItems =
            await _jellyfinApiData.getItems(
              parentItem: item,
              includeItemTypes: BaseItemDtoType.track.jellyfinName,
              recursive: false,
              fields: "${_jellyfinApiData.defaultFields},MediaSources,MediaStreams,SortName",
            ) ??
            [];
        childItems.addAll(trackChildItems);
        var trackChildStubs = trackChildItems.map((e) => DownloadStub.fromItem(type: DownloadItemType.track, item: e));
        childStubs.addAll(trackChildStubs);
      }
      // LEGACY - ARTISTS AND GENRES ARE NOW FINAMP COLLECTIONS
      // If we are an artist, we also need to add the tracks where the artist
      // only is a performing artist, but not an album artist
      // We might get some overlap because we often see albumartist = performingartist,
      // but they will get filtered out later
      if (parent.baseItemType == BaseItemDtoType.artist) {
        var artistTrackChildItems =
            await _jellyfinApiData.getItems(
              parentItem: item,
              includeItemTypes: BaseItemDtoType.track.jellyfinName,
              filters: "Artist=${parent.name}",
              artistType: ArtistType.artist,
              fields: "${_jellyfinApiData.defaultFields},MediaSources,MediaStreams,SortName",
            ) ??
            [];
        var artistTrackChildStubs = artistTrackChildItems.map(
          (e) => DownloadStub.fromItem(type: DownloadItemType.track, item: e),
        );
        childStubs.addAll(artistTrackChildStubs);
      }
      itemFetch.complete(childItems.map((e) => e.id.raw).toList());
      for (var element in childStubs) {
        _metadataCache[BaseItemId(element.id)] = Future.value(element);
      }
      return childStubs;
    } catch (e) {
      if (e is Response && e.statusCode == 404) {
        _syncLogger.warning("Got 404 while fetching children of ${parent.name}.");
        throw MissingServerItemException(parent);
      } else {
        // Retries should try connecting again instead of re-using error
        unawaited(_childCache.remove(item.id.raw));
        itemFetch.completeError(e);
        _downloadsService.incrementConnectionErrors();
        rethrow;
      }
    }
  }

  /// Get ordered child items for the given finampCollection DownloadStub, like
  /// favorites.  Used within [_syncDownload].
  Future<List<DownloadStub>> _getFinampCollectionChildren(DownloadStub parent) async {
    assert(parent.type == DownloadItemType.finampCollection);
    FinampCollection collection = parent.finampCollection!;
    final String fields = "${_jellyfinApiData.defaultFields},MediaSources,MediaStreams,SortName";
    try {
      List<BaseItemDto> outputItems;
      DownloadItemType? typeOverride;
      switch (collection.type) {
        case FinampCollectionType.favorites:
          outputItems =
              await _jellyfinApiData.getItems(
                includeItemTypes: "Audio,MusicAlbum,Playlist",
                filters: "IsFavorite",
                fields: fields,
              ) ??
              [];
          // Artists use a different endpoint, so request those separately
          outputItems.addAll(
            await _jellyfinApiData.getItems(includeItemTypes: "MusicArtist", filters: "IsFavorite", fields: fields) ??
                [],
          );
        case FinampCollectionType.allPlaylists:
        case FinampCollectionType.allPlaylistsMetadata:
          outputItems = await _jellyfinApiData.getItems(includeItemTypes: "Playlist", fields: fields) ?? [];
        case FinampCollectionType.latest5Albums:
          outputItems =
              await _jellyfinApiData.getLatestItems(includeItemTypes: "MusicAlbum", limit: 5, fields: fields) ?? [];
        case FinampCollectionType.libraryImages:
          outputItems =
              await _jellyfinApiData.getItems(
                parentItem: collection.library!,
                includeItemTypes: "MusicAlbum",
                fields: fields,
              ) ??
              [];
          // Playlists need to be fetched without libraries
          outputItems.addAll(await _jellyfinApiData.getItems(includeItemTypes: "Playlist", fields: fields) ?? []);
          // Artists use a different endpoint, so request those separately
          outputItems.addAll(
            await _jellyfinApiData.getItems(
                  parentItem: collection.library!,
                  includeItemTypes: "MusicArtist",
                  fields: fields,
                ) ??
                [],
          );
          // Genres use a different endpoint, so request those separately
          outputItems.addAll(
            await _jellyfinApiData.getItems(
                  parentItem: collection.library!,
                  includeItemTypes: "MusicGenre",
                  fields: fields,
                ) ??
                [],
          );
          outputItems.removeWhere((element) => element.imageId == null);
          typeOverride = DownloadItemType.image;
        case FinampCollectionType.collectionWithLibraryFilter:
          var item = collection.item!;
          var baseItemType = BaseItemDtoType.fromItem(collection.item!);
          outputItems =
              await _jellyfinApiData.getItems(
                parentItem: (baseItemType == BaseItemDtoType.genre) ? collection.library! : item,
                libraryFilter: (baseItemType == BaseItemDtoType.artist) ? collection.library! : null,
                genreFilter: (baseItemType == BaseItemDtoType.genre) ? item : null,
                includeItemTypes: BaseItemDtoType.album.jellyfinName,
                fields: fields,
              ) ??
              [];
          // If we are an artist, we also need to add the tracks where the artist
          // only is a performing artist, but not an album artist
          // We might get some overlap because we often see albumartist = performingartist,
          // but they will get filtered out later
          if (baseItemType == BaseItemDtoType.artist) {
            outputItems.addAll(
              await _jellyfinApiData.getItems(
                    parentItem: item,
                    libraryFilter: collection.library!,
                    includeItemTypes: BaseItemDtoType.track.jellyfinName,
                    filters: "Artist=${parent.name}",
                    artistType: ArtistType.artist,
                    fields: fields,
                  ) ??
                  [],
            );
          }
      }
      _downloadsService.resetConnectionErrors();
      var stubList = outputItems
          .map((e) => DownloadStub.fromItem(item: e, type: typeOverride ?? e.downloadType))
          .toList();
      for (var element in stubList) {
        _metadataCache[BaseItemId(element.id)] = Future.value(element);
      }
      return stubList;
    } catch (e) {
      if (e is Response && e.statusCode == 404) {
        _syncLogger.warning("Got 404 while fetching children of ${parent.name}.");
        throw MissingServerItemException(parent);
      } else {
        _downloadsService.incrementConnectionErrors();
        rethrow;
      }
    }
  }

  /// Gets the View/Library ID for the given album ID by fetching album children
  /// of all know views.  Used by [_syncDownload] to assign libraries to items
  /// in playlists or finampCollections.
  Future<BaseItemId?> _getAlbumViewID(BaseItemId albumId) async {
    final userHelper = GetIt.instance<FinampUserHelper>();
    for (var view in (userHelper.currentUser?.views.values ?? <BaseItemDto>[])) {
      var children = await _getCollectionChildren(DownloadStub.fromItem(type: DownloadItemType.collection, item: view));
      // Iterable.nonNulls does not seem to work here, I don't know why.
      var childIds = children.map<BaseItemId?>((e) => e.baseItem?.id).where((id) => id != null).toList();
      if (childIds.contains(albumId)) {
        return view.id;
      }
    }
    return null;
  }

  /// If items on the server are deleted or updated, it is possible that the BaseItemDto stored in the image download is
  /// no longer a valid parent for the image, as identified by blurHash??imageId.  This attempts to select a new parent
  /// with a valid BaseItemDto referring to the given image.
  Future<BaseItemDto?> _updateImageBaseItem(DownloadStub parent) async {
    _syncLogger.finer("Attempting to update image item id for ${parent.name}");
    final localParents = _isar.downloadItems
        .filter()
        .requires((q) => q.isarIdEqualTo(parent.isarId))
        .or()
        .info((q) => q.isarIdEqualTo(parent.isarId))
        .findAllSync();
    final serverParents = await Future.wait(
      localParents.where((x) => x.type.requiresItem).map((x) => _getCollectionInfo(x.baseItem!.id, x.type, true)),
    );
    final validParent = serverParents.firstWhereOrNull(
      (x) => (x?.baseItem?.blurHash ?? x?.baseItem?.imageId) == parent.id,
    );
    return validParent?.baseItem;
  }

  /// This returns whether the given item needs its metadata refreshed from the server.
  /// If modifying to add another required field, the requested fields to be downloaded
  /// in _getCollectionInfo and _getCollectionChildren must be updated.  Additionally,
  /// DownloadItem.copyWith must be updated to preserve the field, and BaseItemDto.mostlyEqual
  /// must be updated to check the field when determining equality.
  bool _needsMetadataUpdate(DownloadStub stub) {
    assert(stub.type.requiresItem);

    // childCount is expected to change frequently for playlists, so we
    // always fetch a fresh copy from the server to check if the metadata
    // needs updating, even when quickSyncing.
    if (stub.type == DownloadItemType.collection && stub.baseItemType == BaseItemDtoType.playlist) {
      return true;
    }
    if (stub.baseItem?.sortName == null) {
      return true;
    }
    if (stub.type == DownloadItemType.track &&
        (stub.baseItem?.mediaSources == null || stub.baseItem?.mediaStreams == null)) {
      return true;
    }
    return false;
  }

  /// Ensures the given node is downloaded.  Called on all required nodes with files
  /// by [_syncDownload].  Items enqueued/downloading/failed are validated and cleaned
  /// up before re-initiating download if needed.
  Future<void> _initiateDownload(DownloadItem item) async {
    switch (item.state) {
      case DownloadItemState.complete:
        return;
      case DownloadItemState.notDownloaded:
        break;
      case DownloadItemState.enqueued: //fall through
      case DownloadItemState.downloading:
        if (await _downloadsService.downloadTaskQueue.validateQueued(item)) {
          return;
        }
        await _downloadsService.deleteBuffer.deleteDownload(item);
      case DownloadItemState.failed:
      case DownloadItemState.syncFailed:
      case DownloadItemState.needsRedownload:
      case DownloadItemState.needsRedownloadComplete:
        await _downloadsService.deleteBuffer.deleteDownload(item);
    }

    switch (item.type) {
      case DownloadItemType.track:
        return _downloadTrack(item);
      case DownloadItemType.image:
        return _downloadImage(item);
      case DownloadItemType.animatedCover:
        return _downloadAnimatedCover(item);
      case DownloadItemType.verticalBackgroundVideo:
        return _downloadVerticalBackgroundVideo(item);
      case _:
        throw StateError("???");
    }
  }

  /// Removes unsafe characters from file names.  Used by [_downloadTrack] and
  /// [_downloadImage] for human readable download locations.
  String? _filesystemSafe(String? unsafe) => unsafe?.replaceAll(RegExp(r'[/?<>:*|.\\"]'), "_");

  /// Builds the subdirectory ($1) and base filename ($2) for tracks
  /// Used by [_downloadTrack] for a consistent directory structure.
  (String, String) _getTrackDownloadPath(DownloadItem downloadItem) {
    assert(downloadItem.type == DownloadItemType.track);
    var downloadLocation = downloadItem.syncDownloadLocation!;
    var item = downloadItem.baseItem!;
    String fileName;
    String subDirectory;
    if (downloadLocation.useHumanReadableNames) {
      final indexNumber = item.indexNumber != null ? "[${item.indexNumber}] " : "";
      final artist = (item.artists?.isNotEmpty ?? false) ? "${item.artists?.first} - " : "";
      final originalFilename = item.mediaSources?.firstWhere((e) => e.type.toLowerCase() == "default").name;
      fileName = _filesystemSafe(
        "${originalFilename ?? "$indexNumber$artist${item.name}"}_${item.id.raw.substring(0, 8)}",
      )!;
      final pathSegments = [_filesystemSafe(item.albumArtist), _filesystemSafe(item.album)];
      // if (item.parentIndexNumber != null) {
      //   pathSegments.add(_filesystemSafe("Disc ${item.parentIndexNumber}"));
      // }
      subDirectory = path_helper.joinAll(pathSegments.nonNulls);
      if (path_helper.split(downloadLocation.currentPath).lastOrNull?.toLowerCase() != "finamp") {
        subDirectory = path_helper.join("Finamp", subDirectory);
      }
    } else {
      fileName = item.id.raw;
      subDirectory = FINAMP_BASE_DOWNLOAD_DIRECTORY;
    }

    if (downloadLocation.baseDirectory.baseDirectory == BaseDirectory.root) {
      subDirectory = path_helper.join(downloadLocation.currentPath, subDirectory);
    }
    return (subDirectory, fileName);
  }

  /// Prepares for downloading of a given track by filling in the path information
  /// and media sources, and marking item as enqueued in isar.
  Future<void> _downloadTrack(DownloadItem downloadItem) async {
    assert(downloadItem.type == DownloadItemType.track && downloadItem.syncDownloadLocation != null);
    var item = downloadItem.baseItem!;

    if (downloadItem.baseItem!.mediaSources == null && FinampSettingsHelper.finampSettings.isOffline) {
      _isar.writeTxnSync(() {
        var canonItem = _isar.downloadItems.getSync(downloadItem.isarId);
        if (canonItem == null) {
          throw StateError("Node missing while failing offline download for ${downloadItem.name}: $canonItem");
        }
        _downloadsService.updateItemState(canonItem, DownloadItemState.failed);
      });
    }
    // At this point the baseItem should always have the needed attributes
    List<MediaSourceInfo>? mediaSources = downloadItem.baseItem?.mediaSources;
    List<MediaStream>? mediaStreams = downloadItem.baseItem?.mediaStreams;

    // Container must be accurate because unknown container names break iOS playback
    String? container = downloadItem.syncTranscodingProfile?.codec.container ?? mediaSources?.firstOrNull?.container;
    String extension = container == null ? "" : ".${_filesystemSafe(container)}";

    String baseFilename;
    String subDirectory;
    (subDirectory, baseFilename) = _getTrackDownloadPath(downloadItem);
    String fileName = "$baseFilename$extension";

    // fetch lyrics if track has lyrics
    LyricDto? lyrics;
    if (mediaStreams?.any((element) => element.type == "Lyric") ?? false) {
      _syncLogger.finer("Fetching lyrics for ${item.name}");
      try {
        lyrics = await _jellyfinApiData.getLyrics(itemId: item.id);
        _syncLogger.finer("Fetched lyrics for ${item.name}");
      } catch (e) {
        _syncLogger.warning("Failed to fetch lyrics for ${item.name}.");
        //!!! don't fail download if local metadata is outdated and server has no lyrics
        if (e is Response && e.statusCode == 404) {
          _syncLogger.finer("No lyrics for ${item.name}");
        } else {
          _syncLogger.warning("Failed to fetch lyrics for ${item.name}.");
          rethrow;
        }
      }
    } else {
      _syncLogger.finer("No lyrics for ${item.name}");
    }

    _isar.writeTxnSync(() {
      DownloadItem? canonItem = _isar.downloadItems.getSync(downloadItem.isarId);
      if (canonItem == null) {
        _syncLogger.severe("Download metadata ${downloadItem.id} missing after download starts");
        throw StateError("Could not save download task id");
      }
      if (canonItem.state != DownloadItemState.notDownloaded) {
        _syncLogger.warning("Download state incorrect while enqueueing ${canonItem.name}");
        return;
      }
      canonItem.path = path_helper.join(subDirectory, fileName);
      canonItem.fileTranscodingProfile = canonItem.syncTranscodingProfile;
      if (canonItem.state != DownloadItemState.notDownloaded) {
        _syncLogger.severe("Track ${canonItem.name} changed state to ${canonItem.state} while initiating download.");
      } else {
        _downloadsService.updateItemState(canonItem, DownloadItemState.enqueued, alwaysPut: true);
        if (lyrics != null) {
          final lyricsItem = DownloadedLyrics.fromItem(isarId: canonItem.isarId, item: lyrics);
          _isar.downloadedLyrics.putSync(lyricsItem, saveLinks: false);
        }
      }
    });
  }

  /// Prepares for downloading of a given image by filling in the path information
  /// and marking item as enqueued in isar.
  Future<void> _downloadImage(DownloadItem downloadItem) async {
    assert(downloadItem.type == DownloadItemType.image && downloadItem.syncDownloadLocation != null);
    var downloadLocation = downloadItem.syncDownloadLocation!;

    String subDirectory = FINAMP_BASE_IMAGES_DIRECTORY;

    if (downloadLocation.useHumanReadableNames) {
      if (path_helper.split(downloadLocation.currentPath).lastOrNull?.toLowerCase() != "finamp") {
        subDirectory = path_helper.join("Finamp", subDirectory);
      }
    }
    if (downloadLocation.baseDirectory.baseDirectory == BaseDirectory.root) {
      subDirectory = path_helper.join(downloadLocation.currentPath, subDirectory);
    }
    final fileName = "${Uuid().v4()}.image";

    _isar.writeTxnSync(() {
      DownloadItem? canonItem = _isar.downloadItems.getSync(downloadItem.isarId);
      if (canonItem == null) {
        _syncLogger.severe("Download metadata ${downloadItem.id} missing after download starts");
        throw StateError("Could not save download task id");
      }
      if (canonItem.state != DownloadItemState.notDownloaded) {
        _syncLogger.severe("Download state incorrect while enqueueing ${canonItem.name}");
        return;
      }
      canonItem.path = path_helper.join(subDirectory, fileName);
      canonItem.fileTranscodingProfile = canonItem.syncTranscodingProfile;
      if (canonItem.state != DownloadItemState.notDownloaded) {
        _syncLogger.severe("Image ${canonItem.name} changed state to ${canonItem.state} while initiating download.");
      } else {
        _downloadsService.updateItemState(canonItem, DownloadItemState.enqueued, alwaysPut: true);
      }
    });
  }

  /// Prepares for downloading of an animated cover by filling in the path information
  /// and marking item as enqueued in isar.
  Future<void> _downloadAnimatedCover(DownloadItem downloadItem) async {
    assert(downloadItem.type == DownloadItemType.animatedCover && downloadItem.syncDownloadLocation != null);
    var item = downloadItem.baseItem!;
    var downloadLocation = downloadItem.syncDownloadLocation!;

    String subDirectory;
    if (downloadLocation.useHumanReadableNames) {
      subDirectory = path_helper.join("Finamp", _filesystemSafe(item.albumArtist));
    } else {
      subDirectory = "animated_covers";
    }

    if (downloadLocation.baseDirectory.baseDirectory == BaseDirectory.root) {
      subDirectory = path_helper.join(downloadLocation.currentPath, subDirectory);
    }

    // Always use a new, unique filename when creating animated cover downloads
    final fileName = "${const Uuid().v4()}.animated_cover";

    _isar.writeTxnSync(() {
      DownloadItem? canonItem = _isar.downloadItems.getSync(downloadItem.isarId);
      if (canonItem == null) {
        _syncLogger.severe("Download metadata ${downloadItem.id} missing after download starts");
        throw StateError("Could not save download task id");
      }
      if (canonItem.state != DownloadItemState.notDownloaded) {
        _syncLogger.severe("Download state incorrect while enqueueing ${canonItem.name}");
        return;
      }
      canonItem.path = path_helper.join(subDirectory, fileName);
      canonItem.fileTranscodingProfile = canonItem.syncTranscodingProfile;
      if (canonItem.state != DownloadItemState.notDownloaded) {
        _syncLogger.severe(
          "Animated cover ${canonItem.name} changed state to ${canonItem.state} while initiating download.",
        );
      } else {
        _downloadsService.updateItemState(canonItem, DownloadItemState.enqueued, alwaysPut: true);
      }
    });
  }

  /// Prepares for downloading of a vertical background video by filling in the path information
  /// and marking item as enqueued in isar.
  Future<void> _downloadVerticalBackgroundVideo(DownloadItem downloadItem) async {
    assert(downloadItem.type == DownloadItemType.verticalBackgroundVideo && downloadItem.syncDownloadLocation != null);
    var item = downloadItem.baseItem!;
    var downloadLocation = downloadItem.syncDownloadLocation!;

    String subDirectory;
    if (downloadLocation.useHumanReadableNames) {
      subDirectory = path_helper.join("Finamp", _filesystemSafe(item.albumArtist));
    } else {
      subDirectory = "vertical_background_videos";
    }

    if (downloadLocation.baseDirectory.baseDirectory == BaseDirectory.root) {
      subDirectory = path_helper.join(downloadLocation.currentPath, subDirectory);
    }

    // Always use a new, unique filename when creating vertical video downloads
    final fileName = "${const Uuid().v4()}.vertical_background_video";

    _isar.writeTxnSync(() {
      DownloadItem? canonItem = _isar.downloadItems.getSync(downloadItem.isarId);
      if (canonItem == null) {
        _syncLogger.severe("Download metadata ${downloadItem.id} missing after download starts");
        throw StateError("Could not save download task id");
      }
      if (canonItem.state != DownloadItemState.notDownloaded) {
        _syncLogger.severe("Download state incorrect while enqueueing ${canonItem.name}");
        return;
      }
      canonItem.path = path_helper.join(subDirectory, fileName);
      canonItem.fileTranscodingProfile = canonItem.syncTranscodingProfile;
      if (canonItem.state != DownloadItemState.notDownloaded) {
        _syncLogger.severe(
          "Vertical background video ${canonItem.name} changed state to ${canonItem.state} while initiating download.",
        );
      } else {
        _downloadsService.updateItemState(canonItem, DownloadItemState.enqueued, alwaysPut: true);
      }
    });
  }
}
