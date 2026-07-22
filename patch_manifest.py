#!/usr/bin/env python3
"""Pas het door `flutter create` gegenereerde AndroidManifest.xml aan:
- INTERNET-permissie (kaarten/gegevens ophalen)
- App-naam "GPP Zoek"
- <queries> zodat de app externe apps (Google Maps, browser) mag openen.
  Zonder dit blok doet url_launcher op Android 11+ niets.
"""
import re
from pathlib import Path

pad = Path("android/app/src/main/AndroidManifest.xml")
xml = pad.read_text(encoding="utf-8")

# 1) INTERNET-permissie
if "android.permission.INTERNET" not in xml:
    xml = re.sub(
        r"(<manifest\b[^>]*>)",
        r'\1\n    <uses-permission android:name="android.permission.INTERNET"/>',
        xml,
        count=1,
    )

# 2) App-naam
xml = re.sub(r'android:label="[^"]*"', 'android:label="GPP Zoek"', xml, count=1)

# 3) <queries>-blok toevoegen (nodig om Google Maps / browser te kunnen openen)
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
