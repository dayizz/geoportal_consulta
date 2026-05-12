import 'package:collection/collection.dart';
import 'package:latlong2/latlong.dart';

/// Cache simple para evitar recálculos de funciones puras
class MemoizedCache<K, V> {
  final Map<K, V> _cache = {};

  V getOrCompute(K key, V Function() compute) {
    return _cache.putIfAbsent(key, compute);
  }

  void invalidate(K key) => _cache.remove(key);
  void clear() => _cache.clear();
}

/// Caché de geometrías extraídas para evitar re-parseo
class GeometryCache {
  final Map<String, List<List<LatLng>>> _polygonCache = {};
  final Map<String, List<List<LatLng>>> _polylineCache = {};

  List<List<LatLng>> getPolygons(
    String id,
    Map<String, dynamic> geometry,
    List<List<LatLng>> Function(Map<String, dynamic>) extractor,
  ) {
    return _polygonCache.putIfAbsent(id, () => extractor(geometry));
  }

  List<List<LatLng>> getPolylines(
    String id,
    Map<String, dynamic> geometry,
    List<List<LatLng>> Function(Map<String, dynamic>) extractor,
  ) {
    return _polylineCache.putIfAbsent(id, () => extractor(geometry));
  }

  void clear() {
    _polygonCache.clear();
    _polylineCache.clear();
  }
}

/// Índice espacial simple para búsquedas rápidas de municipios
class SpatialIndex {
  final Map<String, List<LatLng>> _municipioIndex = {};

  void build(
    Iterable<MapEntry<String, List<LatLng>>> entries,
  ) {
    _municipioIndex.clear();
    _municipioIndex.addAll(Map.fromEntries(entries));
  }

  List<LatLng>? lookup(String key) => _municipioIndex[key];

  void clear() => _municipioIndex.clear();
}

/// Búsqueda de punto en polígono optimizada con early exit
bool pointInPolygonFast(LatLng point, List<LatLng> polygon) {
  if (polygon.length < 3) return false;

  var inside = false;
  var j = polygon.length - 1;

  for (var i = 0; i < polygon.length; j = i++) {
    final xi = polygon[i].longitude;
    final yi = polygon[i].latitude;
    final xj = polygon[j].longitude;
    final yj = polygon[j].latitude;

    final intersect = ((yi > point.latitude) != (yj > point.latitude)) &&
        (point.longitude <
            (xj - xi) * (point.latitude - yi) / (yj - yi) + xi);
    if (intersect) inside = !inside;
  }

  return inside;
}

/// Agrupa polígonos por zoom para renderizado selectivo
class ZoomAwarePolygonFilter {
  static const _HIGH_ZOOM_THRESHOLD = 14.0;
  static const _MEDIUM_ZOOM_THRESHOLD = 11.0;

  static bool shouldShowPolygonDetail(double zoom) => zoom >= _HIGH_ZOOM_THRESHOLD;
  static bool shouldShowPolygon(double zoom) => zoom >= _MEDIUM_ZOOM_THRESHOLD;
}

/// Merge de buckets optimizado
List<MapEntry<String, int>> mergeDuplicateEntries(
  Map<String, int> map,
) {
  return map.entries.toList();
}
