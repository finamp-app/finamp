import base64
from pathlib import Path
import subprocess
import tempfile
import unittest

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
