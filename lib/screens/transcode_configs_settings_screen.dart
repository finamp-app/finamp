/*
class BitrateSelector extends ConsumerStatefulWidget {
  const BitrateSelector({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() {
    return _BitrateSelectorState();
  }
}

class _BitrateSelectorState extends ConsumerState<BitrateSelector> {
  int currentBitrate = FinampSettingsHelper.finampSettings.transcodeBitrate;

  @override
  Widget build(BuildContext context) {
    bool enabled = ref.watch(finampSettingsProvider.transcodingStreamingFormat).codec != "flac";
    return Column(
      children: [
        ListTile(
          title: Text(AppLocalizations.of(context)!.bitrate),
          subtitle: Text(AppLocalizations.of(context)!.bitrateSubtitle),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Slider(
              min: 64,
              max: 320,
              value: (currentBitrate / 1000).clamp(64, 320),
              divisions: 8,
              label: AppLocalizations.of(context)!.kiloBitsPerSecondLabel(currentBitrate ~/ 1000),
              onChanged: enabled
                  ? (value) {
                      setState(() {
                        currentBitrate = (value * 1000).toInt();
                      });
                    }
                  : null,
              onChangeEnd: (value) {
                FinampSetters.setTranscodeBitrate((value * 1000).toInt());
              },
              autofocus: false,
              focusNode: FocusNode(skipTraversal: true, canRequestFocus: false),
            ),
            Text(
              enabled
                  ? AppLocalizations.of(context)!.kiloBitsPerSecondLabel(currentBitrate ~/ 1000)
                  : AppLocalizations.of(context)!.losslessNoBitrate,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 12),
          ],
        ),
      ],
    );
  }
}

class StreamingTranscodingFormatDropdownListTile extends ConsumerWidget {
  const StreamingTranscodingFormatDropdownListTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.transcodingStreamingFormatTitle),
      subtitle: Column(
        spacing: 4.0,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.transcodingStreamingFormatSubtitle),
          FinampSettingsDropdown<FinampTranscodingStreamingFormat>(
            dropdownItems: FinampTranscodingStreamingFormat.values
                .map(
                  (e) => DropdownMenuEntry<FinampTranscodingStreamingFormat>(
                    value: e,
                    label: "${e.codec}+${e.container}".toUpperCase(),
                  ),
                )
                .toList(),
            selectedValue: ref.watch(finampSettingsProvider.transcodingStreamingFormat),
            onSelected: FinampSetters.setTranscodingStreamingFormat.ifNonNull,
          ),
        ],
      ),
    );
  }
}
 */
