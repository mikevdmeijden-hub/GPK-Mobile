#!/usr/bin/env python3
"""Voeg de INTERNET-permissie en de app-naam toe aan het door
flutter create gegenereerde AndroidManifest.xml."""
import re
from pathlib import Path

pad = Path("android/app/src/main/AndroidManifest.xml")
xml = pad.read_text(encoding="utf-8")

if "android.permission.INTERNET" not in xml:
    xml = re.sub(
        r"(<manifest\b[^>]*>)",
        r'\1\n    <uses-permission android:name="android.permission.INTERNET"/>',
        xml,
        count=1,
    )

xml = re.sub(r'android:label="[^"]*"', 'android:label="GPK Parkeren"', xml, count=1)

pad.write_text(xml, encoding="utf-8")
print("Manifest aangepast:")
print(xml)
