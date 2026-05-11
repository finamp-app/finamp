import 'package:home_widget/home_widget.dart';


class HomeScreenWidget {
  static void initialize() {
    HomeWidget.registerInteractivityCallback(userInteraction);
    HomeWidget.saveWidgetData<String>('id', "hi, from flutter, world");
  }

  static Future<void> saveData(String id, value) async {
    await HomeWidget.saveWidgetData(id, value);
    print(("Saved widget data:", id, value));
  }

  static Future<void> reloadWidget() async {
    HomeWidget.updateWidget(
      qualifiedAndroidName: "com.unicornsonlsd.finamp.glance.HomeWidgetReceiver",
    );
  }
}

// called when the user clicks on the widget and excutes the requested function
@pragma("vm:entry-point")
Future<void> userInteraction(Uri? data) async {
  // parse Uri
  // excute requested function, pause/play/skip/back/like
}
