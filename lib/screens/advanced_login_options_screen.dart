import 'package:finamp/components/finamp_app_bar_back_button.dart';
import 'package:finamp/extensions/localizations.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/client_certificate_authentication_menu.dart';
import 'package:finamp/screens/accessibility_settings_screen.dart';
import 'package:finamp/screens/logs_screen.dart';
import 'package:finamp/services/client_certificate_installer.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

import '../components/Buttons/cta_medium.dart';
import '../components/LoginScreen/login_server_selection_page.dart';
import '../components/themed_bottom_sheet.dart';
import '../services/finamp_user_helper.dart';

class AdvancedLoginOptionsScreen extends ConsumerWidget {
  const AdvancedLoginOptionsScreen({super.key});

  static const routeName = "/login/advanced";

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      onPopInvokedWithResult: (_, _) {
        final state = loginServerSelectionKey.currentState;
        if (state != null && state.mounted) {
          state.retryServerURLCheck();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context)!.advanced), leading: FinampAppBarBackButton()),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 200.0),
          children: [
            ListTile(
              leading: Icon(TablerIcons.certificate),
              title: Text(AppLocalizations.of(context)!.clientCertificate),
              subtitle: Text(
                !ClientCertificateInstaller.isSupported
                    ? AppLocalizations.of(context)!.clientCertificatesUnsupported
                    : ref.watch(finampSettingsProvider.clientCertificate) != null
                    ? AppLocalizations.of(context)!.clientCertificateInstalled
                    : AppLocalizations.of(context)!.clientCertificateUnavailable,
              ),
              enabled: ClientCertificateInstaller.isSupported,
              onTap: () => showClientCertificateMenu(context: context),
            ),
            ListTile(
              leading: Icon(TablerIcons.circle_key),
              title: Text(AppLocalizations.of(context)!.customHeaders),
              onTap: () => showCustomHeadersMenu(context: context),
            ),
            ListTile(
              leading: const Icon(TablerIcons.accessible),
              title: Text(AppLocalizations.of(context)!.accessibility),
              onTap: () => Navigator.of(context).pushNamed(AccessibilitySettingsScreen.routeName),
            ),
            ListTile(
              leading: const Icon(TablerIcons.file_text),
              title: Text(AppLocalizations.of(context)!.viewLogs),
              onTap: () => Navigator.of(context).pushNamed(LogsScreen.routeName),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showCustomHeadersMenu({required BuildContext context}) async {
  await showThemedBottomSheet<void>(
    context: context,
    routeName: clientCertificateAuthenticationRouteName,
    minDraggableHeight: 0.9,
    useRootNavigator: true,
    buildSlivers: (context) {
      var menu = [
        SliverStickyHeader(
          header: Padding(
            padding: const EdgeInsets.only(top: 6.0, bottom: 16.0),
            child: Center(
              child: Text(
                AppLocalizations.of(context)!.customHeaders,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
              ),
            ),
          ),
          sliver: MenuMask(
            height: const MenuMaskHeight(40.0),
            child: SliverToBoxAdapter(child: CustomHeadersMenu()),
          ),
        ),
      ];
      const stackHeight = 250.0;
      return (stackHeight, menu);
    },
  );
}

class CustomHeadersMenu extends StatefulWidget {
  const CustomHeadersMenu({super.key});

  @override
  State<CustomHeadersMenu> createState() => _CustomHeadersMenuState();
}

class _CustomHeadersMenuState extends State<CustomHeadersMenu> {
  /// This list can contain null entries so that list tiles can consistently key by index when we delete items
  late final List<MapEntry<String, String>?> customHeaders;

  @override
  void initState() {
    customHeaders = List<MapEntry<String, String>?>.of(
      GetIt.instance<JellyfinApiHelper>().customHeadersTemp?.entries ?? [],
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      child: Column(
        spacing: 10,
        children: [
          for (int i = 0; i < customHeaders.length; i++)
            if (customHeaders[i] != null)
              CustomHeadersTile(
                customHeaders: customHeaders,
                index: i,
                delete: () => setState(() {
                  customHeaders[i] = null;
                }),
              ),
          FractionallySizedBox(
            widthFactor: 0.9,
            child: CTAMedium(
              text: context.l10n.addButtonLabel,
              icon: TablerIcons.plus,
              onPressed: () => setState(() {
                customHeaders.add(MapEntry("", ""));
              }),
            ),
          ),
          Builder(
            builder: (context) {
              return FractionallySizedBox(
                widthFactor: 0.9,
                child: CTAMedium(
                  text: context.l10n.save,
                  icon: TablerIcons.device_floppy,
                  onPressed: () => setState(() {
                    // First save off form entries to customHeaders, then validate against that
                    Form.of(context).save();
                    final valid = Form.of(context).validate();
                    if (valid) {
                      GetIt.instance<JellyfinApiHelper>().customHeadersTemp = Map.fromEntries(customHeaders.nonNulls);
                      Navigator.of(context).maybePop();
                    }
                  }),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class CustomHeadersTile extends StatelessWidget {
  const CustomHeadersTile({super.key, required this.index, required this.customHeaders, required this.delete});

  final int index;
  final List<MapEntry<String, String>?> customHeaders;
  final void Function() delete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minVerticalPadding: 0,
      title: Align(
        alignment: AlignmentGeometry.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 250),
          child: TextFormField(
            key: ValueKey(index),
            initialValue: customHeaders[index]!.key,
            decoration: InputDecoration(
              filled: true,
              fillColor: Color.alphaBlend(
                ColorScheme.of(context).onSurface.withValues(alpha: 0.1),
                ColorScheme.of(context).surface,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              floatingLabelBehavior: FloatingLabelBehavior.never,
              border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(8)),
            ),
            onSaved: (newString) {
              customHeaders[index] = MapEntry(newString ?? "", customHeaders[index]!.value);
            },
            validator: (newString) {
              if (newString == null || newString == "") return context.l10n.required;
              if (newString == FinampUserHelper.httpAuthorizationHeader) return context.l10n.httpHeaderNotAuth;
              int count = 0;
              for (final field in customHeaders) {
                if (field?.key == newString) {
                  count++;
                }
              }
              if (count != 1) {
                return context.l10n.httpHeaderConflict;
              }
              return null;
            },
          ),
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(left: 50, top: 1),
        child: TextFormField(
          key: ValueKey(index),
          initialValue: customHeaders[index]!.value,
          decoration: InputDecoration(
            filled: true,
            fillColor: Color.alphaBlend(
              ColorScheme.of(context).onSurface.withValues(alpha: 0.1),
              ColorScheme.of(context).surface,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            floatingLabelBehavior: FloatingLabelBehavior.never,
            border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(8)),
          ),
          validator: (newString) {
            if (newString == null || newString == "") return context.l10n.required;
            return null;
          },
          onSaved: (newString) {
            customHeaders[index] = MapEntry(customHeaders[index]!.key, newString ?? "");
          },
        ),
      ),
      trailing: IconButton(onPressed: delete, icon: Icon(TablerIcons.trash)),
    );
  }
}
