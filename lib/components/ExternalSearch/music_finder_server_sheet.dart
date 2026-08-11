import 'package:flutter/material.dart';
import 'package:finamp/l10n/app_localizations.dart';

import '../../services/music_finder_client.dart';

/// Modal sheet to enter and health-check a Music Finder base URL.
///
/// The field is always empty when opened — a stored URL is never shown
/// (treated like a secret). Pops with the URL on success, or `null` if dismissed.
class MusicFinderServerSheet extends StatefulWidget {
  const MusicFinderServerSheet({
    Key? key,
    required this.client,
  }) : super(key: key);

  final MusicFinderClient client;

  static Future<String?> show(
    BuildContext context, {
    required MusicFinderClient client,
    bool isDismissible = true,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: MusicFinderServerSheet(client: client),
        );
      },
    );
  }

  @override
  State<MusicFinderServerSheet> createState() => _MusicFinderServerSheetState();
}

class _MusicFinderServerSheetState extends State<MusicFinderServerSheet> {
  final _urlController = TextEditingController();
  bool _isConnecting = false;
  bool _obscureUrl = true;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  String? _validate(String raw) {
    final localizations = AppLocalizations.of(context)!;
    final value = raw.trim();
    if (value.isEmpty) {
      return localizations.emptyServerUrl;
    }
    if (!value.startsWith("http://") && !value.startsWith("https://")) {
      return localizations.urlStartWithHttps;
    }
    if (value.endsWith("/")) {
      return localizations.urlTrailingSlash;
    }
    return null;
  }

  Future<void> _connect() async {
    if (_isConnecting) {
      return;
    }

    final validationError = _validate(_urlController.text);
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    final url = _urlController.text.trim();
    setState(() {
      _isConnecting = true;
      _error = null;
    });

    final ok = await widget.client.checkConnection(url);
    if (!mounted) {
      return;
    }

    if (ok) {
      // Drop the typed secret from the field before the sheet closes.
      _urlController.clear();
      Navigator.of(context, rootNavigator: true).pop(url);
      return;
    }

    setState(() {
      _isConnecting = false;
      _error = AppLocalizations.of(context)!.musicFinderConnectFailed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Text(
              localizations.musicFinderServerSheetTitle,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              localizations.musicFinderServerSheetSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              enabled: !_isConnecting,
              obscureText: _obscureUrl,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onEditingComplete: _connect,
              decoration: InputDecoration(
                labelText: localizations.musicFinderServerUrl,
                hintText: "http://127.0.0.1:8088",
                border: const OutlineInputBorder(),
                errorText: _error,
                suffixIcon: IconButton(
                  tooltip: _obscureUrl
                      ? localizations.musicFinderShowUrl
                      : localizations.musicFinderHideUrl,
                  onPressed: _isConnecting
                      ? null
                      : () => setState(() => _obscureUrl = !_obscureUrl),
                  icon: Icon(
                    _obscureUrl ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isConnecting
                      ? null
                      : () {
                          _urlController.clear();
                          Navigator.of(context, rootNavigator: true).pop();
                        },
                  child: Text(
                    MaterialLocalizations.of(context).cancelButtonLabel,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isConnecting ? null : _connect,
                  child: _isConnecting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(localizations.connectButtonLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
