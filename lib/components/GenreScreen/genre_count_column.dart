import 'package:flutter/material.dart';

Widget buildCountColumn({
  required int? count,
  required String label,
  required VoidCallback onTap,
  Color? textColor,
  Color? subtitleColor,
  Color? borderColor,
  Color? backgroundColor,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor ?? Colors.black.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count?.toString() ?? '-',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor ?? Colors.black),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: subtitleColor ?? Colors.grey)),
        ],
      ),
    ),
  );
}
