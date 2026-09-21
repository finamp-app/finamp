# Screenshots Pretty Please

This is the screenshot automation directory. As you may have been able to tell by its name.

This is the README for said directory. As you also may have been able to tell by its name.

Thus, we shall explore the screenshot automation.

## `screenshot_automation/run_screenshot_automation.dart`

This is the entrypoint for screenshot automation. It starts the required services and emulators, and then runs the tests on said emulators.

```
Start and run screenshot automation.
This script includes running the screenshot server, emulator, and Flutter
integration tests for screenshots.

Usage:
-s, --j-server            The Jellyfin instance to use for screenshots.
-u, --j-user              The Jellyfin user to use for screenshots.
-p, --j-password          The Jellyfin password to use for screenshots.
-H, --harnesses           The harnesses to run screenshots for.
-l, --playlist-id         The Jellyfin playlist ID to use for screenshots.
-c, --[no-]load-config    Load configuration from the config.yml file.
-h, --help                Display this help information.
```

## TODO

- [ ] Create Composition Tool
- [ ] Add more Screenshots
- [ ] Separate harnesses to run with different emus
- [ ] Clean up tool
- [ ] More Documentation is Good Documentation
