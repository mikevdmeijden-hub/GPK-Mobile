#!/usr/bin/env python3
"""Pas het gegenereerde AndroidManifest.xml aan: internet, app-naam, en
<queries> zodat de app Google Maps/browser mag openen."""
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

if "<queries>" not in xml:
    queries = """    <queries>
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="https"/>
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="geo"/>
        </intent>
    </queries>
</manifest>"""
    xml = xml.replace("</manifest>", queries)

pad.write_text(xml, encoding="utf-8")
print("Manifest aangepast:")
print(xml)
