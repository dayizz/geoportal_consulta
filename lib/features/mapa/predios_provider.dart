import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_config.dart';
import '../auth/auth_provider.dart';
import 'predio_model.dart';

const _backendBaseUrl = 'http://127.0.0.1:8000';
const _projectCodes = ['TQI', 'TSNL', 'TAP', 'TQM'];

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
  final Map<String, dynamic> geometry;

  const GeoJsonPredioFeature({
    required this.id,
    required this.geometry,
    this.estatus,
  });
}

class _MunicipioLookup {
  final String nombre;
  final List<List<LatLng>> polygons;

  const _MunicipioLookup({required this.nombre, required this.polygons});
}

String? _inferProyecto(Predio predio) {
  final directo = predio.proyecto?.trim().toUpperCase();
  if (directo != null && _projectCodes.contains(directo)) {
    return directo;
  }

  final contenido = [
    predio.claveCatastral,
    predio.ejido ?? '',
  ].join(' ').toUpperCase();

  for (final code in _projectCodes) {
    if (contenido.contains(code)) return code;
  }

  if (predio.claveCatastral.trim().toUpperCase().startsWith('QI-')) {
    return 'TQI';
  }

  return null;
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
          return _MunicipioLookup(
            nombre: nombre,
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

Future<List<Predio>> _loadPrediosFromAssetGeoJson(String proyecto) async {
  try {
    final raw = await rootBundle.loadString('assets/data/TSNL-131617.geojson');
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return const [];

    final features = decoded['features'];
    if (features is! List) return const [];

    final requestedProject = proyecto.trim().toUpperCase();
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
      allPredios.add(
        Predio.fromMap({
          'id': (props['ID'] ?? props['id'] ?? allPredios.length).toString(),
          'clave_catastral':
              (props['CLAVE'] ?? props['clave'] ?? 'GEOJSON-${allPredios.length + 1}')
                  .toString(),
          'tramo': (props['SEGMENTO'] ?? props['segmento'] ?? '').toString(),
          'tipo_propiedad': 'PRIVADA',
          'proyecto': (featureProject.isEmpty ? requestedProject : featureProject),
          'municipio': municipioDetectado,
          'estatus': (props['ESTATUS'] ?? props['estatus'] ?? '').toString(),
          'geometry': geometry,
          'created_at': DateTime.now().toIso8601String(),
        }),
      );
    }

    final byProject = allPredios
        .where((p) => (p.proyecto ?? '').trim().toUpperCase() == requestedProject)
        .toList();
    if (byProject.isNotEmpty) return byProject;
    return allPredios;
  } catch (_) {
    return const [];
  }
}

/// Proveedor que obtiene predios del proyecto activo desde Supabase.
/// Retorna lista vacía si Supabase no está configurado.
final prediosConsultaProvider =
    FutureProvider.autoDispose<List<Predio>>((ref) async {
  final proyecto = ref.watch(proyectoActivoProvider);
  if (proyecto == null) return [];

  if (!SupabaseConfig.isConfigured) {
    try {
      final uri = Uri.parse('$_backendBaseUrl/predios').replace(
        queryParameters: {'proyecto': proyecto},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) {
        return _loadPrediosFromAssetGeoJson(proyecto);
      }

      final data = jsonDecode(response.body) as List;
      final prediosFiltrados = data
          .map((e) => Predio.fromMap(e as Map<String, dynamic>))
          .toList();

      if (prediosFiltrados.isNotEmpty) {
        return prediosFiltrados;
      }

      // Fallback: si el backend devuelve vacío por filtro estricto de proyecto,
      // recuperar todo y filtrar en cliente usando inferencia de proyecto.
      final fallbackResponse =
          await http.get(Uri.parse('$_backendBaseUrl/predios')).timeout(
                const Duration(seconds: 3),
              );
      if (fallbackResponse.statusCode != 200) {
        return _loadPrediosFromAssetGeoJson(proyecto);
      }

      final fallbackData = jsonDecode(fallbackResponse.body) as List;
      final allPredios = fallbackData
          .map((e) => Predio.fromMap(e as Map<String, dynamic>))
          .toList();

      final inferred = allPredios
          .where((predio) => _inferProyecto(predio) == proyecto.toUpperCase())
          .toList();
      if (inferred.isNotEmpty) return inferred;
      return _loadPrediosFromAssetGeoJson(proyecto);
    } catch (_) {
      return _loadPrediosFromAssetGeoJson(proyecto);
    }
  }

  final client = Supabase.instance.client;
  final response = await client
      .from('predios')
      .select()
      .eq('proyecto', proyecto)
      .order('created_at');

    final supabasePredios = (response as List)
      .map((e) => Predio.fromMap(e as Map<String, dynamic>))
      .toList();
    if (supabasePredios.isNotEmpty) return supabasePredios;
    return _loadPrediosFromAssetGeoJson(proyecto);
});

final municipiosLimitesProvider =
    FutureProvider.autoDispose<List<MunicipioLimite>>((ref) async {
  try {
    final response = await http
        .get(Uri.parse('$_backendBaseUrl/municipios'))
        .timeout(const Duration(seconds: 3));
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
    final raw = await rootBundle.loadString('assets/data/TSNL-131617.geojson');
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return const [];

    final features = decoded['features'];
    if (features is! List) return const [];

    return features
        .whereType<Map>()
        .map((f) => Map<String, dynamic>.from(f))
        .map((feature) {
          final props = Map<String, dynamic>.from(
            (feature['properties'] as Map?) ?? const <String, dynamic>{},
          );
          return GeoJsonPredioFeature(
            id: (props['ID'] ?? feature['id'] ?? '').toString(),
            estatus: (props['ESTATUS'] ?? props['estatus'])?.toString(),
            geometry: Map<String, dynamic>.from(
              (feature['geometry'] as Map?) ?? const <String, dynamic>{},
            ),
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
