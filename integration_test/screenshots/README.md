# Screenshot Automation

This project is set up with Screenshot automation. To automate away, there are a few things to consider:

## Screenshot Infrastructure

The screenshot manager from [tief_screen](https://github.com/Tiefseetauchner/tief_screen) is being used as a backbone for capturing screenshots. See applicable documentation for more.

Screenshots are taken after a test completes. That means, at the end of your test, there needs to be a steady, correct state. **Whatever the state of a widget is at the end of the test is the state it will be captured in.**

To transport screenshots from the emulator to the host, the `screenshot_server` is used. Run the screenshot server via `dart run tief_screen:screenshot_server` before the test. It will create a folder `screenshots` in the pwd and place the screenshots in there, grouped by harness.

## Harnesses

For test management, especially for performance reasons on emulators, the tests are collected by [tief_test_harness](https://github.com/Tiefseetauchner/tief_test_harness). Here, the harnesses are grouped by the emulator they would be run on.

A harness is created by a function which is registered via `@RegisterHarness("main", name: "Harness (Screen) Name")`. **After adding or modifying a harness registration, the build_runner must be run.**

The function declaration should look something like this, then:

```dart
@RegisterHarness("main", name: "Downloads Screen")
Future<ScenarioHarness> buildDownloadsScreenHarness() async {
  // Building the harness and adding scenarios
}
```

This harness builder is then automatically (or rather, through build_runner) registered to the `main` harness and, when running the tests (see below) automatically executed.

## Emulators

Use `avdmanager create avd -n "finampemu" -k "system-images;android-36;default;x86_64" --device "Nexus 5"` to create an emulator. Resize it to fit your need by changing `~/.android/avd/finampemu.avd/config.ini`. E.g.:

```ini
hw.lcd.height=1920
hw.lcd.width=1080
hw.lcd.density=400
```

Creates a 9:16 phone. Start the emulator with `emulator @finampemu`.

## Tests

Run tests via `flutter test integration_test/screenshots`. This will detect all `*_test.dart` files, which in our case is the `main_harness_test.dart`.

Tests take environment variables to set your server and authorization. Use with `-D JELLYFIN_SERVER=<YOUR_SERVER> -D JELLYFIN_USER=<YOUR_USER> -D JELLYFIN_PASSWORD=<YOUR_PASSWORD>`.

Additionally, you can define `-D HARNESSES="Harness 1","Harness 2"` to only run specific harnesses.
