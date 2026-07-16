import 'package:finamp/models/jellyfin_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get_it/get_it.dart';

import '../../services/finamp_user_helper.dart';
import '../../services/jellyfin_api_helper.dart';
import '../error_snackbar.dart';

class NewPlaylistDialog extends StatefulWidget {
  const NewPlaylistDialog({
    Key? key,
    required this.itemsToAdd,
  }) : super(key: key);

  final List<String> itemsToAdd;

  @override
  State<NewPlaylistDialog> createState() => _NewPlaylistDialogState();
}

class _NewPlaylistDialogState extends State<NewPlaylistDialog> {
  final _formKey = GlobalKey<FormState>();
  final _jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final _finampUserHelper = GetIt.instance<FinampUserHelper>();

  bool _isSubmitting = false;

  String? _name;
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.newPlaylist),
      content: Form(
        key: _formKey,
        child: TextFormField(
          decoration:
              InputDecoration(labelText: AppLocalizations.of(context)!.name),
          textInputAction: TextInputAction.done,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return AppLocalizations.of(context)!.required;
            }
            return null;
          },
          onFieldSubmitted: (_) async => await _submit(),
          onSaved: (newValue) => _name = newValue,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop<bool>(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        TextButton(
          onPressed: _isSubmitting ? null : () async => await _submit(),
          child: Text(AppLocalizations.of(context)!.createButtonLabel),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState != null && _formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      _formKey.currentState!.save();

      try {
        await _jellyfinApiHelper.createNewPlaylist(NewPlaylist(
          name: _name,
          ids: widget.itemsToAdd,
          userId: _finampUserHelper.currentUser!.id,
        ));

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.playlistCreated),
        ));
        Navigator.of(context).pop<bool>(true);
      } catch (e) {
        errorSnackbar(e, context);
        setState(() {
          _isSubmitting = false;
        });
        return;
      }
    }
  }
}
