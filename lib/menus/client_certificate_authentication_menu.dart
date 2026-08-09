import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:finamp/components/confirmation_prompt_dialog.dart';
import 'package:finamp/components/themed_bottom_sheet.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/client_certificate_installer.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

const clientCertificateAuthenticationRouteName = "/client-certificate-authentication-menu";

Future<void> showClientCertificateMenu({required BuildContext context, VoidCallback? onImported}) async {
  await showThemedBottomSheet(
    context: context,
    routeName: clientCertificateAuthenticationRouteName,
    minDraggableHeight: 0.3,
    useRootNavigator: true,
    buildSlivers: (context) {
      var menu = [
        SliverStickyHeader(
          header: const _ClientCertificateMenuHeader(),
          sliver: MenuMask(
            height: const MenuMaskHeight(44.0),
            child: SliverToBoxAdapter(child: _ClientCertificateMenuContent(onImported: onImported)),
          ),
        ),
      ];
      const stackHeight = 250.0;
      return (stackHeight, menu);
    },
  );
}

class _ClientCertificateMenuHeader extends StatelessWidget {
  const _ClientCertificateMenuHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6.0, bottom: 16.0),
      child: Center(
        child: Text(
          AppLocalizations.of(context)!.clientCertificate,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
        ),
      ),
    );
  }
}

class _ClientCertificateMenuContent extends ConsumerStatefulWidget {
  const _ClientCertificateMenuContent({this.onImported});

  final VoidCallback? onImported;

  @override
  ConsumerState<_ClientCertificateMenuContent> createState() => _ClientCertificateMenuContentState();
}

class _ClientCertificateMenuContentState extends ConsumerState<_ClientCertificateMenuContent> {
  final _clientCertificateInstaller = ClientCertificateInstaller();
  bool _importing = false;

  Future<void> _importCertificate() async {
    final l10n = AppLocalizations.of(context)!;

    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['p12', 'pfx']);
    if (result == null || result.files.single.path == null) return;

    final filePath = result.files.single.path!;

    if (!mounted) return;
    final password = await _showPasswordDialog(context);
    if (password == null) return;

    setState(() => _importing = true);
    try {
      final bytes = await File(filePath).readAsBytes();
      FinampSetters.setClientCertificate(ClientCertificate(data: bytes, password: password));
      await _clientCertificateInstaller.installClientCertificate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.clientCertificateImportSuccess)));
        widget.onImported?.call();
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.clientCertificateImportError)));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<String?> _showPasswordDialog(BuildContext context) async {
    // Use root navigator context to avoid cross-overlay InheritedWidget dependency issues.
    final dialogContext = Navigator.of(context, rootNavigator: true).context;
    return await showDialog<String?>(context: dialogContext, builder: (context) => const _PasswordDialog());
  }

  Future<void> _removeCertificate() async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (context) => ConfirmationPromptDialog(
        promptText: l10n.clientCertificateDeleteConfirm,
        confirmButtonText: l10n.removeClientCertificate,
        onConfirmed: () async {
          FinampSetters.setClientCertificate(null);
          await _clientCertificateInstaller.clearClientCertificate();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final certificate = ref.watch(finampSettingsProvider.clientCertificate);
    final isInstalled = certificate != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16.0,
        children: [
          // Status row
          Row(
            spacing: 12.0,
            children: [
              Icon(
                isInstalled ? TablerIcons.certificate : TablerIcons.certificate_off,
                color: isInstalled
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withAlpha(153),
                size: 28.0,
              ),
              Expanded(
                child: Text(
                  isInstalled ? l10n.clientCertificateInstalled : l10n.clientCertificateUnavailable,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          // Description
          Text(
            l10n.clientCertificateDescription,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withAlpha(179)),
          ),
          // Action buttons
          Row(
            spacing: 8.0,
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _importing ? null : _importCertificate,
                  child: _importing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : Text(l10n.importClientCertificate),
                ),
              ),
              if (isInstalled)
                Expanded(
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                    onPressed: _removeCertificate,
                    child: Text(l10n.removeClientCertificate),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.clientCertificatePasswordTitle),
      content: TextField(
        controller: _controller,
        obscureText: true,
        autofocus: true,
        keyboardType: TextInputType.visiblePassword,
        decoration: InputDecoration(hintText: l10n.clientCertificatePasswordHint),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(null), child: Text(l10n.genericCancel)),
        TextButton(onPressed: () => Navigator.of(context).pop(_controller.text), child: Text(l10n.confirm)),
      ],
    );
  }
}
