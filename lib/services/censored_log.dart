import 'package:finamp/services/contains_login.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

import 'case_insensitive_pattern.dart';
import 'finamp_user_helper.dart';

extension CensoredMessage on LogRecord {
  /// The uncensored log string to be shown to the user
  String get logString =>
      "[$loggerName/${level.name}] $time: $message${getStack == null ? "" : "\n${getStack.toString()}"}";

  StackTrace? get getStack {
    var stack = stackTrace;
    if (error is Error) {
      stack ??= (error as Error).stackTrace;
    }
    if (object is Error) {
      stack ??= (object as Error).stackTrace;
    }
    return stack;
  }

  String get loginCensoredMessage => containsLogin ? "LOGIN BODY" : message;

  String get censoredMessage {
    if (containsLogin) {
      return loginCensoredMessage;
    }

    String workingLogString = logString;

    // If userHelper is not initialized, calling code cannot have used baseurl/token
    // so skipping censoring is fine.
    if (GetIt.instance.isRegistered<FinampUserHelper>()) {
      final user = GetIt.instance<FinampUserHelper>().currentUser;

      if (user != null) {
        var useLocal = user.isLocal && user.preferLocalNetwork;
        workingLogString = workingLogString.replaceAll(
          CaseInsensitivePattern(user.localAddress),
          "HOMEURL${!useLocal ? "(INACTIVE)" : ""}",
        );
        workingLogString = workingLogString.replaceAll(
          CaseInsensitivePattern(user.publicAddress),
          "PUBLICURL${useLocal ? "(INACTIVE)" : ""}",
        );
        workingLogString = workingLogString.replaceAll(CaseInsensitivePattern(user.accessToken), "TOKEN");
        workingLogString = workingLogString.replaceAll(CaseInsensitivePattern(user.id), "USER_ID");

        for (final headerVal in user.customHeaders.values) {
          workingLogString = workingLogString.replaceAll(CaseInsensitivePattern(headerVal), "HTTP-TOKEN");
        }
      }
    }

    // If we are currently logging in, there may be a temp URL to censor.
    // Check after normal URL replacement to prefer that if both urls are set.
    if (GetIt.instance.isRegistered<JellyfinApiHelper>()) {
      final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();

      if (jellyfinApiHelper.baseUrlTemp != null) {
        // Replace the temporary base URL with BASEURL
        final tempUriMatcher = jellyfinApiHelper.baseUrlTemp!;
        tempUriMatcher.replace(scheme: ""); // don't replace the scheme, it might be important for diagnosing issues
        workingLogString = workingLogString.replaceAll(
          CaseInsensitivePattern(tempUriMatcher.toString()),
          "TEMP_BASEURL",
        );

        // remove anything between the quotes in "Failed host lookup: ''"
        workingLogString = workingLogString.replaceAll(
          CaseInsensitivePattern(tempUriMatcher.host.toString()),
          "TEMP_HOST",
        );
      }

      // Replace the host and port values in network errors
      workingLogString = workingLogString.replaceAllMapped(
        RegExp(r"(host: )([^,]+)(, port: )(\d+)", caseSensitive: false),
        (match) => "${match[1]}HOST${match[3]}PORT",
      );

      workingLogString = workingLogString.replaceAllMapped(
        RegExp(r"(Failed host lookup: ')([^']+)(')", caseSensitive: false),
        (match) => "${match[1]}HOST${match[3]}",
      );

      workingLogString = workingLogString.replaceAllMapped(
        RegExp(r"(address = )([^,]+)(, port = )(\d+)", caseSensitive: false),
        (match) => "${match[1]}HOST${match[3]}PORT",
      );
    }

    workingLogString = workingLogString.replaceAll("\n", "\n\t\t");

    return workingLogString;
  }
}
