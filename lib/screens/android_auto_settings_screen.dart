import 'package:finamp/models/finamp_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/SettingsScreen/finamp_settings_dropdown.dart';
import '../services/finamp_settings_helper.dart';

class AndroidAutoSettingsScreen extends StatefulWidget {
  const AndroidAutoSettingsScreen({super.key});
  static const routeName = "/settings/androidAuto";

  @override
  State<AndroidAutoSettingsScreen> createState() => _AndroidAutoSettingsScreenState();
}

class _AndroidAutoSettingsScreenState extends State<AndroidAutoSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Android Auto"),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 200.0),
        children: const [
          AndroidAutoBrowsingModeDropdown(),
        ],
      ),
    );
  }
}

class AndroidAutoBrowsingModeDropdown extends ConsumerWidget {
  const AndroidAutoBrowsingModeDropdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(finampSettingsProvider.androidAutoBrowsingMode);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Albums & Artists Browsing",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            "Choose how to browse Albums and Artists in Android Auto",
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          FinampSettingsDropdown<AndroidAutoBrowsingMode>(
            dropdownItems: [
              DropdownMenuEntry(
                value: AndroidAutoBrowsingMode.flat,
                label: "Flat list (paginated)",
              ),
              DropdownMenuEntry(
                value: AndroidAutoBrowsingMode.letterFirst,
                label: "Letter-first (A-Z)",
              ),
            ],
            selectedValue: currentMode,
            onSelected: (value) {
              if (value != null) {
                FinampSetters.setAndroidAutoBrowsingMode(value);
              }
            },
          ),
        ],
      ),
    );
  }
}
