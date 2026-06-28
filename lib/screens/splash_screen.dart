import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/screens/login_screen.dart';
import 'package:finamp/screens/music_screen.dart';
import 'package:finamp/screens/view_selector.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  static const routeName = "/";

  @override
  Widget build(BuildContext context) {
    final finampUserHelper = GetIt.instance<FinampUserHelper>();

    if (finampUserHelper.currentUser == null) {
      return const LoginScreen();
    } else if (finampUserHelper.currentUser!.currentView == null) {
      return const ViewSelector();
    } else {
      return const MusicScreen();
    }
  }
}
