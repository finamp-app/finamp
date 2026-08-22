import 'dart:async';

import 'package:balanced_text/balanced_text.dart';
import 'package:finamp/components/themed_bottom_sheet.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/services/feedback_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

const quickConnectAuthorizationMenuRouteName = "/quick-connect-authorization-menu";

Future<void> showQuickConnectAuthorizationMenu({required BuildContext context}) async {
  FeedbackHelper.feedback(FeedbackType.selection);

  await showThemedBottomSheet<void>(
    context: context,
    routeName: quickConnectAuthorizationMenuRouteName,
    minDraggableHeight: 0.60,
    buildSlivers: (context) {
      var menu = [
        SliverStickyHeader(
          header: ServerSharingPanelHeader(),
          sliver: MenuMask(
            height: ServerSharingPanelHeader.defaultHeight,
            child: SliverToBoxAdapter(child: QuickConnectInput()),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.only(left: 32.0, right: 32.0, top: 16.0),
          sliver: SliverToBoxAdapter(
            child: BalancedText(
              AppLocalizations.of(context)!.quickConnectAuthorizationMenuDescription,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ),
        SliverPadding(padding: EdgeInsets.only(bottom: 40.0)),
      ];
      var stackHeight = MediaQuery.heightOf(context) * 0.65;
      return (stackHeight, menu);
    },
  );
}

class QuickConnectInput extends StatefulWidget {
  const QuickConnectInput({super.key});

  @override
  State<QuickConnectInput> createState() => _QuickConnectInputState();
}

enum QuickConnectAuthorizationState { waitingForInput, processing, success, failed }

class _QuickConnectInputState extends State<QuickConnectInput> {
  final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final TextEditingController _controller = TextEditingController();
  QuickConnectAuthorizationState _state = QuickConnectAuthorizationState.waitingForInput;

  Future<void> _authorizeQuickConnect() async {
    if ([QuickConnectAuthorizationState.processing, QuickConnectAuthorizationState.success].contains(_state)) {
      return;
    }
    final code = _controller.text.trim();
    if (code.isEmpty) return;

    setState(() => _state = QuickConnectAuthorizationState.processing);
    FeedbackHelper.feedback(FeedbackType.selection);

    try {
      // Call the authorization method
      final success = await jellyfinApiHelper.authorizeQuickConnect(code: code);
      if (mounted) {
        setState(
          () => _state = success ? QuickConnectAuthorizationState.success : QuickConnectAuthorizationState.failed,
        );
      }

      if (!success) {
        // If the authorization failed, we don't pop immediately
        return;
      }
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 1500)).then((_) {
          if (mounted) {
            Navigator.pop(context);
          }
        }),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _state = QuickConnectAuthorizationState.failed);
      }
    }
  }

  Widget get _feedbackIcon {
    return switch (_state) {
      QuickConnectAuthorizationState.waitingForInput => const SizedBox.shrink(),
      QuickConnectAuthorizationState.processing => SizedBox(
        width: 24.0,
        height: 24.0,
        child: CircularProgressIndicator(
          strokeCap: StrokeCap.round,
          strokeWidth: 3.5,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      QuickConnectAuthorizationState.success => Icon(
        TablerIcons.lock_check,
        color: Theme.of(context).colorScheme.primary,
        size: 28.0,
      ),
      QuickConnectAuthorizationState.failed => Icon(
        TablerIcons.lock_exclamation,
        color: Theme.of(context).colorScheme.error,
        size: 28.0,
      ),
    };
  }

  Widget _getFeedbackWidget() {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 80.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 10.0,
        children: [
          if (_state != QuickConnectAuthorizationState.waitingForInput)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 8.0,
              children: [
                Center(child: _feedbackIcon),
                Text(
                  switch (_state) {
                    QuickConnectAuthorizationState.processing => AppLocalizations.of(
                      context,
                    )!.quickConnectAuthorizationMenuStateTitleProcessing,
                    QuickConnectAuthorizationState.success => AppLocalizations.of(
                      context,
                    )!.quickConnectAuthorizationMenuStateTitleSuccess,
                    QuickConnectAuthorizationState.failed => AppLocalizations.of(
                      context,
                    )!.quickConnectAuthorizationMenuStateTitleFailed,
                    _ => "",
                  },
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          if ([QuickConnectAuthorizationState.failed, QuickConnectAuthorizationState.waitingForInput].contains(_state))
            Text(
              switch (_state) {
                QuickConnectAuthorizationState.waitingForInput => AppLocalizations.of(
                  context,
                )!.quickConnectAuthorizationMenuStateSubtitleIdle,
                QuickConnectAuthorizationState.failed => AppLocalizations.of(
                  context,
                )!.quickConnectAuthorizationMenuStateSubtitleFailed,
                _ => "",
              },
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w400),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (_controller.text.trim().length >= 6) {
        // Automatically authorize when the code is long enough
        _authorizeQuickConnect();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _getFeedbackWidget(),
          const SizedBox(height: 16.0),
          QuickConnectInputField(controller: _controller, onSubmitted: () => _authorizeQuickConnect()),
        ],
      ),
    );
  }
}

class QuickConnectInputField extends StatefulWidget {
  const QuickConnectInputField({super.key, required this.controller, required this.onSubmitted});

  final TextEditingController controller;
  final VoidCallback onSubmitted;

  @override
  State<QuickConnectInputField> createState() => _QuickConnectInputFieldState();
}

class _QuickConnectInputFieldState extends State<QuickConnectInputField> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            _focusNode.requestFocus();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) {
                final text = widget.controller.text;
                final hasDigit = index < text.length;
                final digit = hasDigit ? text[index] : '';

                return Container(
                  width: 48,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: index == text.length && _focusNode.hasFocus
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 2.0,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      hasDigit ? digit : '_',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontSize: 32,
                        fontWeight: hasDigit ? FontWeight.w600 : FontWeight.w200,
                        color: hasDigit
                            ? Theme.of(context).textTheme.bodyLarge?.color
                            : Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.4),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        // Hidden text field for actual input handling
        Visibility(
          visible: false,
          maintainFocusability: true,
          maintainState: true,
          maintainInteractivity: true,
          maintainSize: true,
          maintainAnimation: true,
          maintainSemantics: true,
          child: SizedBox.shrink(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              maxLength: 6,
              keyboardType: TextInputType.number,
              autofocus: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              enableInteractiveSelection: true,
              scrollPadding: EdgeInsets.zero,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              onSubmitted: (_) => widget.onSubmitted(),
              // onTapOutside: (_) => setState(() {
              //   _focusNode.unfocus();
              // }),
            ),
          ),
        ),
        const SizedBox(height: 8.0),
        Text(
          AppLocalizations.of(context)!.quickConnectAuthorizationMenuInputLabel,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class ServerSharingPanelHeader extends StatelessWidget {
  const ServerSharingPanelHeader({super.key});

  static const defaultHeight = MenuMaskHeight(36.0);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6.0, bottom: 16.0),
      child: Center(
        child: Text(
          AppLocalizations.of(context)!.quickConnectAuthorizationMenuTitle,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge!.color!,
            fontSize: 18,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
