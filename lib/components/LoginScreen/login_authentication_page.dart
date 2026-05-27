import 'package:finamp/components/Buttons/cta_medium.dart';
import 'package:finamp/components/Buttons/simple_button.dart';
import 'package:finamp/components/finamp_icon.dart';
import 'package:finamp/components/LoginScreen/login_user_selection_page.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

import 'login_flow.dart';

class LoginAuthenticationPage extends StatefulWidget {
  static const routeName = "login/authentication";

  final ConnectionState? connectionState;
  final VoidCallback? onAuthenticated;

  const LoginAuthenticationPage({super.key, required this.connectionState, required this.onAuthenticated});

  @override
  State<LoginAuthenticationPage> createState() => _LoginAuthenticationPageState();
}

class _LoginAuthenticationPageState extends State<LoginAuthenticationPage> {
  static final _loginAuthenticationPageLogger = Logger("LoginAuthenticationPage");

  final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();

  String? username;
  String? password;
  String? authToken;
  PublicSystemInfoResult? serverInfo;

  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.connectionState?.selectedUser != null) {
      username = widget.connectionState?.selectedUser?.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 120),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Center(
          child: Column(
            children: [
              Padding(padding: const EdgeInsets.only(top: 32.0, bottom: 20.0), child: FinampIcon(75, 75)),
              Text(
                AppLocalizations.of(context)!.loginFlowAuthenticationHeading,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 20.0, bottom: 12.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SimpleButton(
                    icon: TablerIcons.chevron_left,
                    text: AppLocalizations.of(context)!.backToAccountSelection,
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ),
              JellyfinUserWidget(user: widget.connectionState?.selectedUser),
              _buildLoginForm(context),
              const SizedBox(height: 16),
              CTAMedium(
                text: AppLocalizations.of(context)!.login,
                icon: TablerIcons.login_2,
                onPressed: () async => await sendForm(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Form _buildLoginForm(BuildContext context) {
    // This variable is for handling shifting focus when the user presses submit.
    // https://stackoverflow.com/questions/52150677/how-to-shift-focus-to-next-textfield-in-flutter
    final node = FocusScope.of(context);

    InputDecoration inputFieldDecoration(String placeholder) {
      return InputDecoration(
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        label: Text(placeholder),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(16)),
      );
    }

    return Form(
      key: formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 2.0, left: 8.0),
              child: Text(AppLocalizations.of(context)!.username, textAlign: TextAlign.start),
            ),
            TextFormField(
              autocorrect: false,
              keyboardType: TextInputType.text,
              autofillHints: const [AutofillHints.username],
              decoration: inputFieldDecoration(AppLocalizations.of(context)!.usernameHint),
              textInputAction: TextInputAction.next,
              onEditingComplete: () => node.nextFocus(),
              initialValue: username,
              onSaved: (newValue) => username = newValue,
              validator: (value) {
                if (value?.isEmpty == true) {
                  return AppLocalizations.of(context)!.usernameValidationMissingUsername;
                }
                return null;
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 2.0, left: 8.0),
              child: Text(AppLocalizations.of(context)!.password, textAlign: TextAlign.start),
            ),
            TextFormField(
              autocorrect: false,
              obscureText: true,
              keyboardType: TextInputType.visiblePassword,
              autofillHints: const [AutofillHints.password],
              decoration: inputFieldDecoration(AppLocalizations.of(context)!.passwordHint),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) async => await sendForm(),
              onSaved: (newValue) => password = newValue,
            ),
          ],
        ),
      ),
    );
  }

  /// Function to handle logging in for Widgets, including a snackbar for errors.
  Future<void> loginHelper({required String username, String? password, required BuildContext context}) async {
    JellyfinApiHelper jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();

    try {
      if (password == null) {
        await jellyfinApiHelper.authenticateViaName(username: username);
      } else {
        await jellyfinApiHelper.authenticateViaName(username: username, password: password);
      }

      if (!mounted) return;
      widget.onAuthenticated?.call();
    } catch (e) {
      GlobalSnackbar.error(e);

      // We return here to stop the function from continuing.
      return;
    }
  }

  Future<void> sendForm() async {
    if ((formKey.currentState?.validate() ?? false) && !widget.connectionState!.isAuthenticating) {
      formKey.currentState!.save();
      setState(() {
        widget.connectionState!.isAuthenticating = true;
      });
      await loginHelper(username: username!, password: password, context: context);
      setState(() {
        widget.connectionState!.isAuthenticating = false;
      });
    }
  }
}
