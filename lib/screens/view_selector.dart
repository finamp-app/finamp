import 'package:finamp/components/finamp_app_bar_back_button.dart';
import 'package:finamp/screens/music_screen.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/screens/splash_screen.dart';
import '../components/ViewSelector/no_music_libraries_message.dart';
import '../components/global_snackbar.dart';
import '../models/jellyfin_models.dart';
import '../services/finamp_user_helper.dart';
import '../services/jellyfin_api_helper.dart';

class ViewSelector extends StatefulWidget {
  const ViewSelector({super.key});

  static const routeName = "/settings/views";

  @override
  State<ViewSelector> createState() => _ViewSelectorState();
}

class _ViewSelectorState extends State<ViewSelector> {
  final _jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final _finampUserHelper = GetIt.instance<FinampUserHelper>();
  late Future<List<BaseItemDto>> viewListFuture;
  final Map<BaseItemDto, bool> _views = {};
  bool isSubmitButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    viewListFuture = _jellyfinApiHelper.getViews();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.selectMusicLibraries),
        leading: FinampAppBarBackButton(),
      ),
      floatingActionButton: isSubmitButtonEnabled
          ? FloatingActionButton(onPressed: _submitChoice, child: const Icon(Icons.check))
          : null,
      body: FutureBuilder<List<BaseItemDto>>(
        future: viewListFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            // Finamp only supports music libraries. We used to allow people to
            // select unsupported libraries, but some people selected "general"
            // libraries and thought Finamp was broken.
            if (snapshot.data!.isEmpty || !snapshot.data!.any((element) => element.collectionType == "music")) {
              return NoMusicLibrariesMessage(
                onRefresh: () {
                  setState(() {
                    _views.clear();
                    viewListFuture = _jellyfinApiHelper.getViews();
                  });
                },
              );
            }
            if (_views.isEmpty) {
              _views.addEntries(
                snapshot.data!
                    .where((element) => element.collectionType != "playlists")
                    .map(
                      (e) => MapEntry(
                        e,
                        e.collectionType == "music" &&
                            (_finampUserHelper.currentUser!.views.isEmpty ||
                                _finampUserHelper.currentUser!.views.keys.contains(e.id)),
                      ),
                    ),
              );

              // If only one music library is available and user doesn't have a
              // view saved (assuming setup is in progress), skip the selector.
              if (_views.values.where((element) => element == true).length == 1 &&
                  _finampUserHelper.currentUser!.currentView == null) {
                _submitChoice();
              } else {
                if (mounted) {
                  Future.microtask(
                    () => setState(() {
                      isSubmitButtonEnabled = _views.values.contains(true);
                    }),
                  );
                }
              }
            }

            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 200.0),
              itemCount: _views.length,
              itemBuilder: (context, index) {
                final isSelected = _views.values.elementAt(index);
                final view = _views.keys.elementAt(index);

                return CheckboxListTile(
                  key: ValueKey(view.id),
                  value: isSelected,
                  enabled: view.collectionType == "music",
                  title: Text(_views.keys.elementAt(index).name ?? AppLocalizations.of(context)!.unknownName),
                  onChanged: (value) {
                    setState(() {
                      _views[_views.keys.elementAt(index)] = value!;
                      isSubmitButtonEnabled = _views.values.contains(true);
                    });
                  },
                );
              },
            );
          } else if (snapshot.hasError) {
            GlobalSnackbar.error(snapshot.error);
            return Center(
              child: ListView(
                padding: EdgeInsets.only(top: 20),
                children: [
                  ListTile(leading: Icon(Icons.error), title: Text(AppLocalizations.of(context)!.librarySelectError)),
                  ListTile(
                    leading: Icon(Icons.refresh),
                    title: Text(AppLocalizations.of(context)!.refresh),
                    onTap: () => setState(() {
                      viewListFuture = _jellyfinApiHelper.getViews();
                    }),
                  ),
                  ListTile(
                    leading: Icon(Icons.logout),
                    title: Text(AppLocalizations.of(context)!.logOut),
                    onTap: () async {
                      final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();

                      await jellyfinApiHelper.logoutCurrentUser().onError((_, __) {});

                      if (!context.mounted) return;

                      await Navigator.of(context).pushNamedAndRemoveUntil(SplashScreen.routeName, (route) => false);
                    },
                  ),
                ],
              ),
            );
          } else {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
        },
      ),
    );
  }

  void _submitChoice() {
    if (_views.values.where((element) => element == true).isEmpty) {
      // This should no longer be possible since the submit button only shows
      // when views are selected, but we return just in case
      return;
    } else {
      try {
        _finampUserHelper.setCurrentUserViews(
          _views.entries.where((element) => element.value == true).map((e) => e.key).toList(),
        );

        // allow calling _submitChoice() while selector is being built by delaying
        // navigation changes
        Future.microtask(() => Navigator.of(context).pushNamedAndRemoveUntil(MusicScreen.routeName, (route) => false));
      } catch (e) {
        GlobalSnackbar.error(e);
      }
    }
  }
}
