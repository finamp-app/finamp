import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:finamp/l10n/app_localizations.dart';

import '../components/ExternalSearch/music_finder_server_sheet.dart';
import '../components/now_playing_bar.dart';
import '../models/music_finder_models.dart';
import '../services/finamp_secrets.dart';
import '../services/music_finder_client.dart';

/// External Music Finder search against a self-hosted Music Finder service.
///
/// The Music Finder base URL is stored encrypted ([FinampSecrets]). Opening
/// this route without a reachable server prompts to reconnect without wiping
/// the saved URL.
class ExternalSearchScreen extends StatefulWidget {
  const ExternalSearchScreen({Key? key}) : super(key: key);

  static const routeName = "/external-search";

  @override
  State<ExternalSearchScreen> createState() => _ExternalSearchScreenState();
}

class _ExternalSearchScreenState extends State<ExternalSearchScreen> {
  final _songController = TextEditingController();
  final _artistController = TextEditingController();
  final _albumController = TextEditingController();
  final _resultsScrollController = ScrollController();
  final _musicFinderClient = MusicFinderClient();

  String? _serverUrl;
  bool _isConnecting = false;
  bool _isConnected = false;
  bool _isSearching = false;
  bool _isAdding = false;
  bool _serverSheetOpen = false;
  String? _searchError;
  String? _selectedArtistId;

  MusicFinderSearchResult? _result;
  MusicFinderAddResult? _addResult;
  final Set<String> _selectedUrls = {};

  String get _baseUrl => _serverUrl?.trim() ?? "";

  bool get _canSearch {
    return _isConnected &&
        !_isSearching &&
        (_songController.text.trim().isNotEmpty ||
            _artistController.text.trim().isNotEmpty ||
            _albumController.text.trim().isNotEmpty);
  }

  bool get _canAdd =>
      _isConnected && !_isAdding && _selectedUrls.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _songController.addListener(_onFieldChanged);
    _artistController.addListener(_onFieldChanged);
    _albumController.addListener(_onFieldChanged);

    final savedUrl = FinampSecrets.musicFinderServerUrl?.trim();
    if (savedUrl == null || savedUrl.isEmpty) {
      // Always allow entry via the skull button; prompt to connect.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _promptForServerOnEntry();
        }
      });
      return;
    }

    _serverUrl = savedUrl;
    _isConnected = false;
    _isConnecting = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _verifySavedServer(savedUrl);
      }
    });
  }

  /// First open with no saved Music Finder URL: show the connect sheet.
  /// Leave External Search if the user dismisses without connecting.
  Future<void> _promptForServerOnEntry() async {
    await _openServerSheet(force: true);
    if (!mounted) {
      return;
    }
    if (!_isConnected) {
      Navigator.of(context).pop();
    }
  }

  void _onFieldChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _songController.removeListener(_onFieldChanged);
    _artistController.removeListener(_onFieldChanged);
    _albumController.removeListener(_onFieldChanged);
    _songController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    _resultsScrollController.dispose();
    super.dispose();
  }

  Future<void> _verifySavedServer(String url) async {
    final ok = await _musicFinderClient.checkConnection(url);
    if (!mounted) {
      return;
    }

    if (ok) {
      setState(() {
        _isConnecting = false;
        _isConnected = true;
        _serverUrl = url;
      });
      return;
    }

    await _leaveBecauseServerUnavailable();
  }

  Future<void> _leaveBecauseServerUnavailable() async {
    // Keep the Hive URL — a failed health check (offline, MagicDNS not up yet,
    // server restart) must not wipe the secret; that looked like "URL does not
    // persist between launches."
    setState(() {
      _serverUrl = null;
      _isConnected = false;
      _isConnecting = false;
      _result = null;
      _addResult = null;
      _selectedUrls.clear();
      _selectedArtistId = null;
    });

    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.musicFinderServerUnavailable,
        ),
      ),
    );

    final connectedUrl = await MusicFinderServerSheet.show(
      context,
      client: _musicFinderClient,
      isDismissible: true,
    );
    if (!mounted) {
      return;
    }

    if (connectedUrl != null && connectedUrl.isNotEmpty) {
      await FinampSecrets.setMusicFinderServerUrl(connectedUrl);
      setState(() {
        _serverUrl = connectedUrl;
        _isConnected = true;
        _isConnecting = false;
        _searchError = null;
      });
      return;
    }

    Navigator.of(context).pop();
  }

  Future<void> _openServerSheet({bool force = false}) async {
    if (_serverSheetOpen) {
      return;
    }

    // Field is always empty — never pass the stored URL into the sheet.
    _serverSheetOpen = true;
    final connectedUrl = await MusicFinderServerSheet.show(
      context,
      client: _musicFinderClient,
      isDismissible: true,
    );
    _serverSheetOpen = false;

    if (!mounted) {
      return;
    }

    if (connectedUrl != null && connectedUrl.isNotEmpty) {
      setState(() {
        _serverUrl = connectedUrl;
        _isConnected = true;
        _isConnecting = false;
        _searchError = null;
        _result = null;
        _addResult = null;
        _selectedUrls.clear();
      });
      await FinampSecrets.setMusicFinderServerUrl(connectedUrl);
      return;
    }

    setState(() {
      _isConnecting = false;
    });
  }

  bool _isUnreachableError(Object error) {
    if (error is TimeoutException ||
        error is SocketException ||
        error is HandshakeException ||
        error is HttpException) {
      return true;
    }
    if (error is MusicFinderException) {
      final code = error.statusCode;
      return code == null || code >= 500;
    }
    return false;
  }

  Future<void> _handleUnreachable(Object error) async {
    if (!_isUnreachableError(error)) {
      return;
    }
    setState(() {
      _isConnected = false;
      _result = null;
      _addResult = null;
      _selectedUrls.clear();
      _selectedArtistId = null;
    });
    await _leaveBecauseServerUnavailable();
  }

  Future<void> _runSearch({String? artistId}) async {
    if (_isSearching || !_isConnected) {
      return;
    }
    if (_songController.text.trim().isEmpty &&
        _artistController.text.trim().isEmpty &&
        _albumController.text.trim().isEmpty) {
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
      _addResult = null;
      _selectedUrls.clear();
      if (artistId != null) {
        _selectedArtistId = artistId;
      }
    });

    try {
      final result = await _musicFinderClient.search(
        baseUrl: _baseUrl,
        song: _songController.text.trim(),
        artist: _artistController.text.trim(),
        album: _albumController.text.trim(),
        artistId: artistId ?? _selectedArtistId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isSearching = false;
        _result = result;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSearching = false;
        _result = null;
        _searchError = e.toString();
      });
      await _handleUnreachable(e);
    }
  }

  Future<void> _addSelected() async {
    if (!_canAdd) {
      return;
    }

    setState(() {
      _isAdding = true;
      _addResult = null;
    });

    try {
      final candidates = _result?.candidates ?? const [];
      final addResult = await _musicFinderClient.addItems(
        baseUrl: _baseUrl,
        urls: [
          for (var i = 0; i < candidates.length; i++)
            if (_selectedUrls.contains(_candidateKey(candidates[i], i)) &&
                candidates[i].url.isNotEmpty)
              candidates[i].url,
        ],
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isAdding = false;
        _addResult = addResult;
      });
      final messenger = ScaffoldMessenger.of(context);
      final okCount = addResult.results.where((r) => r.ok).length;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!
                .musicFinderAddSummary(okCount, addResult.results.length),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isAdding = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      await _handleUnreachable(e);
    }
  }

  void _onCancel() {
    Navigator.of(context).pop();
  }

  String _candidateKey(MusicFinderCandidate c, int index) =>
      c.url.isNotEmpty ? c.url : "idx:$index";

  void _toggleSelectAll(bool? select) {
    final candidates = _result?.candidates ?? const [];
    setState(() {
      if (select == true) {
        _selectedUrls
          ..clear()
          ..addAll([
            for (var i = 0; i < candidates.length; i++)
              _candidateKey(candidates[i], i),
          ]);
      } else {
        _selectedUrls.clear();
      }
    });
  }

  void _scrollResultsByPage(double direction) {
    if (!_resultsScrollController.hasClients) {
      return;
    }
    final position = _resultsScrollController.position;
    final delta = position.viewportDimension * 0.85 * direction;
    _resultsScrollController.animateTo(
      (position.pixels + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _jumpResultsTo(double offset) {
    if (!_resultsScrollController.hasClients) {
      return;
    }
    final position = _resultsScrollController.position;
    _resultsScrollController.jumpTo(
      offset.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }

  Widget _buildSearchHeader(AppLocalizations localizations) {
    final candidates = _result?.candidates ?? const [];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SearchFields(
            songController: _songController,
            artistController: _artistController,
            albumController: _albumController,
            enabled: !_isSearching && !_isAdding,
            canSearch: _canSearch,
            isSearching: _isSearching,
            isAdding: _isAdding,
            onSearch: () => _runSearch(),
            onCancel: _onCancel,
          ),
          if (_searchError != null) ...[
            const SizedBox(height: 16),
            Text(
              _searchError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 12),
            _IdentitySection(
              result: _result!,
              selectedArtistId: _selectedArtistId,
              onArtistSelected: (id) {
                setState(() => _selectedArtistId = id);
              },
              onContinueWithArtist: _isSearching
                  ? null
                  : () {
                      if (_selectedArtistId != null) {
                        _runSearch(artistId: _selectedArtistId);
                      }
                    },
            ),
          ],
          if (_result != null &&
              candidates.isEmpty &&
              !_result!.alreadyOwned &&
              !_result!.needsArtistChoice) ...[
            const SizedBox(height: 16),
            Text(localizations.musicFinderNoCandidates),
          ],
          if (_addResult != null) ...[
            const SizedBox(height: 16),
            Text(
              localizations.musicFinderAddResults,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final r in _addResult!.results)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  r.ok ? Icons.check_circle : Icons.error,
                  color: r.ok
                      ? Colors.green
                      : Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  r.detail.isEmpty ? (r.ok ? "ok" : "error") : r.detail,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultsPane(
    AppLocalizations localizations,
    List<MusicFinderCandidate> candidates,
    bool allSelected,
    bool someSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          elevation: 1,
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        localizations.musicFinderResults,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      "${_selectedUrls.length}/${candidates.length}",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Checkbox(
                      tristate: true,
                      value: allSelected
                          ? true
                          : (someSelected ? null : false),
                      onChanged: _isAdding ? null : _toggleSelectAll,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ElevatedButton.icon(
                  onPressed: _canAdd ? _addSelected : null,
                  icon: const Icon(Icons.library_add_outlined),
                  label: Text(
                    _isAdding
                        ? localizations.musicFinderAddingLabel
                        : localizations.musicFinderAddSelected,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: localizations.musicFinderJumpToTop,
                      onPressed: () => _jumpResultsTo(0),
                      icon: const Icon(Icons.vertical_align_top),
                    ),
                    IconButton(
                      tooltip: localizations.musicFinderScrollUp,
                      onPressed: () => _scrollResultsByPage(-1),
                      icon: const Icon(Icons.keyboard_arrow_up),
                    ),
                    IconButton(
                      tooltip: localizations.musicFinderScrollDown,
                      onPressed: () => _scrollResultsByPage(1),
                      icon: const Icon(Icons.keyboard_arrow_down),
                    ),
                    IconButton(
                      tooltip: localizations.musicFinderJumpToBottom,
                      onPressed: () {
                        if (!_resultsScrollController.hasClients) {
                          return;
                        }
                        _jumpResultsTo(
                          _resultsScrollController.position.maxScrollExtent,
                        );
                      },
                      icon: const Icon(Icons.vertical_align_bottom),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Scrollbar(
            controller: _resultsScrollController,
            thumbVisibility: true,
            trackVisibility: true,
            interactive: true,
            child: ListView.builder(
              controller: _resultsScrollController,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              itemCount: candidates.length,
              itemBuilder: (context, index) {
                final c = candidates[index];
                final itemKey = _candidateKey(c, index);
                return CheckboxListTile(
                  key: ValueKey(itemKey),
                  value: _selectedUrls.contains(itemKey),
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  onChanged: _isAdding
                      ? null
                      : (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedUrls.add(itemKey);
                            } else {
                              _selectedUrls.remove(itemKey);
                            }
                          });
                        },
                  title: Text(
                    c.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    "${localizations.musicFinderScore}: ${c.score.toStringAsFixed(2)}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final candidates = _result?.candidates ?? const [];
    final allSelected = candidates.isNotEmpty &&
        List.generate(
          candidates.length,
          (i) => _selectedUrls.contains(_candidateKey(candidates[i], i)),
        ).every((v) => v);
    final someSelected = _selectedUrls.isNotEmpty && !allSelected;
    final hasCandidates = candidates.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.externalSearch),
        actions: [
          if (_isConnected)
            IconButton(
              icon: const Icon(Icons.dns_outlined),
              tooltip: localizations.musicFinderChangeServer,
              onPressed: (_isSearching || _isAdding || _isConnecting)
                  ? null
                  : () => _openServerSheet(force: true),
            ),
        ],
      ),
      bottomNavigationBar: const NowPlayingBar(),
      body: SafeArea(
        child: Column(
          children: [
            if (_isConnecting)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: !_isConnected
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        Flexible(
                          flex: hasCandidates ? 2 : 1,
                          child: SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            child: _buildSearchHeader(localizations),
                          ),
                        ),
                        if (hasCandidates)
                          Expanded(
                            flex: 3,
                            child: _buildResultsPane(
                              localizations,
                              candidates,
                              allSelected,
                              someSelected,
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Search form: stacked in portrait, compact row in landscape / wide layouts.
class _SearchFields extends StatelessWidget {
  const _SearchFields({
    required this.songController,
    required this.artistController,
    required this.albumController,
    required this.enabled,
    required this.canSearch,
    required this.isSearching,
    required this.isAdding,
    required this.onSearch,
    required this.onCancel,
  });

  final TextEditingController songController;
  final TextEditingController artistController;
  final TextEditingController albumController;
  final bool enabled;
  final bool canSearch;
  final bool isSearching;
  final bool isAdding;
  final VoidCallback onSearch;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final node = FocusScope.of(context);
    final size = MediaQuery.of(context).size;
    final wide = size.width >= 700 ||
        MediaQuery.of(context).orientation == Orientation.landscape;

    final songField = TextField(
      controller: songController,
      enabled: enabled,
      textInputAction: TextInputAction.next,
      onEditingComplete: () => node.nextFocus(),
      decoration: InputDecoration(
        labelText: localizations.song,
        border: const OutlineInputBorder(),
        isDense: wide,
      ),
    );
    final artistField = TextField(
      controller: artistController,
      enabled: enabled,
      textInputAction: TextInputAction.next,
      onEditingComplete: () => node.nextFocus(),
      decoration: InputDecoration(
        labelText: localizations.artist,
        border: const OutlineInputBorder(),
        isDense: wide,
      ),
    );
    final albumField = TextField(
      controller: albumController,
      enabled: enabled,
      textInputAction: TextInputAction.done,
      onEditingComplete: canSearch ? onSearch : null,
      decoration: InputDecoration(
        labelText: localizations.album,
        border: const OutlineInputBorder(),
        isDense: wide,
      ),
    );
    final actions = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: (isSearching || isAdding) ? null : onCancel,
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: canSearch ? onSearch : null,
          child: Text(
            isSearching
                ? localizations.searchingButtonLabel
                : localizations.searchButtonLabel,
          ),
        ),
      ],
    );

    if (wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: songField),
              const SizedBox(width: 12),
              Expanded(child: artistField),
              const SizedBox(width: 12),
              Expanded(child: albumField),
            ],
          ),
          const SizedBox(height: 12),
          actions,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        songField,
        const SizedBox(height: 16),
        artistField,
        const SizedBox(height: 16),
        albumField,
        const SizedBox(height: 16),
        actions,
      ],
    );
  }
}

/// User-facing identity prompts only (owned / pick artist). No diagnostics.
class _IdentitySection extends StatelessWidget {
  const _IdentitySection({
    required this.result,
    required this.selectedArtistId,
    required this.onArtistSelected,
    required this.onContinueWithArtist,
  });

  final MusicFinderSearchResult result;
  final String? selectedArtistId;
  final ValueChanged<String> onArtistSelected;
  final VoidCallback? onContinueWithArtist;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final identity = result.identity;

    final showOwned = result.alreadyOwned && identity?.owned != null;
    final showChooser = result.needsArtistChoice &&
        (identity?.artists.isNotEmpty ?? false);

    if (!showOwned && !showChooser) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showOwned)
              Text(
                localizations.musicFinderAlreadyOwned(
                  identity!.owned!.artist,
                  identity.owned!.title.isNotEmpty
                      ? identity.owned!.title
                      : identity.owned!.album,
                  identity.owned!.score.toStringAsFixed(2),
                ),
              ),
            if (showChooser) ...[
              if (showOwned) const SizedBox(height: 8),
              Text(localizations.musicFinderChooseArtist),
              for (final a in identity!.artists)
                RadioListTile<String>(
                  dense: true,
                  title: Text(a.name),
                  subtitle: Text(
                    "${a.source} · ${(a.score * 100).toStringAsFixed(0)}%"
                    "${a.disambiguation.isNotEmpty ? ' · ${a.disambiguation}' : ''}",
                  ),
                  value: a.id,
                  groupValue: selectedArtistId,
                  onChanged: onContinueWithArtist == null
                      ? null
                      : (v) {
                          if (v != null) {
                            onArtistSelected(v);
                          }
                        },
                ),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: selectedArtistId == null ||
                          onContinueWithArtist == null
                      ? null
                      : onContinueWithArtist,
                  child: Text(localizations.musicFinderContinueWithArtist),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
