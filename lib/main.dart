// ---------------------------------------------------------------------------
// GPK — Gehandicapten Parkeerplaats (v1.0)
// Vind gehandicaptenparkeerplaatsen in Nederland en de parkeerregels per gemeente.
// Gemaakt door Michael van der Meijden.
// ---------------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';

import 'services.dart';

// Kleuren — Nederlands verkeersbord-blauw.
const kBlauw = Color(0xFF0B5AA6);
const kBlauwDonker = Color(0xFF083D72);
const kDiep = Color(0xFF06243F);
const kInkt = Color(0xFF12212E);
const kLucht = Color(0xFFEAF2FB);
const kDemping = Color(0xFF5B6B7B);
const kLijn = Color(0xFFDBE4EE);
const kGratis = Color(0xFF1B7A43);
const kGratisLicht = Color(0xFFE4F4EA);
const kBetaald = Color(0xFFB4531A);
const kBetaaldLicht = Color(0xFFFBEDE2);
const kWisselend = Color(0xFF5E6B7A);
const kWisselendLicht = Color(0xFFECEFF3);

void main() => runApp(const GpkApp());

class GpkApp extends StatelessWidget {
  const GpkApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPK — Gehandicapten Parkeerplaats',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: kBlauw,
        scaffoldBackgroundColor: kLucht,
        fontFamily: 'Roboto',
      ),
      home: const KaartScherm(),
    );
  }
}

class KaartScherm extends StatefulWidget {
  const KaartScherm({super.key});
  @override
  State<KaartScherm> createState() => _KaartSchermState();
}

class _KaartSchermState extends State<KaartScherm> {
  final _kaart = MapController();
  final _zoek = TextEditingController();
  List<Plek> _plekken = [];
  bool _bezig = false;
  String _status = 'Zoek een plaats of gebruik de knoppen hieronder';

  // ---- Data ophalen -------------------------------------------------------

  /// Haal plekken op voor het huidige kaartbeeld. [ververs] = "Download nieuwste"
  /// (vervangt), anders "Bijwerken" (voegt toe aan wat er is).
  Future<void> _haalHuidigBeeld({required bool ververs}) async {
    LatLngBounds b;
    try {
      b = _kaart.camera.visibleBounds;
    } catch (_) {
      _toast('Beweeg de kaart eerst naar een gebied.');
      return;
    }
    setState(() {
      _bezig = true;
      _status = ververs ? 'Nieuwste plekken ophalen…' : 'Bijwerken…';
    });
    try {
      final nieuw = await GpkService.plekkenInBox(
          b.south, b.west, b.north, b.east);
      setState(() {
        if (ververs) {
          _plekken = nieuw;
        } else {
          // Samenvoegen zonder dubbelen (op coördinaat)
          final gezien = _plekken
              .map((p) => '${p.lat.toStringAsFixed(6)},${p.lon.toStringAsFixed(6)}')
              .toSet();
          for (final p in nieuw) {
            final sleutel =
                '${p.lat.toStringAsFixed(6)},${p.lon.toStringAsFixed(6)}';
            if (!gezien.contains(sleutel)) {
              _plekken.add(p);
              gezien.add(sleutel);
            }
          }
        }
        _status = _plekken.isEmpty
            ? 'Geen plekken in dit gebied gevonden (of nog niet in OpenStreetMap).'
            : '${_plekken.length} plek${_plekken.length == 1 ? '' : 'ken'} in beeld.';
      });
    } catch (_) {
      _toast('Ophalen mislukt — ben je online? Probeer het zo nog eens.');
    } finally {
      if (mounted) setState(() => _bezig = false);
    }
  }

  Future<void> _zoekPlaats() async {
    final q = _zoek.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _bezig = true;
      _status = "Zoeken naar '$q'…";
    });
    try {
      final plaats = await GpkService.zoekPlaats(q);
      if (plaats == null) {
        _toast("'$q' niet gevonden");
        setState(() => _bezig = false);
        return;
      }
      _kaart.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(plaats.zuid, plaats.west),
          LatLng(plaats.noord, plaats.oost),
        ),
        padding: const EdgeInsets.all(30),
      ));
      final plekken = await GpkService.plekkenInBox(
          plaats.zuid, plaats.west, plaats.noord, plaats.oost);
      setState(() {
        _plekken = plekken;
        _status = plekken.isEmpty
            ? "Geen plekken in kaart gebracht in ${plaats.naam}."
            : '${plaats.naam}: ${plekken.length} plek${plekken.length == 1 ? '' : 'ken'}.';
      });
    } catch (_) {
      _toast('Zoeken mislukt — ben je online?');
    } finally {
      if (mounted) setState(() => _bezig = false);
    }
  }

  void _toast(String t) {
    if (!mounted) return;
    setState(() => _status = t);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(t),
        behavior: SnackBarBehavior.floating,
        backgroundColor: kDiep,
      ));
  }

  // ---- Plek-detail als bottom sheet --------------------------------------

  void _openPlek(Plek p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => PlekSheet(plek: p),
    );
  }

  // ---- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _kop(),
          Expanded(
            child: Stack(
              children: [
                _bouwKaart(),
                if (_bezig)
                  const Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: SizedBox(
                        width: 26, height: 26,
                        child: CircularProgressIndicator(
                            strokeWidth: 3, color: kBlauw),
                      ),
                    ),
                  ),
                _statusbalk(),
              ],
            ),
          ),
          _werkbalk(),
        ],
      ),
    );
  }

  Widget _kop() {
    return Container(
      color: kDiep,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 14, right: 14, bottom: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: kBlauw,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                alignment: Alignment.center,
                child: const Text('♿',
                    style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GPK Parkeren',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    Text('Gehandicaptenparkeerplaatsen',
                        style: TextStyle(color: Color(0xFF8FB2D6), fontSize: 10)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.white),
                onPressed: _openOver,
                tooltip: 'Over deze app',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.search, color: kDemping, size: 20),
                Expanded(
                  child: TextField(
                    controller: _zoek,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _zoekPlaats(),
                    decoration: const InputDecoration(
                      hintText: 'Zoek een plaats…',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 8, vertical: 12),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _zoekPlaats,
                  child: const Text('Zoek',
                      style: TextStyle(
                          color: kBlauw, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bouwKaart() {
    return FlutterMap(
      mapController: _kaart,
      options: const MapOptions(
        initialCenter: LatLng(52.15, 5.4),
        initialZoom: 7.5,
        minZoom: 6,
        maxZoom: 19,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'nl.gpk.app',
          maxZoom: 19,
        ),
        MarkerLayer(
          markers: [
            for (final p in _plekken)
              Marker(
                point: p.punt,
                width: 30,
                height: 38,
                alignment: Alignment.topCenter,
                child: GestureDetector(
                  onTap: () => _openPlek(p),
                  child: const _Pin(),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _statusbalk() {
    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: Container(
        color: kDiep.withOpacity(0.92),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(_status,
            style: const TextStyle(color: Color(0xFFB8CCE0), fontSize: 12)),
      ),
    );
  }

  Widget _werkbalk() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 12, right: 12, top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _bezig ? null : () => _haalHuidigBeeld(ververs: true),
              icon: const Icon(Icons.download, size: 20),
              label: const Text('Download nieuwste'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kGratis,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _bezig ? null : () => _haalHuidigBeeld(ververs: false),
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('Bijwerken'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kBlauwDonker,
                side: const BorderSide(color: kLijn),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openOver() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Over GPK Parkeren'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Versie 1.0',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              Text('Gemaakt door Michael van der Meijden'),
              SizedBox(height: 12),
              Text(
                  'Vind gehandicaptenparkeerplaatsen in Nederland en de '
                  'parkeerregels per gemeente.\n\n'
                  'Bronnen: OpenStreetMap (plekken), gpkwijs.nl en gemeenten '
                  '(regels), Nominatim (zoeken).\n\n'
                  'Aan deze informatie kunnen geen rechten worden ontleend. '
                  'De borden ter plaatse en de gemeente zijn altijd leidend.',
                  style: TextStyle(fontSize: 13, height: 1.4)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Sluiten'),
          ),
        ],
      ),
    );
  }
}

// Bord-pin marker.
class _Pin extends StatelessWidget {
  const _Pin();
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: kBlauw,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          alignment: Alignment.center,
          child: const Text('♿',
              style: TextStyle(color: Colors.white, fontSize: 15)),
        ),
        // klein pijltje onder de pin
        Transform.translate(
          offset: const Offset(0, -2),
          child: CustomPaint(size: const Size(10, 6), painter: _PinPunt()),
        ),
      ],
    );
  }
}

class _PinPunt extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = kBlauw;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width / 2, s.height)
      ..close();
    c.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Bottom sheet: plekdetails + gemeenteregels (regels live geladen).
// ---------------------------------------------------------------------------
class PlekSheet extends StatefulWidget {
  final Plek plek;
  const PlekSheet({super.key, required this.plek});
  @override
  State<PlekSheet> createState() => _PlekSheetState();
}

class _PlekSheetState extends State<PlekSheet> {
  String? _gemeente;
  Regels? _regels;
  bool _laden = true;

  @override
  void initState() {
    super.initState();
    _haalRegels();
  }

  Future<void> _haalRegels() async {
    final gem = await GpkService.gemeenteBij(widget.plek.lat, widget.plek.lon);
    Regels? r;
    if (gem != null) r = await GpkService.regelsVoor(gem);
    if (mounted) {
      setState(() {
        _gemeente = gem;
        _regels = r;
        _laden = false;
      });
    }
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Kon de link niet openen.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Color _badgeVg(String s) => s == 'gratis'
      ? kGratis
      : s == 'betaald'
          ? kBetaald
          : kWisselend;
  Color _badgeBg(String s) => s == 'gratis'
      ? kGratisLicht
      : s == 'betaald'
          ? kBetaaldLicht
          : kWisselendLicht;

  @override
  Widget build(BuildContext context) {
    final p = widget.plek;
    final rijen = <(String, String)>[
      if (p.naam != null) ('Locatie', p.naam!),
      if (p.capaciteit != null) ('Aantal plekken', p.capaciteit!),
      if (p.betaald != null)
        ('Betaald (OSM)',
            p.betaald == 'no' ? 'Nee' : p.betaald == 'yes' ? 'Ja' : p.betaald!),
      if (p.maxduur != null) ('Max. duur', p.maxduur!),
      if (p.overdekt) ('Overdekt', 'Ja'),
      ('Coördinaten',
          '${p.lat.toStringAsFixed(5)}, ${p.lon.toStringAsFixed(5)}'),
    ];
    final route =
        'https://www.google.com/maps/dir/?api=1&destination=${p.lat},${p.lon}';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (_, scroll) => SingleChildScrollView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                    color: kLijn, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const _Eyebrow('PARKEERPLAATS'),
            const Text('Gehandicaptenplek',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
            Text(_gemeente != null ? 'Gemeente $_gemeente' : 'Gemeente wordt opgezocht…',
                style: const TextStyle(color: kDemping, fontSize: 12)),
            const SizedBox(height: 16),
            const _Eyebrow('DETAILS'),
            const SizedBox(height: 4),
            for (final r in rijen) _DetailRij(label: r.$1, waarde: r.$2),
            const SizedBox(height: 10),
            _LinkKnop(
              tekst: '→  Routebeschrijving',
              onTap: () => _open(route),
            ),
            const SizedBox(height: 18),
            const _Eyebrow('GEMEENTEREGELS'),
            const SizedBox(height: 8),
            if (_laden)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text('Regels ophalen…', style: TextStyle(color: kDemping)),
                ]),
              )
            else if (_regels != null)
              _regelsBlok(_regels!)
            else
              const Text('Regels konden niet worden opgehaald.',
                  style: TextStyle(color: kDemping)),
          ],
        ),
      ),
    );
  }

  Widget _regelsBlok(Regels r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: _badgeBg(r.status),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(r.label,
              style: TextStyle(
                  color: _badgeVg(r.status),
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ),
        const SizedBox(height: 10),
        for (final regel in r.regels)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  ',
                    style: TextStyle(
                        color: kBlauw, fontWeight: FontWeight.w700)),
                Expanded(
                    child: Text(regel,
                        style: const TextStyle(fontSize: 14, height: 1.45))),
              ],
            ),
          ),
        const SizedBox(height: 6),
        if (r.live)
          Text(
            'Actuele regels van gpkwijs.nl'
            '${r.gecontroleerd != null ? ' · gecontroleerd ${r.gecontroleerd}' : ''}',
            style: const TextStyle(fontSize: 11, color: kDemping),
          )
        else
          const Text('Ingebouwde teksten (live regels niet beschikbaar).',
              style: TextStyle(fontSize: 11, color: kDemping)),
        const SizedBox(height: 8),
        _LinkKnop(
          tekst: '→  Regels van ${_gemeente ?? 'de gemeente'} op gpkwijs.nl',
          onTap: () => _open(r.gpkwijsUrl),
        ),
        if (r.bron != null) ...[
          const SizedBox(height: 8),
          _LinkKnop(
            tekst: '→  Officiële bron van de gemeente',
            onTap: () => _open(r.bron!),
          ),
        ],
        const SizedBox(height: 12),
        const Text(
          'Deze informatie is indicatief en kan verouderd zijn. De borden ter '
          'plaatse en de gemeente zijn altijd leidend.',
          style: TextStyle(fontSize: 11, color: kDemping, height: 1.4),
        ),
      ],
    );
  }
}

class _Eyebrow extends StatelessWidget {
  final String tekst;
  const _Eyebrow(this.tekst);
  @override
  Widget build(BuildContext context) => Text(tekst,
      style: const TextStyle(
          color: kBlauw,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8));
}

class _DetailRij extends StatelessWidget {
  final String label, waarde;
  const _DetailRij({required this.label, required this.waarde});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 11, color: kDemping)),
            Text(waarde,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _LinkKnop extends StatelessWidget {
  final String tekst;
  final VoidCallback onTap;
  const _LinkKnop({required this.tekst, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            border: Border.all(color: kLijn),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(tekst,
              style: const TextStyle(
                  color: kBlauw, fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      );
}
