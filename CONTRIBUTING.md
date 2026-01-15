# Contributing to Finamp

Thanks for your interest in contributing to Finamp! This document goes over how to get started on Finamp development, and other ways to contribute.

## Setting up a Development Environment

Finamp is a fairly standard Flutter app, so all you have to do is [install Flutter](https://docs.flutter.dev/get-started/install). Once Flutter is installed, you should be able to run Finamp on emulators/real devices.  
After installing Flutter you can check if every need component is installed by running:

```bash
flutter doctor -v
```

This will list out all components used for Flutter development, and if they are installed. This should include either Android or iOS development (depending on your platform), as well as any desktop platform you want to target.  
You can ignore the Chrome/Web component, since Finamp is not a web app.

### NixOS

The project includes a `flake.nix` file that can help you install Flutter and Rust dependencies. The recommended way of using it is to
use `nix develop`, which allows rustup for Discord RPC dependency. Also, there's `nix develop .#fenix` which stubs rustup with [fenix](https://github.com/nix-community/fenix/), but it is a hack.

To get the application running on NixOS once you are in the development shell:
- `flutter build linux` - generates the build files in `./build/linux/x64/release/bundle` where the `lib` folder will have all the dynamic libraries.
- `cd ./build/linux/x64/release/bundle/lib` - flutter cannot find the dynamic libraries by default. Probably works only with this CWD because the fallback is CWD.
- `../finamp` - start the application.  
  Or use convenient `(cd build/linux/x64/release/bundle/lib && ../finamp)` command to cd in subshell

It is possible those actions will not lead to application start in JetBrains IDEs. Then, the actual run should be done outside JetBrains IDE using the same flake.

The normally-used `flutter run ...` command does not seem to launch application on NixOS at this time but could be used to run on Android (not tested).

Note that code generation fails since 21baadbaf6852d34d7d12725a293c359c05cf20b due to unknown issue in nixpkgs. Applying this patch helps:

```diff
diff --git a/lib/builders/finamp_settings_builder.dart b/lib/builders/finamp_settings_builder.dart
--- a/lib/builders/finamp_settings_builder.dart	(revision 66736f47c5d084463591dd74189c46123f4144ff)
+++ b/lib/builders/finamp_settings_builder.dart	(date 1768146068892)
@@ -129,13 +129,6 @@
   }
 
   static String _typeName(DartType type) {
-    var typeArg = type.element!.displayName;
-    if (type is ParameterizedType && type.typeArguments.isNotEmpty) {
-      typeArg = "$typeArg<${type.typeArguments.map((x) => _typeName(x)).join(",")}>";
-    }
-    if (type.nullabilitySuffix == NullabilitySuffix.question) {
-      typeArg = "$typeArg?";
-    }
-    return typeArg;
+    return type.getDisplayString();
   }
 }

```

After that, you need to manually update `InvalidType` in generated code to represent actual types, which most of the time is done by reverting affected lines since there are currently only two types (`Color` and `Locale`) that trigger failure. This patch is not to be committed to tree due to [`getDisplayString` not being intended for code generation](https://github.com/dart-lang/sdk/issues/52455#issuecomment-1559972986), and so manual check of generated code is required.

### Building for Android

You can build debug builds for Android right-away, but you will get an error if you try to build a release build (which is the default type).  
To build release APKs, you need to set up a signing key for Android. To get that set up, follow [this guide](https://docs.flutter.dev/deployment/android#signing-the-app) from the Flutter documentation.
Respectively, you can also set a custom keystore for debug builds by setting the `debugKeystoreFile`, `debugKeystorePassword`, `debugKeyAlias`, and `debugKeyPassword` variables in the same `android/key.properties` file.
This should not be necessary for most users, but can be useful if you develop on multiple machines and easily want to share the same debug key.
Note that Finamp is configured to use a different app ID for debug builds by default, so if you install a release build and a debug build, you will have two independent versions of Finamp installed on your device.
This also means that you can keep using your regular install of Finamp (from the Play Store, etc.) while developing new features for Finamp, without breaking your ability to listen to music :)  

If you try to install a release build you built yourself (with your signing key) on top of a release build you downloaded from the Play Store or GitHub, Android will prevent you from doing so and show a generic error message. The only solution here is to uninstall the existing version, and then install your build. Note that this will delete any logins, settings and downloads that you had configured.  
This generally shouldn't be needed, since debug builds works fine for daily usage, even though they are a bit less performant.

### Developing on an Android Device without Android Studio on linux (not recommended)
1. You need the following packages  
    *you may need to find out the equivalents for your distro, these are for Arch*  
    `android-sdk android-sdk-build-tools android-sdk-cmdline-tools-latest android-platform android-sdk-platform-tools`
2. Ensure your active java version is jdk17, newer/older might still work but 17 definitely does
3. Accept license  
    `flutter doctor --android-licenses && sudo /opt/android-sdk/cmdline-tools/latest/bin/sdkmanager --licenses`
4. Enable USB debugging on your phone
5. Connect your phone via usb to your pc
6. Find your device  
    `flutter devices`
7. Run on device  
    `flutter run -d <device>` eg. for google pixel phones `flutter run -d pixel`   
8. Go back to develop on linux   
    `flutter run -d linux`

### Code Generation (The Arcane Arts)

![A conversation between jmshrv and Chaphasilor. I say "did you try running (the Dart build command)?" They reply "I wasn't aware I need to use the arcane arts for this"](assets/arcane-arts.png)

Because Dart doesn't support macros, a few dependencies rely on code generation which must be run manually.  
You'll have to do this whenever you:

- Create a new setting (in `lib/models/finamp_models.dart`)
- Create a new class/type or extend and existing one, where you **use type annotations** (e.g. `@HiveType`, `@HiveField`, `@Isar`, `@riverpod`, `@JsonSerializable`, ...)
- Modify the Jellyfin API interface (`lib/services/jellyfin_api.dart`)

To perform the code generation, run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

If you can't launch Finamp (e.g. with `flutter run`) after generating code you may need to run `flutter clean` and then try both commands again. This must be done when:

- Modifying a class that is returned by Jellyfin (such as the classes in `lib/models/jellyfin_models.dart`)
- Adding fields (annotated with `@HiveField`) to a database class (annotated with `@HiveType`)

### Native Splash Screens

Native splash screens are generated from `flutter_native_splash.yaml`.

Run:

```bash
dart run flutter_native_splash:create --path=flutter_native_splash.yaml
```

Rerun this after changing splash colors, splash icon assets, or light/dark splash behavior. This updates the generated iOS and Android native splash resources.

>[!WARNING]
> **If you don't rebuild generated files**, you will encounter some issues:
>
> - Settings not persisting
> - Hive/Isar errors on startup
> - Missing data when converting JSON to classes

Aside from generating the code you'll also have to explicitly use the generated code in some cases:

- After creating a **new** class annotated with `@HiveType` in `lib/models/finamp_models.dart` (or another file), you need to first run code generation and then register the newly generated Hive adapter.  
  This is done in `main.dart`, in the `setupHive()` method. Simply add another line like `Hive.registerAdapter(YourNewClassNameAdapter());`, where `YourNewClassName` is the name of the class, and you append the word `Adapter` at the end.

In detail, the actual dependencies and purposes for the code generation are:

- Hive - the database that Finamp uses for storing most data
- Isar - Hive's younger/newer brother, which powers Finamp's login & download system
- `json_serializable` - For serializing and deserializing JSON from/into classes, e.g. automatically converting data between Finamp's internal representation and the Jellyfin API
- Chopper - For talking to Jellyfin over HTTP
  - This layer (`lib/services/jellyfin_api.dart`) is not used by the app directly. The user-facing API is located at `lib/services/jellyfin_api_helper.dart`.
- Riverpod - For reactive state management throughout the app
- Most recently, Finamp's settings helpers - These are methods automatically generated for getting and settings any settings within Finamp.

### Hive

As mentioned above, Finamp uses Hive for most data storage needs. If you're doing work that involves data storage, we recommend you read [the Hive docs](https://docs.hivedb.dev/#/). Please ensure that your changes work when upgrading Finamp from the current release to your changes, as not handling upgrades will cause the app to crash.  

>[!IMPORTANT]
> When downgrading or switching between branches, you will have to wipe your app data if any changes were made to Hive, otherwise you'll encounter Hive-related errors.

When creating new types, note that you'll also have to register an adapter in `main.dart`. After code generation, there should be a class called `[YourType]Adapter`, which you can initialize in `setupHive`.

## Project Structure
Here is a short description on the paths you'll most likely come across
```
lib/                                -- the codebase also known as src in other projects
    components/                     -- Contains elements used by screens
    l10n/                           -- Translations files. Edit the en file to add translations and run code generation
        models/
            finamp_models.g.dart    -- Mostly database and settings
        screens/                    -- All the "pages", "screens", "views" what ever you want to call them
        services/                   -- Things that run in the background, kinda like backend
```
## Developing

*Remember to format your changes before pushing (ideally in a **separate commit**), by running `flutter gen-l10n` or the "Generate Localizations" command in VS Code*

### Extending the Jellyfin API

1. Figure out the endpoint you need. You can use https://api.jellyfin.org for this, for example
2. Create a new matching endpoint in `jellyfin_api.dart`. Just copy-paste the needed annotations from other similar endpoints.
3. Run code-generation (`dart run build_runner build --delete-conflicting-outputs`) to generate actual code based on the endpoint annotations
4. Create a new method for interacting with the endpoint in `jellyfin_api_helper.dart`. Again, just copy-paste what you need.
5. Call the new method through `JellyfinApiHelper` to make your request

### Adding a New Setting

1. Find a setting that has a similar UI (e.g. toggle, dropdown) as what you're trying to add
2. Find the code for that setting on one of the settings screens, and check what kind of data structure it uses (defined in `finamp_models.dart`)
3. Add a new property for the setting you're trying to add, with the right data structure. That [can] involve, in that order: [create a new enum or class at the end of the file], [assign new HiveIDs and field IDs], add a new default value for the setting (`DefaultSettings` class), add a new property to `FinampSettings` (remember to increment the `HiveField` annotation), and add an argument for the new property to the `FinampSettings` constructor
4. Then run code generation via `dart run build_runner build --delete-conflicting-outputs`
5. Now duplicate the code for the new setting in the appropriate settings screen file, and update the settings property it references to match your newly added setting
6. Now add new translation strings in `app_en.arb` at the bottom, then generate the new localizations via `flutter gen-l10n` (see "Adding i18n strings")
7. Use the new translation tokens in your new settings' code, replacing the old translation tokens
8. Format everything via `dart format . `

### Adding i18n strings

1. In [app_en.arb](lib/l10n/app_en.arb), add default English string as well as string description following examples in the file
2. Run `flutter gen-l10n` or VSCode command "Generate Localizations" if you have Flutter plugin installed

### Playback Reporting

There are several aspects to playback reporting in Finamp. The main goal is to always let the server know what the user is listening to, including when they *started* and when they *stopped*. This is handled in [`playback_history_service.dart`](lib/services/playback_history_service.dart), by listening to the player state (among others) and invoking various Jellyfin endpoints in response. There are 3 endpoints: starting, stopping, and a generic "progress" endpoint that just updates the server's state without creating a start or stop event.  
The start and stop events are further used by server plugins such as ["Playback Reporting"](https://github.com/jellyfin/jellyfin-plugin-playbackreporting) or ["Last.fm"](https://github.com/jesseward/jellyfin-plugin-lastfm) to keep track of users' listening activity.
Playback reporting is also used as a way to tell the server about the user's current playback queue, so that it can be shown in other Jellyfin clients when they are controlling Finamp via the "Play On" feature. That's why when a Play On session is established, we increase the frequency of playback updates.
Finally, playback reporting is also used (read: required) to tell the server about the transcoding status, so that is actually shows up correctly on the admin dashboard (see below).  

Finamp keeps track of any plays that couldn't be sent to the server (due to errors or because offline mode was active) in a text file which can be exported via the "share" icon on the [🔗 Playback History Screen](https://intradeus.github.io/http-protocol-redirector?r=finamp://internal/playbackhistory).  
The playback history itself currently only contains plays since the app was last launched and is deleted when the app is closed.

#### Showing Transcode Status on the Admin Dashboard

Getting the server to show the actual transcoding status on the admin dashboard isn't trivial. It requires 3 conditions:

1. Requesting a (transcoded) stream from the server
   - Either endpoint works, `/Audio/{itemId}/main.m3u8` and `/{streamId}/stream.{container}` (the latter can be returned by the server)
2. Reporting playback of the exact media that was requested (matching `BaseItemDto` IDs)
3. Using a *consistent* `PlaySessionId` across the two requests above

Importantly, while the `PlaySessionId` *can* be "properly" obtained from the server by using the [`POST /Items/{itemId}/PlaybackInfo`](https://api.jellyfin.org/#tag/MediaInfo/operation/GetPostedPlaybackInfo) endpoint, it currently doesn't have to be (as of Jellyfin 10.10.13, and 10.11-RC3), meaning you can just generate a random ID (UUID v4 works) and use that. It just has to be consistent.  
The server team mentioned that in the future this ID might be used to authenticate media requests, meaning you'll have to obtain the ID before you can request a media stream, but this will probably require some API changes (as explained below).

The above steps are all that's needed to get the dashboard to show "Transcoding" instead of the default "Direct Play". However, if you want to show *reasons* for transcoding, and/or make use of Jellyfin's ability to support *automatic* transcoding based on device capabilities, there are stricter requirements.  
Firstly, you'll *have* to use the [`POST /Items/{itemId}/PlaybackInfo`](https://api.jellyfin.org/#tag/MediaInfo/operation/GetPostedPlaybackInfo) endpoint in order to let the server know which codecs, containers, bitrates, etc. your device supports (this data could vary depending on client settings, e.g. the maximum bitrate could be a setting. Jellyfin will probably also default to the Jellyfin user's default settings here.). This endpoint will return information about which playback method is best suited (based on the media formats and the device capabilities), a pre-build endpoint for streaming the media with the recommended settings, IDs, and keys (the `/{streamId}/stream.{container}` URL mentioned earlier), and the `PlaySessionId` which is used to identify the playback session.  
What this means is that for each and every track you want to possibly play transcoded, you'll have to make a request to the server. There currently is no batching or reusing if you want to properly show the transcoding status and reasons. Possibly because the server needs to decide the transcoding settings for each item individually, since they could all have different formats and bit rates.  
But since **making one request for each track that is queued up is simply not feasible in Finamp** at the moment (takes way to long, and we need to make the request *before* we can add the track to the queue), we have opted to simply use a random `playSessionId` and not support the transcode reasons and/or automatic transcoding features. Finamp stores the ID in the `playSessionId` field of the `MediaItem`'s `extras` map.  
Notably, since we already have the full `BaseItemDto`s and additional metadata for each track, we could simply build client-side automatic transcoding. This would be needed anyway for considering network connectivity and such, so we're not losing much here.  

Should the API for this improve in the future, for example by allowing us to submit the supported codecs and bitrate limits to an endpoint like [`/Sessions/Capabilities/Full`](https://api.jellyfin.org/#tag/Session/operation/PostFullCapabilities) (that part is already possible) and then getting the corresponding `PlaySessionId`s and transcode URLs via the regular `BaseItemDto`, then we could think about doing this the proper way. But until then we'll most likely handle the ID generation and transcoding settings client-side.
### Android Debug Build stuck in 'assembleDebug'
1. `cd android`
2. `./gradlew clean`
3. `cd ..`
4. `flutter run -d <phone>`

Now you need to wait a bit, but it'll finish :)

### CarPlay Development (iOS)

CarPlay uses the `flutter_carplay` plugin. To test CarPlay in the simulator:

1. Build and run the app on an iOS simulator
2. In the Simulator menu: **I/O > External Displays > CarPlay**

Note: CarPlay can only be tested on the simulator with the included entitlements. Testing on real hardware requires a CarPlay entitlement from Apple, which must be requested separately and is not included in this repository.

#### CarPlay Not Appearing in Simulator

If Finamp doesn't appear in the CarPlay display after enabling it, the most common cause is corruption in the Xcode project file from repeated `pod install` runs. This can break entitlement embedding for simulator builds.

**Fix:**
```bash
# Restore project file to committed state
git checkout -- ios/Runner.xcodeproj/project.pbxproj

# Clean rebuild
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter build ios --simulator
```

Then restart the simulator and re-enable CarPlay via **I/O > External Displays > CarPlay**.

### Add dbus message
1. Open `lib/services/dbus_manager.dart`
2. Add another `else if (call.interface == 'com.unicornsonlsd.Finamp' && call.name == 'YOUR FUNCTION NAME')`
3. Profit

### Add global keyboard shortcuts

Finamp uses Flutter `Shortcuts`/`Actions` under `lib/components/Shortcuts/`.

1. Create a new file (Example: `lib/components/Shortcuts/navigation_shortcuts.dart`).
2. Create intents and get actions function (see example at `music_control_shortcuts.dart`).
3. Define shortcuts and add actions to `global_shortcut_manager.dart`.

Note:
Handle `consumesKey` and `invoke` in the `CallbackAction` class for cases where text input is happening in a TextField for potentially conflicting shortcuts.

## The Redesign

The biggest main piece of work being done on Finamp at the moment is the redesign. The relevant meta-issue can be found [here](https://github.com/jmshrv/finamp/issues/220).  
The `redesign` branch has diverged a lot from the stable version on `main`, and `main` is in a "maintenance mode" at this point, with only occasional bug fixes.  
**Please use the `redesign` branch as your source branch when working on new features and creating pull requests!**  
We won't accept new features for the `main` branch at this point.

## Designing

As the name implies, we'll need many fresh design mockups for the redesign. Some are already done, some are still being interated on, and some mockups haven't been started yet.

If you are a designer or have ideas on how the new user interface could/should look, then it would be amazing and really helpfull if you would create a mockup!  
You can share your mockups in an issue here on GitHub (use a relevant one if possible, otherwise create a new one) or on Discord for further discussion.  
Once the mockup is finalized, people can start implementing it.

There's also a Figma file with some existing mockups that you can go off of: <https://www.figma.com/design/wVizekpm9YchvHFP6l508r/Finamp?node-id=101-425&t=27CRT9QAwFhlIMqm-1>  
Some of the designs in there are already outdated or still a work in progress. When in doubt, you should look at the current design in the actual app, or ask us about it!

## Translating

Finamp uses Weblate to manage translations: **<https://hosted.weblate.org/engage/finamp/>**

Feel free to add new languages if yours isn't there yet.  
If you have any questions, such as the context of a string, you can ask in the [Translation Discussions](https://github.com/jmshrv/finamp/discussions/categories/translations). There's also a channel on our [Discord server](https://discord.gg/xh9SZ73jWk) for potentially getting a reply faster.

## Packaging

### Linux

Linux packaging might vary depending on distribution and type of installation.
Please follow the guidelines of your distribution if you would like to package Finamp for it.
The repo contains a [desktop file template](assets/finamp.desktop.m4) and
pre-generated icons following the XDG Icon Theme Specification
in the [assets folder](assets/icon/linux).
