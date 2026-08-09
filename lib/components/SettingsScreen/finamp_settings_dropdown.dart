import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class FinampSettingsDropdown<T> extends StatelessWidget {
  const FinampSettingsDropdown({
    super.key,
    required this.dropdownItems,
    required this.selectedValue,
    required this.onSelected,
    this.selectedIcon,
  });

  final List<DropdownMenuEntry<T>> dropdownItems;
  final T? selectedValue;
  final IconData? selectedIcon;
  final void Function(T?) onSelected;

  @override
  Widget build(BuildContext context) {
    final defaultEntryStyle = ButtonStyle(
      padding: WidgetStateProperty.all<EdgeInsets>(const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0)),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return DropdownMenu<T>(
          width: constraints.maxWidth,
          dropdownMenuEntries: dropdownItems
              .map(
                (e) => DropdownMenuEntry<T>(
                  value: e.value,
                  label: e.label,
                  leadingIcon: e.leadingIcon,
                  trailingIcon: e.trailingIcon,
                  enabled: e.enabled,
                  style: e.style ?? defaultEntryStyle,
                ),
              )
              .toList(),
          initialSelection: selectedValue,
          enableFilter: false,
          enableSearch: false,
          requestFocusOnTap: false,
          onSelected: onSelected,
          textStyle: Theme.of(context).textTheme.bodyMedium,
          leadingIcon: selectedIcon != null ? Icon(selectedIcon) : null,
          trailingIcon: const Icon(TablerIcons.chevron_down),
          selectedTrailingIcon: const Icon(TablerIcons.chevron_up),
          menuStyle: MenuStyle(
            shape: WidgetStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            ),
            backgroundColor: WidgetStateProperty.all<Color>(
              Color.alphaBlend(ColorScheme.of(context).onSurface.withOpacity(0.2), ColorScheme.of(context).surface),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide.none),
            filled: true,
            fillColor: Color.alphaBlend(
              ColorScheme.of(context).primary.withOpacity(0.075),
              ColorScheme.of(context).onSurface.withOpacity(0.1),
            ),
            visualDensity: VisualDensity(horizontal: -4.0, vertical: -4.0),
            errorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.only(left: 8.0),
          ),
        );
      },
    );
  }
}
