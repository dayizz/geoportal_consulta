import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_config.dart';
import 'predio_model.dart';

const _backendBaseUrl = 'http://127.0.0.1:8000';

class MunicipioLimite {
  final String id;
  final String nombre;
  final String? estado;
  final Map<String, dynamic> geometry;

  const MunicipioLimite({
    required this.id,
    required this.nombre,
    required this.geometry,
    this.estado,
  });

  factory MunicipioLimite.fromMap(Map<String, dynamic> map) {
    return MunicipioLimite(
      id: (map['id'] ?? map['nombre'] ?? '').toString(),
      nombre: (map['nombre'] ?? '').toString(),
      estado: map['estado']?.toString(),
      geometry: Map<String, dynamic>.from(
        (map['geometry'] as Map?) ?? const <String, dynamic>{},
      ),
    );
  }
}

class GeoJsonPredioFeature {
  final String id;
  final String? estatus;
  final bool esEnvolvente;
  final bool esEstacion;
  final Map<String, dynamic> geometry;
  final Map<String, dynamic> properties;

  const GeoJsonPredioFeature({
    required this.id,
    required this.geometry,
    required this.properties,
    this.estatus,
    this.esEnvolvente = false,
    this.esEstacion = false,
  });
}

class _MunicipioLookup {
  final String nombre;
  final String? estado;
  final List<List<LatLng>> polygons;

  const _MunicipioLookup({required this.nombre, required this.polygons, this.estado});
}

/// Extrae el display ID desde propiedades GeoJSON (CLAVE o NOM_SEDATU)
String _extractDisplayId(Map<String, dynamic> properties) {
  // Busca CLAVE
  final clave = properties['CLAVE']?.toString().trim();
  if (clave != null && clave.isNotEmpty && clave != 'N/D') {
    return clave;
  }
  
  // Busca NOM_SEDATU
  final nomSedatu = properties['NOM_SEDATU']?.toString().trim();
  if (nomSedatu != null && nomSedatu.isNotEmpty) {
    return nomSedatu;
  }
  
  // Fallback a ID o fid
  return (properties['ID'] ?? properties['fid'] ?? 'Feature').toString();
}

/// Mapeo de municipios a estados territoriales de México
String? _getEstadoFromMunicipio(String? municipio) {
  if (municipio == null || municipio.isEmpty) return null;
  
  final nom = municipio.trim().toLowerCase();
  
  // Mapa de municipio → estado
  const municipioToEstado = {
    // Nuevo León
    'monterrey': 'Nuevo León',
    'guadalupe': 'Nuevo León',
    'apodaca': 'Nuevo León',
    'santa catarina': 'Nuevo León',
    'san nicolás de los garza': 'Nuevo León',
    'san pedro garza garcía': 'Nuevo León',
    'escobedo': 'Nuevo León',
    'garcía': 'Nuevo León',
    'general escobedo': 'Nuevo León',
    'general zuazua': 'Nuevo León',
    'general terán': 'Nuevo León',
    'general treviño': 'Nuevo León',
    'ciénega de flores': 'Nuevo León',
    'cadereyta jiménez': 'Nuevo León',
    'cerralvo': 'Nuevo León',
    'doctor gonzález': 'Nuevo León',
    'hidalgo': 'Nuevo León',
    'higueras': 'Nuevo León',
    'hualahuises': 'Nuevo León',
    'iturbide': 'Nuevo León',
    'lampazos de naranjo': 'Nuevo León',
    'linares': 'Nuevo León',
    'marín': 'Nuevo León',
    'melchor ocampo': 'Nuevo León',
    'mina': 'Nuevo León',
    'montemorelos': 'Nuevo León',
    'pesquería': 'Nuevo León',
    'rayones': 'Nuevo León',
    'salinas victoria': 'Nuevo León',
    'san buenaventura': 'Nuevo León',
    'santiago': 'Nuevo León',
    'vallecillo': 'Nuevo León',
    'villaldama': 'Nuevo León',
    'agualeguas': 'Nuevo León',
    'allende': 'Nuevo León',
    'anáhuac': 'Nuevo León',
    'bustamante': 'Nuevo León',
    'los ramones': 'Nuevo León',
    'mainero': 'Nuevo León',
    'progreso': 'Nuevo León',
    'sabinas hidalgo': 'Nuevo León',
    'villagrán': 'Nuevo León',
    
    // Coahuila
    'saltillo': 'Coahuila',
    'arteaga': 'Coahuila',
    'ramos arizpe': 'Coahuila',
    'monclova': 'Coahuila',
    'abasolo': 'Coahuila',
    'castaños': 'Coahuila',
    'candela': 'Coahuila',
    'concepción del oro': 'Coahuila',
    'cuatro ciénegas': 'Coahuila',
    'el carmen': 'Coahuila',
    'el salvador': 'Coahuila',
    'frontera': 'Coahuila',
    'galeana': 'Coahuila',
    'general cepeda': 'Coahuila',
    'guerrero': 'Coahuila',
    'juárez': 'Coahuila',
    'lamadrid': 'Coahuila',
    'mazapil': 'Coahuila',
    'nadadores': 'Coahuila',
    'parras': 'Coahuila',
    'parás': 'Coahuila',
    'sacramento': 'Coahuila',
    
    // Tamaulipas
    'nuevo laredo': 'Tamaulipas',
  };
  
  return municipioToEstado[nom];
}

List<LatLng> _toLatLngs(List raw) {
  return raw
      .whereType<List>()
      .where((c) => c.length >= 2)
      .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
      .toList();
}

List<List<LatLng>> _extractPolygons(Map<String, dynamic> geo) {
  final type = geo['type'] as String?;
  if (type == 'Polygon') {
    final coords = geo['coordinates'] as List?;
    if (coords == null || coords.isEmpty) return const [];
    return [_toLatLngs(coords[0] as List)];
  }

  if (type == 'MultiPolygon') {
    final multiCoords = geo['coordinates'] as List?;
    if (multiCoords == null) return const [];
    return multiCoords
        .whereType<List>()
        .where((poly) => poly.isNotEmpty)
        .map((poly) => _toLatLngs((poly[0] as List)))
        .toList();
  }

  return const [];
}

LatLng _centroid(List<LatLng> points) {
  if (points.isEmpty) return const LatLng(0, 0);
  double lat = 0;
  double lng = 0;
  for (final p in points) {
    lat += p.latitude;
    lng += p.longitude;
  }
  return LatLng(lat / points.length, lng / points.length);
}

bool _pointInPolygon(LatLng point, List<LatLng> ring) {
  var inside = false;
  for (int i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final xi = ring[i].longitude;
    final yi = ring[i].latitude;
    final xj = ring[j].longitude;
    final yj = ring[j].latitude;

    final intersects =
        ((yi > point.latitude) != (yj > point.latitude)) &&
            (point.longitude <
                (xj - xi) * (point.latitude - yi) /
                        ((yj - yi).abs() < 1e-12 ? 1e-12 : (yj - yi)) +
                    xi);
    if (intersects) inside = !inside;
  }
  return inside;
}

Future<List<_MunicipioLookup>> _loadMunicipioLookup() async {
  try {
    final raw = await rootBundle.loadString('assets/data/municipios.geojson');
    final decoded = jsonDecode(raw);
    final features = (decoded is Map<String, dynamic>)
        ? decoded['features']
        : (decoded is List ? decoded : null);

    if (features is! List) return const [];

    return features
        .whereType<Map>()
        .map((f) => Map<String, dynamic>.from(f))
        .map((feature) {
          final props = Map<String, dynamic>.from(
            (feature['properties'] as Map?) ?? const <String, dynamic>{},
          );
          final nombre = (props['municipio'] ??
                  props['MUNICIPIO'] ??
                  props['nom_mun'] ??
                  props['NOM_MUN'] ??
                  props['shapeName'] ??
                  props['nombre'] ??
                  props['name'] ??
                  '')
              .toString()
              .trim();
          final geometry = Map<String, dynamic>.from(
            (feature['geometry'] as Map?) ?? const <String, dynamic>{},
          );
          final estado = (props['estado'] ??
                  props['ESTADO'] ??
                  props['entidad'] ??
                  props['ENTIDAD'] ??
                  '')
              .toString()
              .trim();
          // Si no hay estado en geojson, usar mapeo municipio→estado
          final estadoFinal = estado.isEmpty ? _getEstadoFromMunicipio(nombre) : estado;
          return _MunicipioLookup(
            nombre: nombre,
            estado: estadoFinal,
            polygons: _extractPolygons(geometry)
                .where((ring) => ring.length >= 3)
                .toList(),
          );
        })
        .where((m) => m.nombre.isNotEmpty && m.polygons.isNotEmpty)
        .toList();
  } catch (_) {
    return const [];
  }
}

String? _detectMunicipioFromGeometry(
  Map<String, dynamic>? geometry,
  List<_MunicipioLookup> municipios,
) {
  if (geometry == null || municipios.isEmpty) return null;

  final polygons = _extractPolygons(geometry)
      .where((ring) => ring.length >= 3)
      .toList();
  if (polygons.isEmpty) return null;

  final center = _centroid(polygons.first);
  for (final municipio in municipios) {
    for (final ring in municipio.polygons) {
      if (_pointInPolygon(center, ring)) {
        return municipio.nombre;
      }
    }
  }

  return null;
}

String? _detectEstadoFromGeometry(
  Map<String, dynamic>? geometry,
  List<_MunicipioLookup> municipios,
) {
  if (geometry == null || municipios.isEmpty) return null;

  final polygons = _extractPolygons(geometry)
      .where((ring) => ring.length >= 3)
      .toList();
  if (polygons.isEmpty) return null;

  final center = _centroid(polygons.first);
  for (final municipio in municipios) {
    for (final ring in municipio.polygons) {
      if (_pointInPolygon(center, ring)) {
        return municipio.estado;
      }
    }
  }

  return null;
}

Future<List<Predio>> _loadPrediosFromAssetGeoJson() async {
  try {
    final raw = await rootBundle.loadString('assets/data/TSN_SEG_16_17.geojson');
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return const [];

    final features = decoded['features'];
    if (features is! List) return const [];

    final allPredios = <Predio>[];
    final municipiosLookup = await _loadMunicipioLookup();

    for (final feature in features.whereType<Map>()) {
      final featureMap = Map<String, dynamic>.from(feature);
      final props = Map<String, dynamic>.from(
        (featureMap['properties'] as Map?) ?? const <String, dynamic>{},
      );
      final geometry = (featureMap['geometry'] as Map?) != null
          ? Map<String, dynamic>.from(featureMap['geometry'] as Map)
          : null;

      final featureProject =
          (props['PROYECTO'] ?? props['proyecto'] ?? '').toString().trim().toUpperCase();
        final municipioDetectado =
          _detectMunicipioFromGeometry(geometry, municipiosLookup);
      final estadoDetectado = _detectEstadoFromGeometry(geometry, municipiosLookup);
      allPredios.add(
        Predio.fromMap({
          'id': (props['ID'] ?? props['id'] ?? allPredios.length).toString(),
          'clave_catastral':
              (props['CLAVE'] ?? props['clave'] ?? 'GEOJSON-${allPredios.length + 1}')
                  .toString(),
          'tramo': (props['SEGMENTO'] ?? props['segmento'] ?? '').toString(),
          'tipo_propiedad': 'PRIVADA',
          'proyecto': featureProject.isEmpty ? null : featureProject,
          'municipio': municipioDetectado,
          'estado': estadoDetectado,
          'estatus': (props['ESTATUS'] ?? props['estatus'] ?? '').toString(),
          'ejido': (props['ejido'] ?? props['EJIDO'])?.toString(),
          'geometry': geometry,
          'created_at': DateTime.now().toIso8601String(),
        }),
      );
    }

    return allPredios;
  } catch (_) {
    return const [];
  }
}

/// Proveedor que obtiene predios del proyecto activo desde Supabase.
/// Retorna lista vacía si Supabase no está configurado.
final prediosConsultaProvider =
    FutureProvider.autoDispose<List<Predio>>((ref) async {
  // Modo archivo local: evita mezclar datos históricos de backend/Supabase.
  return _loadPrediosFromAssetGeoJson();
});

final municipiosLimitesProvider =
    FutureProvider.autoDispose<List<MunicipioLimite>>((ref) async {
  final remoteMunicipios = <MunicipioLimite>[];
  try {
    final response = await http
        .get(Uri.parse('$_backendBaseUrl/municipios'))
        .timeout(const Duration(seconds: 2));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        final remote = data
            .whereType<Map>()
            .map((e) => MunicipioLimite.fromMap(Map<String, dynamic>.from(e)))
            .where((m) => m.nombre.trim().isNotEmpty && m.geometry.isNotEmpty)
            .toList();
        remoteMunicipios.addAll(remote);
      }
    }
  } catch (_) {
    // Continuar con datos locales.
  }

  try {
    Future<List<Map<String, dynamic>>> readFeaturesFromAsset(String assetPath) async {
      final raw = await rootBundle.loadString(assetPath);
      final data = jsonDecode(raw);
      final features = (data is Map<String, dynamic>)
          ? data['features']
          : (data is List ? data : null);
      if (features is! List) return const [];
      return features
          .whereType<Map>()
          .map((f) => Map<String, dynamic>.from(f))
          .toList();
    }

    final allFeatures = <Map<String, dynamic>>[];
    final fallbackAssets = <String>[
      'assets/data/municipios.geojson',
      'assets/data/TAP_LIMITES_MUNICIPALES_ESTATALES.geojson',
    ];

    for (final assetPath in fallbackAssets) {
      try {
        allFeatures.addAll(await readFeaturesFromAsset(assetPath));
      } catch (_) {
        // Carga parcial: si un asset falla, continuar con el resto.
      }
    }

    final localMunicipios = allFeatures
        .map((feature) {
          final props = (feature['properties'] as Map?) ?? const {};
          final p = Map<String, dynamic>.from(props);
          final nivel = (p['nivel'] ?? p['NIVEL'] ?? '').toString().toLowerCase();
          final nombre = (p['municipio'] ??
                  p['MUNICIPIO'] ??
                  p['nom_mun'] ??
                  p['NOM_MUN'] ??
                  p['shapeName'] ??
                  p['nombre'] ??
                  p['name'] ??
                  '')
              .toString();
          final estado = (p['estado'] ?? p['ESTADO'] ?? p['shapeGroup'])
              ?.toString();
          return <String, dynamic>{
            'nivel': nivel,
            'municipio': MunicipioLimite(
              id: (feature['id'] ?? p['shapeID'] ?? p['id'] ?? nombre).toString(),
              nombre: nombre,
              estado: estado,
              geometry: Map<String, dynamic>.from(
                (feature['geometry'] as Map?) ?? const <String, dynamic>{},
              ),
            ),
          };
        })
        .where((entry) {
          final nivel = entry['nivel'] as String;
          // Para lookup de municipio solo incluir límites municipales.
          return nivel.isEmpty || nivel == 'municipio';
        })
        .map((entry) => entry['municipio'] as MunicipioLimite)
        .where((m) => m.nombre.trim().isNotEmpty && m.geometry.isNotEmpty)
        .toList();

    final merged = <MunicipioLimite>[...remoteMunicipios, ...localMunicipios];
    final dedup = <String, MunicipioLimite>{};
    for (final m in merged) {
      final key =
          '${m.nombre.trim().toLowerCase()}|${(m.estado ?? '').trim().toLowerCase()}';
      dedup[key] = m;
    }
    return dedup.values.toList();
  } catch (_) {
    return remoteMunicipios;
  }
});

final importedGeoJsonPrediosProvider =
    FutureProvider.autoDispose<List<GeoJsonPredioFeature>>((ref) async {
  try {
    Future<List<Map<String, dynamic>>> readFeatures(String assetPath) async {
      final raw = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const [];
      final features = decoded['features'];
      if (features is! List) return const [];
      return features
          .whereType<Map>()
          .map((f) => Map<String, dynamic>.from(f))
          .map((f) => {
                ...f,
                '__source_asset': assetPath,
              })
          .toList();
    }

    final importAssets = <String>[
      'assets/data/TSN_SEG_16_17.geojson',
      'assets/data/ENVOLVENTE_COMPLETA.geojson',
      'assets/data/TSN_SEG_13.geojson',
      'assets/data/TSN_SEG_18.geojson',
      'assets/data/ESTACIONES_Y_EDIFICIOS_AUXILIARES_TSNL_1805.geojson',
      'assets/data/AP-T00-SDEF-01-V00-PLA-PR_PRG-36779_25-A02.geojson',
      'assets/data/TAP_25_05_2026.geojson',
      'assets/data/pks.geojson',
    ];

    final mergedFeatures = <Map<String, dynamic>>[];
    for (final assetPath in importAssets) {
      try {
        mergedFeatures.addAll(await readFeatures(assetPath));
      } catch (_) {
        // Mantener carga parcial: si un archivo falla, no bloquear los demas.
      }
    }

    return mergedFeatures
        .map((feature) {
          final props = Map<String, dynamic>.from(
            (feature['properties'] as Map?) ?? const <String, dynamic>{},
          );
          final sourceAsset = (feature['__source_asset'] ?? '').toString().toLowerCase();
          final isTapEnvelopeAsset =
              sourceAsset.contains('ap-t00-sdef-01-v00-pla-pr_prg-36779_25-a02.geojson');
          final isTsnlEnvelopeAsset =
              sourceAsset.contains('envolvente_completa.geojson');
            final isTapAsset =
              sourceAsset.contains('/tap_') ||
              sourceAsset.contains('ap-t00-sdef-01-v00-pla-pr_prg-36779_25-a02');
            final isTsnlAsset =
              sourceAsset.contains('/tsn_') || sourceAsset.contains('tsnl');
          final hasEnvolventeSource =
              sourceAsset.contains('envolvente') || isTapEnvelopeAsset || isTsnlEnvelopeAsset;
          final hasEnvolventeProp = props.values.any(
            (value) => value.toString().toLowerCase().contains('envolvente'),
          );
          final hasEstacionProp = sourceAsset.contains('estaciones_y_edificios');
          final rawProject =
              (props['PROYECTO'] ?? props['proyecto'] ?? '').toString().trim().toUpperCase();
            final inferredEnvelopeProject =
              isTapEnvelopeAsset ? 'TAP' : (isTsnlEnvelopeAsset ? 'TSNL' : '');
            final inferredProject = inferredEnvelopeProject.isNotEmpty
              ? inferredEnvelopeProject
              : (isTapAsset ? 'TAP' : (isTsnlAsset ? 'TSNL' : ''));
          final finalProject =
              rawProject.isNotEmpty
                ? rawProject
                : ((hasEnvolventeSource || hasEnvolventeProp)
                  ? inferredEnvelopeProject
                  : inferredProject);
          final enrichedProps = <String, dynamic>{
            ...props,
            if (finalProject.isNotEmpty) 'PROYECTO': finalProject,
            if (hasEnvolventeSource || hasEnvolventeProp) 'TIPO_CAPA': 'ENVOLVENTE',
          };
          final propsWithMeta = <String, dynamic>{
            ...enrichedProps,
            '__source_asset': sourceAsset,
          };
          return GeoJsonPredioFeature(
            id: _extractDisplayId(enrichedProps),
            estatus: (enrichedProps['ESTATUS'] ?? enrichedProps['estatus'])?.toString(),
            esEnvolvente: hasEnvolventeSource || hasEnvolventeProp,
            esEstacion: hasEstacionProp,
            geometry: Map<String, dynamic>.from(
              (feature['geometry'] as Map?) ?? const <String, dynamic>{},
            ),
            properties: propsWithMeta,
          );
        })
        .where((f) => f.geometry.isNotEmpty)
        .toList();
  } catch (_) {
    return const [];
  }
});

Future<Map<String, dynamic>> autofillMunicipiosDesdeLimites({
  bool overwrite = false,
}) async {
  final uri = Uri.parse('$_backendBaseUrl/predios/autofill-municipio')
      .replace(queryParameters: {'overwrite': overwrite.toString()});
  final response = await http.post(uri);
  if (response.statusCode != 200) {
    throw Exception('No se pudo completar municipio desde límites');
  }
  final payload = jsonDecode(response.body);
  if (payload is Map<String, dynamic>) {
    return payload;
  }
  return <String, dynamic>{};
}
