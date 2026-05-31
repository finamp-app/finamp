/// Formats a byte count into a human-readable string using binary (1024)
/// units. Returns "B" for under 1 KiB, "KB"/"MB"/"GB" for larger sizes.
/// Uses one decimal for KB and MB, two decimals for GB.
String formatBytes(int bytes) {
  if (bytes < 1024) {
    return "$bytes B";
  } else if (bytes < 1024 * 1024) {
    return "${(bytes / 1024).toStringAsFixed(1)} KB";
  } else if (bytes < 1024 * 1024 * 1024) {
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  } else {
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
  }
}
