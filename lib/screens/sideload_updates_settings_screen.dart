import 'dart:async';
import 'dart:io';

import 'package:finamp/components/finamp_app_bar_back_button.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/sideload_update_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Sideload OTA settings: Auto/Manual, time of day, Check now, Android setup.
class SideloadUpdatesSettingsScreen extends ConsumerStatefulWidget {
  const SideloadUpdatesSettingsScreen({super.key});

  static const routeName = '/settings/sideload-updates';

  @override
  ConsumerState<SideloadUpdatesSettingsScreen> createState() =>
      _SideloadUpdatesSettingsScreenState();
}

class _SideloadUpdatesSettingsScreenState
    extends ConsumerState<SideloadUpdatesSettingsScreen> {
  PackageInfo? _packageInfo;
  Map<String, dynamic>? _androidSetup;
  Map<String, dynamic>? _workerStatus;
  bool _checking = false;
  String? _statusMessage;
  final _manifestController = TextEditingController();

  SideloadUpdateService get _service => GetIt.instance<SideloadUpdateService>();

  @override
  void initState() {
    super.initState();
    _manifestController.text =
        FinampSettingsHelper.finampSettings.sideloadManifestUrl ?? '';
    unawaited(_reload());
  }

  @override
  void dispose() {
    _manifestController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final info = await PackageInfo.fromPlatform();
    Map<String, dynamic>? setup;
    Map<String, dynamic>? worker;
    if (Platform.isAndroid) {
      setup = await _service.androidSetupStatus();
      worker = await _service.nativeWorkerStatus();
    }
    if (!mounted) return;
    setState(() {
      _packageInfo = info;
      _androidSetup = setup;
      _workerStatus = worker;
    });
  }

  Future<void> _checkNow({bool install = true}) async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _statusMessage = null;
    });
    try {
      final result = await _service.checkForUpdate(
        installIfReady: install && Platform.isAndroid,
        forceMetered: FinampSettingsHelper.finampSettings.sideloadAllowCellular,
      );
      if (!mounted) return;
      setState(() {
        _statusMessage = _describe(result);
      });
      if (Platform.isIOS &&
          result.outcome == SideloadCheckOutcome.updateAvailable &&
          result.manifest != null) {
        await _showIosUpdateSheet(result.manifest!);
      }
      await _reload();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  String _describe(SideloadCheckResult result) {
    final m = result.manifest;
    switch (result.outcome) {
      case SideloadCheckOutcome.upToDate:
        return 'Up to date${m != null ? ' (${m.version})' : ''}';
      case SideloadCheckOutcome.updateAvailable:
        return 'Update available: ${m?.version} (build ${m?.build})';
      case SideloadCheckOutcome.downloaded:
        return 'Downloaded ${m?.version}';
      case SideloadCheckOutcome.installed:
        return result.message ?? 'Installed ${m?.version}';
      case SideloadCheckOutcome.deferredPlaying:
        return result.message ?? 'Waiting until playback is idle';
      case SideloadCheckOutcome.skippedMetered:
        return result.message ?? 'Waiting for Wi‑Fi';
      case SideloadCheckOutcome.needPermission:
        return result.message ?? 'Allow Install unknown apps';
      case SideloadCheckOutcome.needUserConfirm:
        return result.message ?? 'Complete one-time Install';
      case SideloadCheckOutcome.unsupportedPlatform:
        return 'Updates not supported on this platform';
      case SideloadCheckOutcome.error:
        return result.message ?? 'Error';
    }
  }

  Future<void> _showIosUpdateSheet(SideloadManifest manifest) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.sideloadUpdateAvailableTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '${manifest.version} (build ${manifest.build})\n${manifest.notes}',
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.sideloadIosNoSilentInstall,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                if (manifest.sideStoreSourceUrl != null)
                  FilledButton(
                    onPressed: () => launchUrl(
                      Uri.parse(manifest.sideStoreSourceUrl!),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Text(l10n.sideloadOpenSideStoreSource),
                  ),
                if (manifest.iosIpaUrl != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => launchUrl(
                      Uri.parse(manifest.iosIpaUrl!),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Text(l10n.sideloadDownloadIpa),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  l10n.sideloadUsbInstallHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAutoTime() async {
    final minutes = FinampSettingsHelper.finampSettings.sideloadAutoUpdateMinutes;
    final initial = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    FinampSetters.setSideloadAutoUpdateMinutes(
      picked.hour * 60 + picked.minute,
    );
    await _service.syncNativeSchedule();
    setState(() {});
  }

  String _formatMinutes(int minutes) {
    final t = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    return MaterialLocalizations.of(context).formatTimeOfDay(t);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mode = ref.watch(finampSettingsProvider.sideloadUpdateMode);
    final autoMinutes = ref.watch(finampSettingsProvider.sideloadAutoUpdateMinutes);
    final allowCellular = ref.watch(finampSettingsProvider.sideloadAllowCellular);
    final versionLabel = _packageInfo == null
        ? '…'
        : '${_packageInfo!.version}+${_packageInfo!.buildNumber}';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sideloadUpdatesSettingsTitle),
        leading: const FinampAppBarBackButton(),
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text(l10n.sideloadCurrentVersion),
            subtitle: Text(versionLabel),
          ),
          if (_statusMessage != null)
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(_statusMessage!),
            ),
          SwitchListTile(
            title: Text(l10n.sideloadUpdateModeAuto),
            subtitle: Text(
              mode == SideloadUpdateMode.auto
                  ? l10n.sideloadUpdateModeAutoSubtitle
                  : l10n.sideloadUpdateModeManualSubtitle,
            ),
            value: mode == SideloadUpdateMode.auto,
            onChanged: (enabled) async {
              FinampSetters.setSideloadUpdateMode(
                enabled ? SideloadUpdateMode.auto : SideloadUpdateMode.manual,
              );
              await _service.syncNativeSchedule();
            },
          ),
          if (mode == SideloadUpdateMode.auto)
            ListTile(
              title: Text(l10n.sideloadAutoUpdateTime),
              subtitle: Text(_formatMinutes(autoMinutes)),
              onTap: _pickAutoTime,
            ),
          SwitchListTile(
            title: Text(l10n.sideloadAllowCellular),
            subtitle: Text(l10n.sideloadAllowCellularSubtitle),
            value: allowCellular,
            onChanged: (v) async {
              FinampSetters.setSideloadAllowCellular(v);
              await _service.syncNativeSchedule();
            },
          ),
          ListTile(
            title: Text(l10n.sideloadCheckNow),
            subtitle: Text(
              Platform.isAndroid
                  ? l10n.sideloadCheckNowAndroidSubtitle
                  : l10n.sideloadCheckNowIosSubtitle,
            ),
            trailing: _checking
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.system_update),
            enabled: !_checking,
            onTap: () => _checkNow(install: true),
          ),
          if (Platform.isAndroid) ...[
            const Divider(),
            ListTile(
              title: Text(l10n.sideloadSetupStatus),
              subtitle: Text(_androidSetupSubtitle(l10n)),
            ),
            if (_androidSetup?['canRequestPackageInstalls'] != true)
              ListTile(
                leading: const Icon(Icons.security),
                title: Text(l10n.sideloadAllowUnknownApps),
                onTap: () async {
                  await _service.openInstallUnknownAppsSettings();
                  await _reload();
                },
              ),
            if (_androidSetup?['isSelfInstallerOfRecord'] != true)
              ListTile(
                leading: const Icon(Icons.touch_app),
                title: Text(l10n.sideloadCompleteOneTimeSetup),
                subtitle: Text(l10n.sideloadCompleteOneTimeSetupSubtitle),
                onTap: () => _checkNow(install: true),
              ),
            if (_workerStatus != null)
              ListTile(
                title: Text(l10n.sideloadLastWorkerRun),
                subtitle: Text(_workerStatusText()),
              ),
          ],
          if (Platform.isIOS) ...[
            const Divider(),
            ListTile(
              title: Text(l10n.sideloadIosInstallPaths),
              subtitle: Text(l10n.sideloadIosNoSilentInstall),
            ),
          ],
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _manifestController,
              decoration: InputDecoration(
                labelText: l10n.sideloadManifestUrlOptional,
                hintText: kSideloadDefaultManifestUrl,
              ),
              onSubmitted: (value) async {
                final trimmed = value.trim();
                FinampSetters.setSideloadManifestUrl(
                  trimmed.isEmpty ? null : trimmed,
                );
                await _service.syncNativeSchedule();
              },
            ),
          ),
          if ((_service.lastManifest?.notes.isNotEmpty) ?? false)
            ListTile(
              title: Text(l10n.sideloadReleaseNotes),
              subtitle: Text(_service.lastManifest!.notes),
            ),
        ],
      ),
    );
  }

  String _androidSetupSubtitle(AppLocalizations l10n) {
    final can = _androidSetup?['canRequestPackageInstalls'] == true;
    final self = _androidSetup?['isSelfInstallerOfRecord'] == true;
    final installer = _androidSetup?['installerPackageName']?.toString() ?? 'unknown';
    final parts = <String>[
      can ? l10n.sideloadUnknownAppsAllowed : l10n.sideloadUnknownAppsBlocked,
      self
          ? l10n.sideloadInstallerOfRecordOk
          : l10n.sideloadInstallerOfRecordOther(installer),
    ];
    return parts.join('\n');
  }

  String _workerStatusText() {
    final w = _workerStatus;
    if (w == null) return '';
    final lastRun = w['lastRunAt'];
    final when = lastRun is int && lastRun > 0
        ? DateTime.fromMillisecondsSinceEpoch(lastRun).toLocal().toString()
        : 'never';
    return 'Last: $when\nResult: ${w['lastResult'] ?? '—'}\n${w['lastError'] ?? ''}';
  }
}
