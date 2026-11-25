#!/usr/bin/env python3
"""Reject APKs missing Isar for an advertised ABI. No Android SDK required."""

import argparse
import struct
import zipfile


# ELF class and e_machine for Android's supported Isar targets.
ELF_ABIS = {
    "armeabi-v7a": (1, 40),
    "arm64-v8a": (2, 183),
    "x86": (1, 3),
    "x86_64": (2, 62),
}


def check_apk(path, abis, version=None):
    with zipfile.ZipFile(path) as apk:
        for abi in abis:
            name = f"lib/{abi}/libisar.so"
            try:
                library = apk.read(name)
            except KeyError as error:
                raise ValueError(f"Missing {name}") from error
            if len(library) < 52 or library[:4] != b"\x7fELF" or library[5] != 1:
                raise ValueError(f"Invalid little-endian ELF: {name}")
            elf_class, machine = ELF_ABIS[abi]
            if library[4] != elf_class or struct.unpack_from("<HH", library, 16) != (
                3, machine
            ):
                raise ValueError(f"Wrong ELF architecture or type: {name}")
            # Isar embeds a NUL-terminated version returned by isar_version().
            # This is an artifact check; executing that function requires Android.
            if version and version.encode() + b"\0" not in library:
                raise ValueError(f"Missing Isar version {version} in {name}")
            print(f"OK: {name}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk")
    parser.add_argument("abis", nargs="+", choices=ELF_ABIS)
    parser.add_argument("--isar-version")
    args = parser.parse_args()
    try:
        check_apk(args.apk, args.abis, args.isar_version)
    except (OSError, ValueError, zipfile.BadZipFile) as error:
        parser.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
