import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/finamp_models.dart';

class CustomDownloadLocationForm extends StatefulWidget {
  const CustomDownloadLocationForm({super.key, required this.formKey});

  final Key formKey;

  @override
  State<CustomDownloadLocationForm> createState() => _CustomDownloadLocationFormState();
}

class _CustomDownloadLocationFormState extends State<CustomDownloadLocationForm> {
  Directory? selectedDirectory;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FormField<Directory>(
            builder: (field) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                    child: Material(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                selectedDirectory == null
                                    ? AppLocalizations.of(context)!.selectDirectory
                                    : selectedDirectory!.path.replaceFirst("${selectedDirectory!.parent.path}/", ""),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: selectedDirectory == null
                                    ? Theme.of(
                                        context,
                                      ).textTheme.titleMedium?.copyWith(color: Theme.of(context).hintColor)
                                    : Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.folder),
                              onPressed: () async {
                                String? newPath = await FilePicker.getDirectoryPath();

                                if (newPath != null) {
                                  setState(() {
                                    selectedDirectory = Directory(newPath);
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (field.hasError)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
                      child: Text(
                        field.errorText ?? AppLocalizations.of(context)!.unknownError,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                ],
              );
            },
            validator: (_) {
              if (selectedDirectory == null) {
                return AppLocalizations.of(context)!.required;
              }

              // There are a load of null checks here, but since we've already
              // checked if selectedDirectory is null we should be fine.

              if (selectedDirectory!.path == "/") {
                return AppLocalizations.of(context)!.pathReturnSlashErrorMessage;
              }

              return null;
            },
            onSaved: (_) {
              if (selectedDirectory != null) {
                context.read<NewDownloadLocation>().path = selectedDirectory!.path;
              }
            },
          ),
          TextFormField(
            decoration: InputDecoration(labelText: AppLocalizations.of(context)!.name),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return AppLocalizations.of(context)!.required;
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
          if (Platform.isIOS || Platform.isAndroid)
            Text(
              AppLocalizations.of(context)!.customLocationsBuggy,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
        ],
      ),
    );
  }
}
