import base64
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import zipfile

from android_signing import configure


class AndroidSigningTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.keystore = self.root / "signing.jks"
        self.properties = self.root / "key.properties"
        self.environment = {
            "ANDROID_KEYSTORE_BASE64": base64.b64encode(b"test keystore").decode(),
            "ANDROID_STORE_PASSWORD": " leading #!=:\\ \t\n\rárvíz 🔑",
            "ANDROID_KEY_ALIAS": "release: alias",
            "ANDROID_KEY_PASSWORD": "password\\with=separators",
        }

    def test_java_properties_round_trip(self):
        configure(self.environment, self.keystore, self.properties)
        # Use Gradle's actual parser, not a Python imitation of Properties.
        source = self.root / "ReadProperties.java"
        source.write_text('''
import java.nio.file.*;
import java.util.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
class ReadProperties {
    public static void main(String[] args) throws Exception {
        Properties p = new Properties();
        try (InputStream in = Files.newInputStream(Path.of(args[0]))) { p.load(in); }
        for (String key : new String[]{"storeFile", "storePassword", "keyAlias", "keyPassword"})
            System.out.println(Base64.getEncoder().encodeToString(p.getProperty(key).getBytes(StandardCharsets.UTF_8)));
    }
}
''', encoding="ascii")
        result = subprocess.run(["java", str(source), str(self.properties)],
                                check=True, capture_output=True, text=True)
        actual = [base64.b64decode(line).decode() for line in result.stdout.splitlines()]
        self.assertEqual(actual, [self.keystore.resolve().as_posix(),
                                 self.environment["ANDROID_STORE_PASSWORD"],
                                 self.environment["ANDROID_KEY_ALIAS"],
                                 self.environment["ANDROID_KEY_PASSWORD"]])
        self.assertEqual(self.keystore.read_bytes(), b"test keystore")

    def test_distinct_channel_certificates_reject_cross_verification(self):
        # Exercise real signing and trust checks, not just secret-name routing.
        channels = {}
        for name in ("apk", "aab"):
            root = self.root / name
            root.mkdir()
            generated = root / "generated.jks"
            password = "test-" + name + "-password"
            key_password = "test-" + name + "-key-password"
            environment = dict(os.environ, TEST_STORE_PASSWORD=password,
                               TEST_KEY_PASSWORD=key_password)
            subprocess.run([
                "keytool", "-genkeypair", "-keystore", str(generated),
                "-storetype", "JKS", "-storepass:env", "TEST_STORE_PASSWORD",
                "-keypass:env", "TEST_KEY_PASSWORD", "-alias", name,
                "-keyalg", "RSA", "-keysize", "2048", "-validity", "3650",
                "-dname", "CN=Disposable " + name + " test", "-noprompt",
            ], env=environment, check=True, capture_output=True)
            settings = {
                "ANDROID_KEYSTORE_BASE64": base64.b64encode(
                    generated.read_bytes()).decode(),
                "ANDROID_STORE_PASSWORD": password,
                "ANDROID_KEY_ALIAS": name,
                "ANDROID_KEY_PASSWORD": key_password,
            }
            keystore = root / "runner-release.jks"
            properties = root / "key.properties"
            configure(settings, keystore, properties)
            certificate = subprocess.run([
                "keytool", "-exportcert", "-keystore", str(keystore),
                "-storepass:env", "TEST_STORE_PASSWORD", "-alias", name,
            ], env=environment, check=True, capture_output=True).stdout
            unsigned = root / "unsigned.jar"
            with zipfile.ZipFile(unsigned, "w") as archive:
                archive.writestr("payload.txt", "disposable " + name + " fixture")
            signed = root / "signed.jar"
            subprocess.run([
                "jarsigner", "-keystore", str(keystore), "-storepass:env",
                "TEST_STORE_PASSWORD", "-keypass:env", "TEST_KEY_PASSWORD",
                "-signedjar", str(signed), str(unsigned), name,
            ], env=environment, check=True, capture_output=True)
            channels[name] = (keystore, signed, environment,
                              hashlib.sha256(certificate).hexdigest())

        self.assertNotEqual(channels["apk"][3], channels["aab"][3])
        for name, (keystore, signed, environment, _) in channels.items():
            with self.subTest(channel=name):
                verified = subprocess.run([
                    "jarsigner", "-verify", "-strict", "-keystore", str(keystore),
                    "-storepass:env", "TEST_STORE_PASSWORD", str(signed),
                ], env=environment, capture_output=True)
                self.assertEqual(verified.returncode, 0, verified.stderr)
                other = channels["aab" if name == "apk" else "apk"]
                rejected = subprocess.run([
                    "jarsigner", "-verify", "-strict", "-keystore", str(other[0]),
                    "-storepass:env", "TEST_STORE_PASSWORD", str(signed),
                ], env=other[2], capture_output=True)
                self.assertNotEqual(rejected.returncode, 0,
                                    "The other channel must not trust this signer")

    def test_accepts_wrapped_base64(self):
        value = self.environment["ANDROID_KEYSTORE_BASE64"]
        self.environment["ANDROID_KEYSTORE_BASE64"] = value[:4] + "\n" + value[4:]
        configure(self.environment, self.keystore, self.properties)
        self.assertEqual(self.keystore.read_bytes(), b"test keystore")

    def test_missing_secret_does_not_write_files(self):
        for name in self.environment:
            with self.subTest(name=name):
                environment = self.environment.copy()
                environment[name] = ""
                with self.assertRaisesRegex(ValueError, name):
                    configure(environment, self.keystore, self.properties)
                self.assertFalse(self.keystore.exists())
                self.assertFalse(self.properties.exists())

    def test_invalid_base64_does_not_write_files(self):
        self.environment["ANDROID_KEYSTORE_BASE64"] = "this! is not base64"
        with self.assertRaisesRegex(ValueError, "not valid base64"):
            configure(self.environment, self.keystore, self.properties)
        self.assertFalse(self.keystore.exists())

    def test_preserves_existing_signing_files(self):
        self.properties.write_text("existing settings", encoding="ascii")
        with self.assertRaisesRegex(ValueError, "overwrite"):
            configure(self.environment, self.keystore, self.properties)
        self.assertEqual(self.properties.read_text(), "existing settings")
        self.assertFalse(self.keystore.exists())


if __name__ == "__main__":
    unittest.main()
