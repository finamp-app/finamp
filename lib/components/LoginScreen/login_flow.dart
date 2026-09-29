import 'dart:async';

import 'package:finamp/components/LoginScreen/login_server_selection_page.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/screens/view_selector.dart';
import 'package:finamp/services/client_certificate_installer.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/services/performance_benchmark_service.dart';
import 'package:finamp/services/server_client_discovery_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

import 'login_authentication_page.dart';
import 'login_splash_page.dart';
import 'login_user_selection_page.dart';

class LoginFlow extends StatefulWidget {
  const LoginFlow({super.key});

  @override
  State<LoginFlow> createState() => _LoginFlowState();
}

final loginNavigatorKey = GlobalKey<NavigatorState>();

class _LoginFlowState extends State<LoginFlow> {
  ServerState serverState = ServerState(discoveredServers: {});
  ConnectionState connectionState = ConnectionState();

  @override
  void dispose() {
    serverState.clientDiscoveryHandler.dispose();
    serverState.connectionTestDebounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // handle going back inside the nested Navigator while not on the first page
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (context.mounted) {
          if (!loginNavigatorKey.currentState!.canPop()) {
            Navigator.of(context).pop();
          } else {
            loginNavigatorKey.currentState!.pop();
          }
        }
      },
      child: Navigator(
        key: loginNavigatorKey,
        initialRoute: LoginSplashPage.routeName,
        onGenerateRoute: (RouteSettings settings) {
          Route route;

          Route createRoute(Widget page) => PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => page,
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              if (MediaQuery.disableAnimationsOf(context)) {
                return child;
              }
              final pushingNext = secondaryAnimation.status == AnimationStatus.forward;
              final poppingNext = secondaryAnimation.status == AnimationStatus.reverse;
              final pushingOrPoppingNext = pushingNext || poppingNext;
              late final Tween<Offset> offsetTween = pushingOrPoppingNext
                  ? Tween<Offset>(begin: const Offset(0.0, 0.0), end: const Offset(-1.0, 0.0))
                  : Tween<Offset>(begin: const Offset(1.0, 0.0), end: const Offset(0.0, 0.0));

              final curveOffsetTween = offsetTween.chain(CurveTween(curve: Curves.ease));

              late final Animation<Offset> slidingAnimation = pushingOrPoppingNext
                  ? curveOffsetTween.animate(secondaryAnimation)
                  : curveOffsetTween.animate(animation);
              return SlideTransition(position: slidingAnimation, child: child);
            },
          );

          switch (settings.name) {
            case LoginSplashPage.routeName:
              route = createRoute(
                LoginSplashPage(
                  onGetStartedPressed: () =>
                      loginNavigatorKey.currentState!.pushNamed(LoginServerSelectionPage.routeName),
                ),
              );
              break;
            case LoginServerSelectionPage.routeName:
              route = createRoute(
                LoginServerSelectionPage(
                  serverState: serverState,
                  onServerSelected: (PublicSystemInfoResult server, String baseUrl) {
                    serverState.selectedServer = server;
                    serverState.baseUrl = baseUrl;
                    serverState.clientDiscoveryHandler.stopDiscovery();
                    loginNavigatorKey.currentState!.pushNamed(LoginUserSelectionPage.routeName);
                  },
                ),
              );
              break;
            case LoginUserSelectionPage.routeName:
              route = createRoute(
                LoginUserSelectionPage(
                  serverState: serverState,
                  connectionState: connectionState,
                  onUserSelected: (UserDto? user) {
                    connectionState.selectedUser = user;
                    loginNavigatorKey.currentState!.pushNamed(LoginAuthenticationPage.routeName);
                  },
                  onAuthenticated: () {
                    Navigator.of(context).pushReplacementNamed(ViewSelector.routeName);
                  },
                ),
              );
              break;
            case LoginAuthenticationPage.routeName:
              route = createRoute(
                LoginAuthenticationPage(
                  connectionState: connectionState,
                  onAuthenticated: () {
                    Navigator.of(context).popAndPushNamed(ViewSelector.routeName);
                    final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
                    jellyfinApiHelper.updateCapabilities(
                      ClientCapabilities(
                        supportsMediaControl: true,
                        supportsPersistentIdentifier: true,
                        playableMediaTypes: ["Audio"],
                        supportedCommands: [
                          "MoveUp",
                          "MoveDown",
                          "MoveLeft",
                          "MoveRight",
                          "PageUp",
                          "PageDown",
                          "PreviousLetter",
                          "NextLetter",
                          "ToggleOsd",
                          "ToggleContextMenu",
                          "Select",
                          "Back",
                          "TakeScreenshot",
                          "SendKey",
                          "SendString",
                          "GoHome",
                          "GoToSettings",
                          "VolumeUp",
                          "VolumeDown",
                          "Mute",
                          "Unmute",
                          "ToggleMute",
                          "SetVolume",
                          "SetAudioStreamIndex",
                          "SetSubtitleStreamIndex",
                          "ToggleFullscreen",
                          "DisplayContent",
                          "GoToSearch",
                          "DisplayMessage",
                          "SetRepeatMode",
                          "ChannelUp",
                          "ChannelDown",
                          "Guide",
                          "ToggleStats",
                          "PlayMediaSource",
                          "PlayTrailers",
                          "SetShuffleQueue",
                          "PlayState",
                          "PlayNext",
                          "ToggleOsdMenu",
                          "Play",
                          "SetMaxStreamingBitrate",
                          "SetPlaybackOrder",
                        ],
                      ),
                    );
                  },
                ),
              );
              break;
            default:
              throw Exception('Invalid route: ${settings.name}');
          }
          // return MaterialPageRoute<void>(builder: builder, settings: settings);
          return route;
        },
      ),
    );
  }
}

class ServerState {
  final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  static final serverStateLogger = Logger("LoginServerState");

  static Map<String, Object?> _safeEndpoint(Uri uri) {
    final host = uri.host;
    final hostParts = host.split(".");
    final isIpv4 =
        hostParts.length == 4 &&
        hostParts.every((part) {
          final value = int.tryParse(part);
          return value != null && value >= 0 && value <= 255;
        });
    final hostType = isIpv4
        ? "ipv4"
        : host.contains(":")
        ? "ipv6"
        : "hostname";
    return {
      "scheme": uri.scheme,
      "hostType": hostType,
      "port": uri.hasPort ? uri.port : null,
      "hasPath": uri.path.isNotEmpty && uri.path != "/",
    };
  }

  static void _benchmarkConnectionDiagnostic(String stage, Uri uri, {Object? error}) {
    final values = <String, Object?>{
      "stage": stage,
      ..._safeEndpoint(uri),
      if (error != null) "errorType": error.runtimeType.toString(),
    };
    PerformanceBenchmarkService.instance.diagnostic("server-connection", values: values);
  }

  static void _logConnectionFailure(String attempt, Uri uri, Object error) {
    _benchmarkConnectionDiagnostic("$attempt-failed", uri, error: error);
    if (PerformanceBenchmarkService.enabled) {
      serverStateLogger.severe("Couldn't reach server during $attempt (${error.runtimeType})");
    } else {
      serverStateLogger.severe("Couldn't reach server at $uri during $attempt: $error");
    }
  }

  PublicSystemInfoResult? manualServer;
  Map<Uri, PublicSystemInfoResult> discoveredServers;
  PublicSystemInfoResult? selectedServer;
  String? baseUrl;
  Timer? connectionTestDebounceTimer;
  String? baseUrlToTest;
  JellyfinServerClientDiscovery clientDiscoveryHandler;
  bool clientCertificateRequired = false;
  VoidCallback? updateCallback;

  ServerState({
    required this.discoveredServers,
    this.updateCallback,
    this.manualServer,
    this.selectedServer,
    this.baseUrl,
  }) : clientDiscoveryHandler = JellyfinServerClientDiscovery();

  void onBaseUrlChanged(String baseUrl) {
    if (connectionTestDebounceTimer?.isActive ?? false) {
      connectionTestDebounceTimer?.cancel();
    }
    connectionTestDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      updateCallback?.call();
      try {
        baseUrlToTest = baseUrl;
        updateCallback?.call();
        await testServerConnection(baseUrl);
        baseUrlToTest = null;
        updateCallback?.call();
      } catch (err) {
        // nop, make sure *not* to reset the baseUrlToTest
      }
    });
  }

  Future<void> testServerConnection(String baseUrl) async {
    if (baseUrl.isEmpty) return;

    bool unspecifiedProtocol = false;
    bool unspecifiedPort = false;
    String baseUrlToTest = baseUrl.trim();

    if (!(baseUrlToTest.startsWith("http://") || baseUrlToTest.startsWith("https://"))) {
      baseUrlToTest = "https://$baseUrlToTest";
      unspecifiedProtocol = true;
    }

    final portRegex = RegExp(r"[^\/]:\d+");
    if (!portRegex.hasMatch(baseUrlToTest)) {
      unspecifiedPort = true;
    }

    if (baseUrlToTest.endsWith("/")) {
      baseUrlToTest = baseUrlToTest.substring(0, baseUrlToTest.length - 1);
    }

    jellyfinApiHelper.baseUrlTemp = Uri.parse(baseUrlToTest);

    PublicSystemInfoResult? publicServerInfo;
    var attemptUri = Uri.parse(baseUrlToTest);
    _benchmarkConnectionDiagnostic("https-attempt", attemptUri);
    try {
      publicServerInfo = await jellyfinApiHelper.loadServerPublicInfo();
      _benchmarkConnectionDiagnostic("https-success", attemptUri);
    } catch (error) {
      if (await ClientCertificateInstaller.isCertificateRequiredError(error, attemptUri)) {
        clientCertificateRequired = true;
        _benchmarkConnectionDiagnostic("client-certificate-required", attemptUri, error: error);
        return;
      } else {
        _logConnectionFailure("https", attemptUri, error);
      }
    }

    if (this.baseUrlToTest != baseUrl) {
      throw Exception("Server URL changed while testing");
    }

    if (publicServerInfo == null && unspecifiedProtocol) {
      final url = Uri.parse(baseUrlToTest).replace(scheme: "http");
      baseUrlToTest = url.toString();
      jellyfinApiHelper.baseUrlTemp = url;
      _benchmarkConnectionDiagnostic("http-fallback-attempt", url);
      try {
        publicServerInfo = await jellyfinApiHelper.loadServerPublicInfo();
        _benchmarkConnectionDiagnostic("http-fallback-success", url);
      } catch (error) {
        _logConnectionFailure("http-fallback", url, error);
      }
    }

    if (this.baseUrlToTest != baseUrl) {
      throw Exception("Server URL changed while testing");
    }

    if (publicServerInfo == null && unspecifiedPort) {
      final url = Uri.parse(baseUrlToTest).replace(port: 8096);
      baseUrlToTest = url.toString();
      jellyfinApiHelper.baseUrlTemp = url;
      _benchmarkConnectionDiagnostic("default-port-attempt", url);
      try {
        publicServerInfo = await jellyfinApiHelper.loadServerPublicInfo();
        _benchmarkConnectionDiagnostic("default-port-success", url);
      } catch (error) {
        _logConnectionFailure("default-port", url, error);
      }
    }

    if (this.baseUrlToTest != baseUrl) {
      throw Exception("Server URL changed while testing");
    }

    if (publicServerInfo != null) {
      manualServer = publicServerInfo;
      this.baseUrl = baseUrlToTest;
      _benchmarkConnectionDiagnostic("selected", Uri.parse(baseUrlToTest));
    }
  }
}

class ConnectionState {
  bool isConnected;
  bool isAuthenticating;
  QuickConnectState? quickConnectState;
  UserDto? selectedUser;

  ConnectionState({this.isConnected = false, this.isAuthenticating = false, this.quickConnectState, this.selectedUser});
}
