import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../extensions/localizations.dart';
import '../../models/finamp_models.dart';

class AppDirectoryLocationForm extends StatefulWidget {
  const AppDirectoryLocationForm({super.key, required this.formKey});

  final Key formKey;

  @override
  State<AppDirectoryLocationForm> createState() => _AppDirectoryLocationFormState();
}

class _AppDirectoryLocationFormState extends State<AppDirectoryLocationForm> {
  Directory? selectedDirectory;
  late Future<List<Directory>?> externalStorageListFuture;

  @override
  void initState() {
    super.initState();
    externalStorageListFuture = getExternalStorageDirectories();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FutureBuilder<List<Directory>?>(
            future: externalStorageListFuture,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                if (snapshot.data!.isEmpty) {
                  return Text(context.l10n.noExternalDirectories);
                }
                List<DropdownMenuItem<Directory>> dropdownButtonItems = snapshot.data!
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e.path, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList();
                return DropdownButtonFormField<Directory>(
                  items: dropdownButtonItems,
                  hint: Text(context.l10n.location),
                  isExpanded: true,
                  initialValue: selectedDirectory,
                  onChanged: (value) {
                    setState(() {
                      selectedDirectory = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return context.l10n.required;
                    }
                    return null;
                  },
                  onSaved: (newValue) {
                    if (newValue != null) {
                      context.read<NewDownloadLocation>().path = newValue.path;
                    }
                  },
                );
              } else if (snapshot.hasError) {
                return Text(snapshot.error.toString());
              } else {
                return const CircularProgressIndicator.adaptive();
              }
            },
          ),
          TextFormField(
            decoration: InputDecoration(labelText: context.l10n.nameRequired),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return context.l10n.required;
              }
              return null;
            },
            onSaved: (newValue) {
              if (newValue != null) {
                context.read<NewDownloadLocation>().name = newValue;
              }
            },
          ),
          const Padding(padding: EdgeInsets.all(8.0)),
          Text(
            context.l10n.exteranlStorageTip,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
