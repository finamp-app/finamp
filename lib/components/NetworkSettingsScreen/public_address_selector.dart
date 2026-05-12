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
  ConsumerState<PublicAddressSelector> createState() => _PublicAddressSelector();
}

class _PublicAddressSelector extends ConsumerState<PublicAddressSelector> {
  TextEditingController? _controller;

  @override
  void dispose() {
    super.dispose();
    _controller?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String? publicAddress = ref.watch(FinampUserHelper.finampCurrentUserProvider)?.publicAddress;

    _controller ??= TextEditingController(text: publicAddress.toString());

    return ListTile(
      title: Text(AppLocalizations.of(context)!.preferLocalNetworkPublicAddressSettingTitle),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.preferLocalNetworkPublicAddressSettingDescription),
          TextField(
            controller: _controller,
            textAlign: TextAlign.center,
            style: TextTheme.of(context).bodyMedium,
            keyboardType: TextInputType.url,
            onSubmitted: (value) async {
              if (!value.startsWith("http")) {
                return GlobalSnackbar.message((context) => AppLocalizations.of(context)!.missingSchemaError);
              }
              GetIt.instance<FinampUserHelper>().currentUser?.update(newPublicAddress: value);
              await changeTargetUrl();
            },
          ),
        ],
      ),
    );
  }
}
