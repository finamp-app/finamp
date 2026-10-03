# Android release artifacts

The `Android release artifacts` workflow builds a signed universal APK and an
AAB from a release tag. It stores them, with SHA-256 checksums, as a GitHub Actions
artifact. It does **not** publish a GitHub release or change a Google Play track.
This is the artifact-building part of the Android release automation discussed
in [#1769](https://github.com/finamp-app/finamp/pull/1769).

## Maintainer setup

Before running this workflow with production credentials:

1. Create the `android-release` GitHub environment. Restrict it to release tags
   and configure the required reviewers appropriate for the project. The job
   also checks that it is running on a tag in `finamp-app/finamp`.
2. Add these **environment secrets**, not repository-wide secrets:

   | Secret | Value |
   | --- | --- |
   | `ANDROID_KEYSTORE_BASE64` | Base64-encoded existing release keystore; line wrapping is supported |
   | `ANDROID_STORE_PASSWORD` | Keystore password |
   | `ANDROID_KEY_ALIAS` | Existing release key alias |
   | `ANDROID_KEY_PASSWORD` | Private key password |

3. Confirm that this key is both the existing GitHub APK signing key and the
   upload key registered in Play Console. Play App Signing may use a different
   key to sign the APKs it delivers to users; that key is not needed here.
   If the GitHub APK and Play upload keys differ, do not use this single-key
   workflow for both channels; separate signing configurations are needed.
4. Check `version:` in `pubspec.yaml` before tagging. The AAB uses its build
   number as `versionCode`; it must be greater than previous Play uploads.
   The workflow uses the same stable Flutter channel as the existing builds.
   Its logs record the actual Flutter and Java versions used.

Do not replace the release key with a newly generated key. Android updates must
preserve signing identity. Only maintainers should handle production signing
material; contributors can validate the build with a disposable test key.

## Running and publishing

Pushing a version tag runs the workflow. To rerun it explicitly against a tag:

```sh
gh workflow run release-android.yml --ref 1.0.1-beta
```

Branch dispatches and forks do not run the release job. Pull requests changing
the workflow or signing helper only run the signing helper tests, without secrets.
Existing debug builds and integration tests in `build.yml` are unchanged.

The release commands deliberately omit `--no-pub`: Flutter needs to regenerate
the release plugin registrant, excluding `integration_test`. See
[flutter/flutter#169336](https://github.com/flutter/flutter/issues/169336).

Download the `finamp-android-release-<tag>` artifact from the successful run.
Verify `SHA256SUMS` and review the APK certificate printed in the build log.
The artifact also records the source commit, Flutter version, resolved dependency
lockfile, and APK manifest summary (including the package ID, version, target SDK,
and supported ABIs).
Upload the AAB to the intended Play testing track, review Play Console's
validation and device availability, then test installation and upgrade through
that track before promoting a release. Attach the APK and checksums to the
corresponding GitHub release after review.

An artifact build does not demonstrate that an app is installable from Google
Play. In particular, the availability reports in
[#1759](https://github.com/finamp-app/finamp/issues/1759) also need the actual
Play artifact, track, and device exclusion settings to be checked.

## Local verification

With Python 3 and Java 17 on `PATH`, run:

```sh
python3 -m unittest discover -s .github/scripts -p 'test_android_signing.py' -v
```

The tests round-trip passwords containing whitespace, separators, backslashes,
and Unicode through Java's actual `Properties` parser. They also check missing
secrets, malformed base64, and preservation of existing local signing files.
For a complete build, install the Flutter/Android toolchain and Rust (`rustup`),
then configure a test keystore using `android/key.properties`
as described in [CONTRIBUTING.md](../CONTRIBUTING.md), then run the two release
build commands from the workflow. Test-signed release builds cannot update the
official app; never uninstall a user's app or clear its data to test this pipeline.
