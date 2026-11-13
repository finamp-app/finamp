#!/usr/bin/env sh
set -eu

# Run after F-Droid's source scan, which removes the plugin's prebuilt libraries.
test -d .isar
expected_revision=$(awk '{print $2}' fdroid_isar_version)
test "$(git -C .isar rev-parse HEAD)" = "$expected_revision"

# Do not build an unversioned core (Isar otherwise reports its version as debug).
ISAR_VERSION=$(sed -n "s/^  static const version = '\([^']*\)';/\1/p" \
    .isar/packages/isar/lib/src/isar.dart)
test -n "$ISAR_VERSION"
export ISAR_VERSION

# Fail on ambiguous caches instead of copying to an unused plugin checkout.
set -- "${PUB_CACHE:-$PWD/.pub-cache}"/git/isar_flutter_libs-*
test "$#" -eq 1
test -f "$1/android/build.gradle"
jni_libs="$1/android/src/main/jniLibs"

for target in x86 x64 armv7 arm64; do
    case "$target" in
        x86) abi=x86 ;;
        x64) abi=x86_64 ;;
        armv7) abi=armeabi-v7a ;;
        arm64) abi=arm64-v8a ;;
    esac
    # Never reuse an output left over from an earlier compilation.
    rm -f ".isar/libisar_android_$target.so"
    (cd .isar && bash -e tool/build_android.sh "$target")
    test -s ".isar/libisar_android_$target.so"
    mkdir -p "$jni_libs/$abi"
    cp ".isar/libisar_android_$target.so" "$jni_libs/$abi/libisar.so"
done
