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

class PkGeoPoint {
  final String pk;
  final LatLng point;

  const PkGeoPoint({
    required this.pk,
    required this.point,
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

String _normalizeForMatch(String input) {
  return input
      .toLowerCase()
      .trim()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n');
}

bool _isStationFeature({
  required String sourceAsset,
  required Map<String, dynamic> properties,
}) {
  final normalizedSource = _normalizeForMatch(sourceAsset);
  if (normalizedSource.contains('estaciones_y_edificios') ||
      normalizedSource.contains('estacion') ||
      normalizedSource.contains('edificios_auxiliares') ||
      normalizedSource.contains('edificio_auxiliar')) {
    return true;
  }

  final estructura = _normalizeForMatch(
    (properties['ESTRUCTURA'] ?? properties['estructura'] ?? '').toString(),
  );
  if (estructura.contains('estacion') || estructura.contains('edificio')) {
    return true;
  }

  for (final entry in properties.entries) {
    final key = _normalizeForMatch(entry.key);
    if (!key.contains('estructura') && !key.contains('tipo')) continue;
    final value = _normalizeForMatch((entry.value ?? '').toString());
    if (value.contains('estacion') || value.contains('edificio auxiliar')) {
      return true;
    }
  }

  return false;
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

Future<List<String>> _loadGeoJsonAssetManifest() async {
  final raw = await rootBundle.loadString('assets/data/manifest.json');
  final decoded = jsonDecode(raw);
  if (decoded is! List) return const [];
  return decoded
      .whereType<String>()
      .where((path) => path.startsWith('assets/data/') && path.endsWith('.geojson'))
      .toList();
}

Future<List<Predio>> _loadPrediosFromAssetGeoJson() async {
  try {
    final allPredios = <Predio>[];
    final municipiosLookup = await _loadMunicipioLookup();

    final predioAssets = (await _loadGeoJsonAssetManifest())
        .where((path) {
          final lower = path.toLowerCase();
          return !lower.contains('municipios') &&
              !lower.contains('envolvente') &&
              !lower.contains('estaciones_y_edificios');
        })
        .toList()
      ..sort();

    for (final assetPath in predioAssets) {
      final raw = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) continue;

      final features = decoded['features'];
      if (features is! List) continue;

      for (final feature in features.whereType<Map>()) {
        final featureMap = Map<String, dynamic>.from(feature);
        final props = Map<String, dynamic>.from(
          (featureMap['properties'] as Map?) ?? const <String, dynamic>{},
        );
        final geometry = (featureMap['geometry'] as Map?) != null
            ? Map<String, dynamic>.from(featureMap['geometry'] as Map)
            : null;

        final featureProject = (props['PROYECTO'] ?? props['proyecto'] ?? '')
            .toString()
            .trim()
            .toUpperCase();
        final municipioDetectado =
            _detectMunicipioFromGeometry(geometry, municipiosLookup);
        final estadoDetectado =
            _detectEstadoFromGeometry(geometry, municipiosLookup);
        allPredios.add(
          Predio.fromMap({
            'id': (props['ID'] ?? props['id'] ?? '${assetPath}_${allPredios.length}')
                .toString(),
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
        if (remote.isNotEmpty) return remote;
      }
    }
  } catch (_) {
    // Fallback below.
  }

  try {
    final raw = await rootBundle.loadString('assets/data/municipios.geojson');
    final data = jsonDecode(raw);
    final features = (data is Map<String, dynamic>)
        ? data['features']
        : (data is List ? data : null);
    if (features is! List) return const [];
    return features
        .whereType<Map>()
        .map((f) => Map<String, dynamic>.from(f))
        .map((feature) {
          final props = (feature['properties'] as Map?) ?? const {};
          final p = Map<String, dynamic>.from(props);
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
          return MunicipioLimite(
            id: (feature['id'] ?? p['shapeID'] ?? nombre).toString(),
            nombre: nombre,
            estado: estado,
            geometry: Map<String, dynamic>.from(
              (feature['geometry'] as Map?) ?? const <String, dynamic>{},
            ),
          );
        })
        .where((m) => m.nombre.trim().isNotEmpty && m.geometry.isNotEmpty)
        .toList();
  } catch (_) {
    return const [];
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

    final importAssets = await _loadGeoJsonAssetManifest();

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
          final propsWithMeta = <String, dynamic>{
            ...props,
            '__source_asset': sourceAsset,
          };
          final hasEnvolventeSource = sourceAsset.contains('envolvente');
          final hasEnvolventeProp = props.values.any(
            (value) => value.toString().toLowerCase().contains('envolvente'),
          );
          final hasEstacionProp = _isStationFeature(
            sourceAsset: sourceAsset,
            properties: props,
          );
          return GeoJsonPredioFeature(
            id: _extractDisplayId(props),
            estatus: (props['ESTATUS'] ?? props['estatus'])?.toString(),
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

final pksGeoJsonProvider =
    FutureProvider.autoDispose<List<PkGeoPoint>>((ref) async {
  try {
    final raw = await rootBundle.loadString('assets/data/pks.geojson');
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return const [];
    final features = decoded['features'];
    if (features is! List) return const [];

    final points = <PkGeoPoint>[];
    for (final item in features.whereType<Map>()) {
      final feature = Map<String, dynamic>.from(item);
      final props = Map<String, dynamic>.from(
        (feature['properties'] as Map?) ?? const <String, dynamic>{},
      );
      final geometry = Map<String, dynamic>.from(
        (feature['geometry'] as Map?) ?? const <String, dynamic>{},
      );
      if ((geometry['type'] as String?) != 'Point') continue;

      final coords = geometry['coordinates'];
      if (coords is! List || coords.length < 2) continue;
      final lngRaw = coords[0];
      final latRaw = coords[1];
      if (lngRaw is! num || latRaw is! num) continue;
      final lng = lngRaw.toDouble();
      final lat = latRaw.toDouble();
      if (!lng.isFinite || !lat.isFinite) continue;
      if (lng < -180 || lng > 180 || lat < -90 || lat > 90) continue;

      String pk = '';
      for (final entry in props.entries) {
        final key = entry.key.toLowerCase().trim();
        if (key == 'pk' || key == 'pks' || key.contains('pk')) {
          pk = (entry.value ?? '').toString().trim();
          if (pk.isNotEmpty) break;
        }
      }
      if (pk.isEmpty) continue;

      points.add(PkGeoPoint(pk: pk, point: LatLng(lat, lng)));
    }
    return points;
  } catch (_) {
    return const [];
  }
});
