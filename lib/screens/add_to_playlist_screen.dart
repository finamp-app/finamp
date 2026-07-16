import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../components/AddToPlaylistScreen/add_to_playlist_list.dart';
import '../components/AddToPlaylistScreen/new_playlist_dialog.dart';

class AddToPlaylistScreen extends StatefulWidget {
  const AddToPlaylistScreen({Key? key}) : super(key: key);

  static const routeName = "/music/addtoplaylist";

  @override
  State<AddToPlaylistScreen> createState() => _AddToPlaylistScreenState();
}

class _AddToPlaylistScreenState extends State<AddToPlaylistScreen> {
  @override
  Widget build(BuildContext context) {
    // Accepts either a single item id or a list of them (multi-select), so all
    // existing callers keep working.
    final arguments = ModalRoute.of(context)!.settings.arguments;
    final itemIds =
        arguments is List<String> ? arguments : [arguments as String];

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.addToPlaylistTitle),
      ),
      body: AddToPlaylistList(
        itemsToAdd: itemIds,
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          // The dialog returns true if a playlist is created. If this is the
          // case, we also pop this page. It will return false if the user
          // cancels the dialog.
          final result = await showDialog<bool>(
            context: context,
            builder: (context) => NewPlaylistDialog(itemsToAdd: itemIds),
          );

          if (!mounted) return;

          if (result == true) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }
}
