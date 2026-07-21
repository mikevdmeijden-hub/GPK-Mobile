# GPK Parkeren — Android-app (v1.0)

Een Flutter-app die gehandicaptenparkeerplaatsen in Nederland toont, met de
parkeerregels per gemeente. Plekken worden live uit OpenStreetMap gehaald,
regels van gpkwijs.nl. Gemaakt door Michael van der Meijden.

Je hoeft **niets** te installeren op je eigen computer: GitHub bouwt de APK
voor je in de cloud. Volg de stappen hieronder.

---

## Stap 1 — Zet de bestanden in een GitHub-repository

1. Ga naar https://github.com en log in.
2. Klik rechtsboven op **+** → **New repository**.
3. Geef het een naam, bijvoorbeeld `gpk-app`. Zet 'm op **Public** of **Private**
   (allebei werkt). Klik **Create repository**.
4. Op de nieuwe pagina klik je op **uploading an existing file**
   (of: **Add file → Upload files**).
5. Sleep **de volledige inhoud van de map `gpk_flutter`** naar het venster —
   dus `lib/`, `android/`, `.github/`, `pubspec.yaml`, enzovoort.
   > Belangrijk: upload de *inhoud* van de map, niet de map zelf. In de repo
   > moet `pubspec.yaml` in de hoofdmap staan, en `.github/workflows/build-apk.yml`
   > op die plek.
6. Klik onderaan op **Commit changes**.

## Stap 2 — De APK laten bouwen

Zodra je de bestanden hebt geüpload naar de `main`-branch, start het bouwen
**automatisch**. Anders:

1. Ga naar het tabblad **Actions** bovenin je repository.
2. Kies links **APK bouwen** en klik rechts op **Run workflow → Run workflow**.
3. Wacht tot het groene vinkje verschijnt (de eerste keer duurt dit ±5–10 min).

## Stap 3 — De APK downloaden

1. Klik in **Actions** op de laatste (groene) run.
2. Scroll naar **Artifacts** onderaan.
3. Klik op **GPK-Parkeren-APK** om een zip te downloaden.
4. Pak de zip uit: daarin zit **app-release.apk**. Dat is je app.

## Stap 4 — Delen en installeren

Stuur `app-release.apk` naar wie je maar wilt (WhatsApp, e-mail, een
downloadlink). Om te installeren:

1. Open het bestand op de Android-telefoon.
2. Android vraagt toestemming om te installeren uit een "onbekende bron" —
   dat is normaal voor apps die niet uit de Play Store komen. Sta het toe.
3. De app verschijnt als **GPK Parkeren** in het app-overzicht.

---

## Hoe de app werkt

- **Zoek een plaats** bovenin → de kaart springt erheen en toont de plekken daar.
- **Download nieuwste** → haalt de plekken op voor het gebied dat je nu ziet
  (vervangt wat er stond).
- **Bijwerken** → vult het huidige beeld aan zonder te wissen.
- **Tik op een markering** → details van de plek + de parkeerregels van de
  gemeente (live van gpkwijs.nl), met links naar de volledige regels en de
  gemeentesite.

De app heeft internet nodig. Aan de getoonde regels kun je geen rechten
ontlenen — de borden ter plaatse en de gemeente zijn leidend.

## Later een nieuwe versie maken

Wijzig een bestand in de repo (of upload een nieuwe versie) en commit naar
`main`. De APK wordt dan opnieuw gebouwd; download 'm weer via **Actions**.

## Als het bouwen mislukt

Open de mislukte run in **Actions** en klik de rode stap open om de melding te
zien. Veelvoorkomend: een tikfout in een bestand of een ontbrekend bestand.
Kopieer de foutmelding en vraag om hulp — dan is het meestal snel opgelost.
