"""Create Gradle's release signing files from CI secrets without shell expansion."""
import base64
import binascii
import os
from pathlib import Path
import sys


def properties_value(value):
    """Encode a value for java.util.Properties.load(InputStream), including Unicode."""
    result = []
    encoded = value.encode("utf-16-be")
    for offset in range(0, len(encoded), 2):
        codepoint = int.from_bytes(encoded[offset:offset + 2], "big")
        character = chr(codepoint)
        if character in "\\ :=#!":
            result.append("\\" + character)
        elif 0x21 <= codepoint <= 0x7e:
            result.append(character)
        else:
            result.append(f"\\u{codepoint:04x}")
    return "".join(result)


def configure(environment, keystore_path, properties_path):
    names = ("ANDROID_KEYSTORE_BASE64", "ANDROID_STORE_PASSWORD",
             "ANDROID_KEY_ALIAS", "ANDROID_KEY_PASSWORD")
    for name in names:
        if not environment.get(name):
            raise ValueError(f"Missing required secret: {name}")
    try:
        keystore = base64.b64decode(
            "".join(environment[names[0]].split()), validate=True)
    except (ValueError, binascii.Error):
        raise ValueError("ANDROID_KEYSTORE_BASE64 is not valid base64") from None
    if not keystore:
        raise ValueError("The decoded keystore is empty")
    if keystore_path.exists() or properties_path.exists():
        raise ValueError("Refusing to overwrite existing signing files")

    values = {
        "storeFile": keystore_path.resolve().as_posix(),
        "storePassword": environment[names[1]],
        "keyAlias": environment[names[2]],
        "keyPassword": environment[names[3]],
    }
    # These files live only on the ephemeral runner and are never uploaded.
    with keystore_path.open("xb") as output:
        os.chmod(keystore_path, 0o600)
        output.write(keystore)
    with properties_path.open("x", encoding="ascii", newline="\n") as output:
        os.chmod(properties_path, 0o600)
        for key, value in values.items():
            output.write(f"{key}={properties_value(value)}\n")


if __name__ == "__main__":
    try:
        configure(os.environ, Path(os.environ["RUNNER_TEMP"]) / "finamp-release.jks",
                  Path("android/key.properties"))
    except ValueError as error:
        sys.exit(str(error))
