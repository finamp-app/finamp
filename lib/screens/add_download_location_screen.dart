import 'dart:io';

import 'package:flutter/material.dart';
import 'package:finamp/components/finamp_app_bar_back_button.dart';
import 'package:path/path.dart' as path_helper;
import 'package:provider/provider.dart';
import 'package:uuid/v4.dart';
import 'package:finamp/components/AddDownloadLocationScreen/app_directory_location_form.dart';
import 'package:finamp/components/AddDownloadLocationScreen/custom_download_location_form.dart';
import 'package:finamp/components/confirmation_prompt_dialog.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/l10n/app_localizations.dart';

class AddDownloadLocationScreen extends StatefulWidget {
  const AddDownloadLocationScreen({super.key});

  static const routeName = "/settings/downloadlocations/add";

  @override
  State<AddDownloadLocationScreen> createState() => _AddDownloadLocationScreenState();
}

class _AddDownloadLocationScreenState extends State<AddDownloadLocationScreen> with SingleTickerProviderStateMixin {
  final customLocationFormKey = GlobalKey<FormState>();
  final appDirectoryFormKey = GlobalKey<FormState>();

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Since we can't initialise tabs before initState we need to awkwardly
    // provide the length directly
    _tabController = TabController(vsync: this, length: Platform.isAndroid ? 2 : 1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = Platform.isAndroid
        ? [
            Tab(text: AppLocalizations.of(context)!.customLocation.toUpperCase()),
            Tab(text: AppLocalizations.of(context)!.appDirectory.toUpperCase()),
          ]
        : [Tab(text: AppLocalizations.of(context)!.customLocation.toUpperCase())];
    return Provider<NewDownloadLocation>(
      create: (_) => NewDownloadLocation(name: null, baseDirectory: DownloadLocationType.none),
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(AppLocalizations.of(context)!.addDownloadLocation),
            leading: FinampAppBarBackButton(),
            bottom: TabBar(controller: _tabController, tabs: tabs),
          ),
          floatingActionButton: FloatingActionButton(
            child: const Icon(Icons.check),
            onPressed: () async {
              bool isValidated = false;

              // If _tabController.index is 0, we are on the custom location tab.
              // If not, we are on the app directory tab.
              if (_tabController.index == 0) {
                if (customLocationFormKey.currentState?.validate() ?? false) {
                  customLocationFormKey.currentState!.save();
                  // If we're saving to a custom location, we want to use human readable names.
                  // With app dir locations, we don't use human readable names.
                  context.read<NewDownloadLocation>().baseDirectory = DownloadLocationType.custom;
                  isValidated = true;
                }
              } else {
                if (appDirectoryFormKey.currentState?.validate() ?? false) {
                  appDirectoryFormKey.currentState!.save();
                  context.read<NewDownloadLocation>().baseDirectory = DownloadLocationType.external;
                  isValidated = true;
                }
              }

              // We set a variable called isValidated so that we don't have to copy this logic into each validate()
              if (isValidated) {
                final newDownloadLocation = context.read<NewDownloadLocation>();

                // We don't use DownloadLocation when initially getting the
                // values because DownloadLocation doesn't have nullable values.
                // At this point, the NewDownloadLocation shouldn't have any
                // null values.
                final downloadLocation = await DownloadLocation.create(
                  name: newDownloadLocation.name!,
                  relativePath: newDownloadLocation.path!,
                  baseDirectory: newDownloadLocation.baseDirectory,
                );

                if (!context.mounted) return;

                final imageTest = File(path_helper.join(downloadLocation.currentPath, "__${UuidV4().generate()}.jpg"));
                final songTest = File(path_helper.join(downloadLocation.currentPath, "__${UuidV4().generate()}.mp3"));
                bool songPassed = false;

                try {
                  songTest.createSync(recursive: true);
                  songPassed = true;
                  imageTest.createSync(recursive: true);
                } on FileSystemException {
                  await showDialog<dynamic>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(AppLocalizations.of(context)!.addDownloadLocationsErrorTitle),
                      content: Text(
                        // If song writes succeed but image writes fail, assume we are in the android Music folder.
                        songPassed
                            ? AppLocalizations.of(context)!.androidImageErrorPrompt
                            : AppLocalizations.of(context)!.addDownloadLocationsErrorPrompt,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(AppLocalizations.of(context)!.close),
                        ),
                      ],
                    ),
                  );

                  return;
                } finally {
                  if (songTest.existsSync()) {
                    songTest.deleteSync();
                  }
                  if (imageTest.existsSync()) {
                    imageTest.deleteSync();
                  }
                }

                FinampSettingsHelper.addDownloadLocation(downloadLocation);
                if (!context.mounted) return;
                Navigator.of(context).pop();
              }
            },
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CustomDownloadLocationForm(formKey: customLocationFormKey),
                ),
              ),
              if (Platform.isAndroid)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: AppDirectoryLocationForm(formKey: appDirectoryFormKey),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
