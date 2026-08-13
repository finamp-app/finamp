import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/network_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

class PublicAddressSelector extends ConsumerStatefulWidget {
  const PublicAddressSelector({super.key});

  @override
  ConsumerState<PublicAddressSelector> createState() => PublicAddressSelectorState();
}

class PublicAddressSelectorState extends ConsumerState<PublicAddressSelector> {
  TextEditingController? _controller;
  FocusNode? _focusNode;
  String _lastCommittedValue = '';

  @override
  void initState() {
    super.initState();
    final address = GetIt.instance<FinampUserHelper>().currentUser?.publicAddress ?? '';
    _controller = TextEditingController(text: address);
    _lastCommittedValue = address;
    _focusNode = FocusNode();
    _focusNode!.addListener(() {
      if (!(_focusNode?.hasFocus ?? false)) {
        commitIfChanged();
      }
    });
  }

  Future<bool> _updateUrl(String url) async {
    if (url.isEmpty) return false;
    if (!url.startsWith('http')) {
      GlobalSnackbar.message((context) => AppLocalizations.of(context)!.missingSchemaError);
      return false;
    }
    GetIt.instance<FinampUserHelper>().currentUser?.update(newPublicAddress: url);
    await changeTargetUrl();
    return true;
  }

  Future<void> commitIfChanged() async {
    final current = _controller?.text.trim() ?? '';
    if (current == _lastCommittedValue) return;
    if (await _updateUrl(current)) {
      _lastCommittedValue = current;
    }
  }

  @override
  void dispose() {
    // Keyboard submit is easy to skip (Back / tap elsewhere). Persist here so
    // the public URL is not lost and replaced by the login/LAN address.
    final current = _controller?.text.trim() ?? '';
    if (current != _lastCommittedValue && current.isNotEmpty && current.startsWith('http')) {
      GetIt.instance<FinampUserHelper>().currentUser?.update(newPublicAddress: current);
    }
    _focusNode?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.preferLocalNetworkPublicAddressSettingTitle),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.preferLocalNetworkPublicAddressSettingDescription),
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            textAlign: TextAlign.center,
            style: TextTheme.of(context).bodyMedium,
            keyboardType: TextInputType.url,
            onEditingComplete: () {
              FocusScope.of(context).unfocus();
              commitIfChanged();
            },
            onSubmitted: (_) => commitIfChanged(),
          ),
        ],
      ),
    );
  }
}
