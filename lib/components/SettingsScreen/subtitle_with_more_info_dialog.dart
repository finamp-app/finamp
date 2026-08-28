import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class SubtitleWithMoreInfoDialog extends StatelessWidget {
  const SubtitleWithMoreInfoDialog({
    super.key,
    required this.subtitle,
    required this.dialogTitle,
    required this.dialogContent,
  });

  final String subtitle;
  final String dialogTitle;
  final String dialogContent;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(text: subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const TextSpan(text: "\n"),
          // tappable "more info" text
          TextSpan(
            text: AppLocalizations.of(context)!.moreInfo,
            style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.w500),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                showGeneralDialog(
                  barrierDismissible: true,
                  barrierLabel: AppLocalizations.of(context)!.close,
                  context: context,
                  pageBuilder: (context, anim1, anim2) {
                    return AlertDialog(
                      title: Text(dialogTitle),
                      content: SingleChildScrollView(child: Text(dialogContent)),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text(AppLocalizations.of(context)!.close),
                        ),
                      ],
                    );
                  },
                );
              },
          ),
        ],
      ),
    );
  }
}
