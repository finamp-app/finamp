import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/network_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

class LocalNetworkAddressSelector extends ConsumerStatefulWidget {
  const LocalNetworkAddressSelector({super.key});

  @override
  ConsumerState<LocalNetworkAddressSelector> createState() => LocalNetworkAddressSelectorState();
}

class LocalNetworkAddressSelectorState extends ConsumerState<LocalNetworkAddressSelector> {
  TextEditingController? _controller;
  FocusNode? _focusNode;
  String _lastCommittedValue = '';

  @override
  void initState() {
    super.initState();
    FinampUser? user = GetIt.instance<FinampUserHelper>().currentUser;
    String address = user?.localAddress ?? DefaultSettings.localNetworkAddress;
    _controller ??= TextEditingController(text: address);
    if (_lastCommittedValue.isEmpty) {
      _lastCommittedValue = address;
    }
    _focusNode = FocusNode();
    _focusNode!.addListener(() {
      if (!(_focusNode?.hasFocus ?? false)) {
        commitIfChanged();
      }
    });
  }

  Future<void> _updateUrl(String url) async {
    if (url.isEmpty) return; // Ignore empty
    if (!url.startsWith('http')) {
      GlobalSnackbar.message((context) => AppLocalizations.of(context)!.missingSchemaError);
      return;
    }
    GetIt.instance<FinampUserHelper>().currentUser?.update(newLocalAddress: url);
    await changeTargetUrl();
  }

  Future<void> commitIfChanged() async {
    final current = _controller?.text.trim() ?? '';
    if (current == _lastCommittedValue) return;
    _lastCommittedValue = current;
    await _updateUrl(current);
  }

  @override
  void dispose() {
    _focusNode?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    FinampUser? user = ref.watch(FinampUserHelper.finampCurrentUserProvider);
    bool featureEnabled = user?.preferLocalNetwork ?? DefaultSettings.preferLocalNetwork;

    return ListTile(
      enabled: featureEnabled,
      title: Text(AppLocalizations.of(context)!.preferLocalNetworkTargetAddressLocalSettingTitle),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.preferLocalNetworkTargetAddressLocalSettingDescription),
          TextField(
            enabled: featureEnabled,
            controller: _controller,
            focusNode: _focusNode,
            style: TextTheme.of(context).bodyMedium,
            textAlign: TextAlign.center,
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
