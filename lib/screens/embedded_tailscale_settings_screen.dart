import 'dart:async';

import 'package:finamp/components/finamp_app_bar_back_button.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/services/embedded_tailscale_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tailscale/tailscale.dart';
import 'package:url_launcher/url_launcher.dart';

/// Settings for in-process Tailscale (tsnet) used for Jellyfin MagicDNS.
class EmbeddedTailscaleSettingsScreen extends ConsumerStatefulWidget {
  const EmbeddedTailscaleSettingsScreen({super.key});

  static const routeName = '/settings/embedded-tailscale';

  @override
  ConsumerState<EmbeddedTailscaleSettingsScreen> createState() =>
      _EmbeddedTailscaleSettingsScreenState();
}

class _EmbeddedTailscaleSettingsScreenState
    extends ConsumerState<EmbeddedTailscaleSettingsScreen> {
  final _authKeyController = TextEditingController();
  StreamSubscription<NodeState>? _stateSub;
  TailscaleStatus? _status;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _status = EmbeddedTailscaleService.lastStatus;
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    if (!FinampSettingsHelper.finampSettings.useEmbeddedTailscale) return;
    try {
      await EmbeddedTailscaleService.ensureInitialized();
      _attachStateListener();
      if (_status == null || _status!.state == NodeState.stopped) {
        setState(() => _busy = true);
        final status = await EmbeddedTailscaleService.up();
        if (mounted) {
          setState(() {
            _status = status;
            _busy = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _busy = false;
        });
      }
    }
  }

  void _attachStateListener() {
    _stateSub?.cancel();
    _stateSub = EmbeddedTailscaleService.listenState((s) {
      if (mounted) setState(() => _status = s);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _authKeyController.dispose();
    super.dispose();
  }

  Future<void> _onToggle(bool enabled) async {
    FinampSetters.setUseEmbeddedTailscale(enabled);
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      if (enabled) {
        await EmbeddedTailscaleService.ensureInitialized();
        _attachStateListener();
        final key = _authKeyController.text.trim();
        final status = await EmbeddedTailscaleService.up(
          authKey: key.isEmpty ? null : key,
        );
        if (mounted) setState(() => _status = status);
      } else {
        await EmbeddedTailscaleService.down();
        if (mounted) {
          setState(() => _status = EmbeddedTailscaleService.lastStatus);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connectWithKey() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await EmbeddedTailscaleService.ensureInitialized();
      _attachStateListener();
      final key = _authKeyController.text.trim();
      final status = await EmbeddedTailscaleService.up(
        authKey: key.isEmpty ? null : key,
      );
      if (mounted) setState(() => _status = status);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _busy = true);
    try {
      await EmbeddedTailscaleService.logout();
      if (mounted) {
        setState(() {
          _status = TailscaleStatus.stopped;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _statusLabel(AppLocalizations l10n) {
    final s = _status;
    if (s == null || s.state == NodeState.stopped || s.state == NodeState.noState) {
      return l10n.embeddedTailscaleStatusDisconnected;
    }
    if (s.isRunning) {
      return l10n.embeddedTailscaleStatusRunning(s.ipv4 ?? '');
    }
    if (s.needsLogin) return l10n.embeddedTailscaleStatusNeedsLogin;
    if (s.state == NodeState.needsMachineAuth) {
      return l10n.embeddedTailscaleStatusNeedsApproval;
    }
    return l10n.embeddedTailscaleStatusOther(s.state.name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final enabled = ref.watch(finampSettingsProvider.useEmbeddedTailscale);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.embeddedTailscaleSettingsTitle),
        leading: const FinampAppBarBackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 200.0),
        children: [
          SwitchListTile.adaptive(
            title: Text(l10n.embeddedTailscaleEnableTitle),
            subtitle: Text(l10n.embeddedTailscaleEnableSubtitle),
            value: enabled,
            onChanged: _busy ? null : _onToggle,
          ),
          ListTile(
            title: Text(l10n.embeddedTailscaleStatusTitle),
            subtitle: Text(
              _busy ? l10n.embeddedTailscaleStatusBusy : _statusLabel(l10n),
            ),
          ),
          if (_error != null)
            ListTile(
              leading: Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(l10n.embeddedTailscaleErrorTitle),
              subtitle: Text(_error!),
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _authKeyController,
              enabled: !_busy,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.embeddedTailscaleAuthKeyLabel,
                hintText: l10n.embeddedTailscaleAuthKeyHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          ListTile(
            title: Text(l10n.embeddedTailscaleConnectButton),
            subtitle: Text(l10n.embeddedTailscaleConnectSubtitle),
            trailing: const Icon(Icons.login),
            enabled: !_busy && enabled,
            onTap: _busy || !enabled ? null : _connectWithKey,
          ),
          if (_status?.needsLogin ?? false)
            ListTile(
              title: Text(l10n.embeddedTailscaleOpenLogin),
              subtitle: Text(l10n.embeddedTailscaleOpenLoginSubtitle),
              trailing: const Icon(Icons.open_in_browser),
              onTap: () async {
                final uri = _status?.authUrl;
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                  return;
                }
                await Clipboard.setData(
                  ClipboardData(text: l10n.embeddedTailscaleLoginClipboardHint),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.embeddedTailscaleLoginCopied)),
                  );
                }
              },
            ),
          const Divider(),
          ListTile(
            title: Text(l10n.embeddedTailscaleLogoutTitle),
            subtitle: Text(l10n.embeddedTailscaleLogoutSubtitle),
            trailing: const Icon(Icons.logout),
            enabled: !_busy && enabled,
            onTap: _busy || !enabled ? null : _logout,
          ),
        ],
      ),
    );
  }
}
