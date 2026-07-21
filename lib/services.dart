// ---------------------------------------------------------------------------
// GPK-app — data-laag: modellen en netwerkdiensten.
// Plekken komen live uit OpenStreetMap (Overpass); gemeenten via Nominatim;
// regels via gpkwijs.nl.
// ---------------------------------------------------------------------------
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

const List<String> overpassMirrors = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
  'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
];
const String nominatim = 'https://nominatim.openstreetmap.org';
const String userAgent = 'GPK-App-NL/1.0 (persoonlijk gebruik)';

/// Eén gehandicaptenparkeerplaats.
class Plek {
  final double lat, lon;
  final String? naam, capaciteit, betaald, maxduur;
  final bool overdekt;
  const Plek({
    required this.lat,
    required this.lon,
    this.naam,
    this.capaciteit,
    this.betaald,
    this.maxduur,
    this.overdekt = false,
  });

  LatLng get punt => LatLng(lat, lon);

  static Plek? fromOsm(Map<String, dynamic> el) {
    final lat = (el['lat'] ?? el['center']?['lat']) as num?;
    final lon = (el['lon'] ?? el['center']?['lon']) as num?;
    if (lat == null || lon == null) return null;
    final t = (el['tags'] ?? {}) as Map<String, dynamic>;
    return Plek(
      lat: lat.toDouble(),
      lon: lon.toDouble(),
      naam: t['name'] as String?,
      capaciteit: (t['capacity:disabled'] ?? t['disabled_spaces'] ?? t['capacity'])
          ?.toString(),
      betaald: t['fee'] as String?,
      maxduur: t['maxstay'] as String?,
      overdekt: t['covered'] == 'yes' ||
          t['parking'] == 'multi-storey' ||
          t['parking'] == 'underground',
    );
  }
}

/// Resultaat van een plaatszoekopdracht.
class Plaats {
  final String naam;
  final double zuid, noord, west, oost;
  const Plaats(this.naam, this.zuid, this.noord, this.west, this.oost);
  LatLng get midden => LatLng((zuid + noord) / 2, (west + oost) / 2);
}

/// De regels voor een gemeente (live van gpkwijs.nl, met fallback).
class Regels {
  final String label; // bv. "Verschilt per zone"
  final String status; // gratis | betaald | wisselend
  final List<String> regels;
  final String? gecontroleerd;
  final String? bron; // officiële gemeente-URL
  final String gpkwijsUrl;
  final bool live;
  const Regels({
    required this.label,
    required this.status,
    required this.regels,
    required this.gpkwijsUrl,
    this.gecontroleerd,
    this.bron,
    this.live = false,
  });
}

// ---------------------------------------------------------------------------
// Ingebouwde fallback-regels (indicatief). Sleutel = gemeente, kleine letters.
// ---------------------------------------------------------------------------
const Map<String, Map<String, Object>> _ingebouwd = {
  'amsterdam': {
    'status': 'wisselend',
    'label': 'Verschilt per zone',
    'regels': [
      'Gratis op gehandicaptenparkeerplaatsen en in blauwe zones.',
      'Voor betaalde straten is een extra (gratis) vergunning nodig.',
      'In garages en bij slagbomen betaal je altijd.',
    ],
  },
  'rotterdam': {
    'status': 'wisselend',
    'label': 'Vergunning nodig',
    'regels': [
      'Gratis op algemene gehandicaptenparkeerplaatsen met GPK.',
      'Op betaalde plekken parkeerbelasting, tenzij aanvullende regeling.',
    ],
  },
  'utrecht': {
    'status': 'gratis',
    'label': 'Gratis na registratie',
    'regels': [
      'Gratis op betaalde plekken na registratie van je kenteken.',
      'Blauwe zones: onbeperkt, zonder parkeerschijf.',
      'In parkeergarages betaal je gewoon.',
    ],
  },
};

const Map<String, Object> _standaard = {
  'status': 'wisselend',
  'label': 'Regels per gemeente',
  'regels': [
    'Met een GPK mag je overal parkeren op algemene gehandicaptenparkeerplaatsen.',
    'Blauwe zones: onbeperkt, zonder tijdslimiet.',
    'Gratis parkeren in betaald gebied verschilt per gemeente.',
    'Let altijd op de onderborden bij de plek.',
  ],
};

// ---------------------------------------------------------------------------
// Diensten
// ---------------------------------------------------------------------------
class GpkService {
  /// Bouw de gpkwijs.nl-slug voor een gemeente.
  static String gpkwijsUrl(String gemeente) {
    var s = gemeente.toLowerCase().replaceAll('gemeente ', '');
    const v = {
      'â': 'a', 'ä': 'a', 'á': 'a', 'à': 'a', 'ë': 'e', 'é': 'e',
      'è': 'e', 'ê': 'e', 'ï': 'i', 'í': 'i', 'ö': 'o', 'ó': 'o',
      'ü': 'u', 'ú': 'u', 'ç': 'c',
    };
    v.forEach((k, val) => s = s.replaceAll(k, val));
    s = s.replaceAll(RegExp(r'[().]'), ' ').replaceAll(',', ' ').replaceAll("'", '');
    s = s.trim().split(RegExp(r'\s+')).join('-').replaceAll('/', '-');
    return 'https://www.gpkwijs.nl/gemeente/$s';
  }

  /// Zoek een plaats -> bounding box (via Nominatim).
  static Future<Plaats?> zoekPlaats(String naam) async {
    final uri = Uri.parse(
        '$nominatim/search?q=${Uri.encodeComponent('$naam, Nederland')}'
        '&format=jsonv2&limit=1');
    final r = await http.get(uri, headers: {'User-Agent': userAgent});
    if (r.statusCode != 200) return null;
    final data = jsonDecode(r.body) as List;
    if (data.isEmpty) return null;
    final bb = (data[0]['boundingbox'] as List?)?.map((e) => double.parse('$e')).toList();
    if (bb == null || bb.length != 4) return null;
    return Plaats(data[0]['display_name'].toString().split(',').first,
        bb[0], bb[1], bb[2], bb[3]);
  }

  /// Zoek de gemeente bij een coördinaat (reverse geocoding).
  static Future<String?> gemeenteBij(double lat, double lon) async {
    final uri = Uri.parse(
        '$nominatim/reverse?format=jsonv2&lat=$lat&lon=$lon&zoom=10&accept-language=nl');
    final r = await http.get(uri, headers: {'User-Agent': userAgent});
    if (r.statusCode != 200) return null;
    final a = (jsonDecode(r.body)['address'] ?? {}) as Map<String, dynamic>;
    return (a['municipality'] ?? a['city'] ?? a['town'] ?? a['village']) as String?;
  }

  /// Haal gehandicaptenplekken op binnen een bounding box (Overpass, met mirrors).
  static Future<List<Plek>> plekkenInBox(
      double zuid, double west, double noord, double oost) async {
    final bbox = '$zuid,$west,$noord,$oost';
    final query = '''[out:json][timeout:25];
(
  nwr["amenity"="parking_space"]["parking_space"="disabled"]($bbox);
  nwr["amenity"="parking_space"]["parking_space"="disabled;normal"]($bbox);
  nwr["amenity"="parking"]["parking_space"="disabled"]($bbox);
  nwr["amenity"="parking"]["disabled_spaces"]($bbox);
  nwr["amenity"="parking"]["capacity:disabled"]["capacity:disabled"!="0"]["capacity:disabled"!="no"]($bbox);
);
out center tags 800;''';
    for (final mirror in overpassMirrors) {
      try {
        final r = await http.post(Uri.parse(mirror),
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'User-Agent': userAgent,
            },
            body: 'data=${Uri.encodeComponent(query)}');
        if (r.statusCode != 200) continue;
        final els = (jsonDecode(r.body)['elements'] ?? []) as List;
        return els
            .map((e) => Plek.fromOsm(e as Map<String, dynamic>))
            .whereType<Plek>()
            .toList();
      } catch (_) {
        // volgende mirror
      }
    }
    throw Exception('Overpass onbereikbaar');
  }

  /// Regels voor een gemeente: probeer gpkwijs.nl live, val terug op ingebouwd.
  static Future<Regels> regelsVoor(String gemeente) async {
    final url = gpkwijsUrl(gemeente);
    final live = await _haalGpkwijs(gemeente, url);
    if (live != null) return live;

    final sleutel = gemeente.toLowerCase().replaceAll('gemeente ', '').trim();
    final m = _ingebouwd[sleutel] ?? _standaard;
    return Regels(
      label: m['label'] as String,
      status: m['status'] as String,
      regels: List<String>.from(m['regels'] as List),
      gpkwijsUrl: url,
      live: false,
    );
  }

  static Future<Regels?> _haalGpkwijs(String gemeente, String url) async {
    try {
      final r = await http.get(Uri.parse(url), headers: {'User-Agent': userAgent});
      if (r.statusCode != 200) return null;
      final html = r.body;
      final blokken = _parseGpkwijs(html);
      if (blokken.isEmpty) return null;

      // Statuskop
      String label = 'Regels van gpkwijs.nl';
      String status = 'wisselend';
      const statusWoorden = {
        'gratis': 'gratis', 'verschilt': 'wisselend',
        'vergunning': 'wisselend', 'betaald': 'betaald',
      };
      for (final b in blokken) {
        final k = b.$1.toLowerCase();
        if (b.$1.length < 60 && !b.$1.contains('?') &&
            !k.contains('gpk parkeren') &&
            statusWoorden.keys.any((w) => k.contains(w))) {
          label = b.$1;
          for (final e in statusWoorden.entries) {
            if (k.contains(e.key)) { status = e.value; break; }
          }
          break;
        }
      }

      // Samenvatting + vaste secties
      final regels = <String>[];
      for (final b in blokken) {
        if (b.$1.toLowerCase().startsWith('mag ik met een gpk gratis parkeren')) {
          regels.add(b.$2);
          break;
        }
      }
      const secties = ['Gratis parkeren met GPK?', 'Tijdslimiet?',
        'Kaart zichtbaar?', 'Uitzonderingen'];
      for (final s in secties) {
        for (final b in blokken) {
          if (b.$1.trim().toLowerCase() == s.toLowerCase()) {
            regels.add('${s.replaceAll('?', '')}: ${b.$2}');
            break;
          }
        }
      }
      if (regels.isEmpty) return null;

      String? gecontroleerd;
      final mg = RegExp(r'[Gg]econtroleerd(?:\s+op)?:?\s*(\d{1,2}\s+\w+\s+\d{4})')
          .firstMatch(html);
      if (mg != null) gecontroleerd = mg.group(1);
      String? bron;
      final mb = RegExp(r'Bron:\s*(https?://\S+)').firstMatch(html);
      if (mb != null) {
        // Knip af op eventuele afsluitende leestekens of tags.
        bron = mb.group(1)!.split(RegExp('[<"]')).first.replaceAll(RegExp(r'[.,)]+$'), '');
      }

      return Regels(
        label: label,
        status: status,
        regels: regels.take(6).toList(),
        gecontroleerd: gecontroleerd,
        bron: bron,
        gpkwijsUrl: url,
        live: true,
      );
    } catch (_) {
      return null;
    }
  }

  /// Zeer eenvoudige HTML-parser: (kop, tekst)-paren uit h1/h2/h3 + volgende alinea's.
  static List<(String, String)> _parseGpkwijs(String html) {
    // Verwijder scripts/styles/nav/footer
    var s = html.replaceAll(
        RegExp(r'<(script|style|nav|footer|header|form)[^>]*>.*?</\1>',
            dotAll: true, caseSensitive: false),
        ' ');
    final blokken = <(String, String)>[];
    // Vind koppen en de tekst tot de volgende kop
    final kopRe = RegExp(r'<h[123][^>]*>(.*?)</h[123]>', dotAll: true, caseSensitive: false);
    final matches = kopRe.allMatches(s).toList();
    for (var i = 0; i < matches.length; i++) {
      final kop = _stripTags(matches[i].group(1) ?? '').trim();
      final start = matches[i].end;
      final eind = (i + 1 < matches.length) ? matches[i + 1].start : s.length;
      final tekst = _stripTags(s.substring(start, eind))
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (kop.isNotEmpty && tekst.isNotEmpty) {
        blokken.add((kop, tekst.length > 400 ? tekst.substring(0, 400) : tekst));
      }
    }
    return blokken;
  }

  static String _stripTags(String s) => s
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&eacute;', 'é')
      .replaceAll('&euml;', 'ë');
}
