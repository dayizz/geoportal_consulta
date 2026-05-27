
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../auth/auth_provider.dart';
import 'optimization_utils.dart';
import 'predio_model.dart';
import 'predios_provider.dart';

// --- Utilidades puras fuera de la clase principal ---
Set<String> collectUniquePropertyValues({
  required List<Predio> predios,
  required List<GeoJsonPredioFeature> imported,
  required String Function(Predio) predioSelector,
  required String Function(Map<String, dynamic>) importedSelector,
  String emptyLabel = 'Sin dato',
}) {
  final values = <String>{};
  for (final p in predios) {
    final v = predioSelector(p).trim();
    values.add(v.isEmpty ? emptyLabel : v);
  }
  for (final f in imported) {
    final v = importedSelector(f.properties).trim();
    values.add(v.isEmpty ? emptyLabel : v);
  }
  values.removeWhere((v) => v.isEmpty);
  return values;
}

Map<String, int> countByFieldUnified({
  required List<Predio> predios,
  required List<GeoJsonPredioFeature> imported,
  required String Function(Predio) predioSelector,
  required String Function(Map<String, dynamic>) importedSelector,
  String emptyLabel = 'Sin dato',
}) {
  final counts = <String, int>{};
  for (final p in predios) {
    final v = predioSelector(p).trim();
    final key = v.isEmpty ? emptyLabel : v;
    counts[key] = (counts[key] ?? 0) + 1;
  }
  for (final f in imported) {
    final v = importedSelector(f.properties).trim();
    final key = v.isEmpty ? emptyLabel : v;
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return counts;
}
// --- Fin utilidades puras ---

// Colores por estado de gestión
Color _colorEstado(Predio p) {
  final estatus = p.estatus?.trim().toLowerCase();
  if (estatus == 'liberado') return const Color(0xFFCDDC39); // verde lima
  if (estatus == 'no liberado') return const Color(0xFFD32F2F); // rojo
  if (p.negociacion) return const Color(0xFF1B5E20); // verde oscuro
  if (p.cop) return const Color(0xFFCDDC39); // verde lima
  if (p.levantamiento) return const Color(0xFFF57F17); // ámbar
  if (p.identificacion) return const Color(0xFF1565C0); // azul
  return const Color(0xFF757575); // gris
}

// Colores por tipo de propiedad
Color _colorTipo(Predio p) {
  switch (p.tipoPropiedad.toUpperCase()) {
    case 'SOCIAL':
      return const Color(0xFF7E57C2);
    case 'PRIVADA':
      return const Color(0xFFF57C00);
    default:
      return const Color(0xFF6D6D6D);
  }
}

enum _ColorMode { estado, tipo }

enum _LiberacionFilter { todos, liberados, noLiberados }

enum _BaseLayer { estandar, satelital }

class _HeatBucket {
  _HeatBucket({
    required this.center,
    this.count = 0,
    this.liberados = 0,
    this.noLiberados = 0,
    this.sample,
  });

  LatLng center;
  int count;
  int liberados;
  int noLiberados;
  Predio? sample;
}

class MapaConsultaScreen extends ConsumerStatefulWidget {
  const MapaConsultaScreen({super.key});

  @override
  ConsumerState<MapaConsultaScreen> createState() =>
      _MapaConsultaScreenState();
}

class _MapaConsultaScreenState extends ConsumerState<MapaConsultaScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapCtrl = MapController();
  Predio? _selectedPredio;
  GeoJsonPredioFeature? _selectedImportedFeature;
  bool _filterSoloEstaciones = false;
  bool _agruparMarcadores = true;
  bool _mostrarEtiquetas = false;
  bool _mostrarPks = false;
  Set<String> _selectedTipoProyectos = {};
  Set<String> _selectedEstatus = {};
  Set<String> _selectedEjidos = {};
  Set<String> _selectedClasificaciones = {};
  Set<String> _selectedMunicipios = {};
  _ColorMode _colorMode = _ColorMode.estado;
  _LiberacionFilter _liberacionFilter = _LiberacionFilter.todos;
  _BaseLayer _baseLayer = _BaseLayer.satelital;
  bool _isRefreshing = false;
  bool _didInitialFocus = false;
  bool _didImportedGeoJsonFocus = false;
  Set<String> _segmentoQueries = {};
  String? _lastFocusedMunicipioKey;
  DateTime? _lastRefresh;
  late AnimationController _spinCtrl;
  double _currentZoom = _defaultZoom;
  int _zoomRenderStep = (_defaultZoom * 2).round();

  // Caches para optimización
  late GeometryCache _geometryCache;
  late SpatialIndex _spatialIndex;
  late MemoizedCache<String, LatLng> _centroidCache;

  static const _defaultCenter = LatLng(20.72, -100.35);
  static const _defaultZoom = 10.0;

  @override
  void initState() {
    super.initState();
    _geometryCache = GeometryCache();
    _spatialIndex = SpatialIndex();
    _centroidCache = MemoizedCache<String, LatLng>();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _lastRefresh = DateTime.now();
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _geometryCache.clear();
    _spatialIndex.clear();
    _centroidCache.clear();
    super.dispose();
  }

  Future<void> _recargar() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    _spinCtrl.repeat();
    _didInitialFocus = false;
    _didImportedGeoJsonFocus = false;
    // Invalida el provider para que vuelva a cargar desde Supabase
    ref.invalidate(prediosConsultaProvider);
    // Esperar a que el future resuelva
    await ref.read(prediosConsultaProvider.future).catchError((_) => <Predio>[]);
    if (mounted) {
      _spinCtrl.stop();
      _spinCtrl.reset();
      setState(() {
        _isRefreshing = false;
        _lastRefresh = DateTime.now();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final prediosAsync = ref.watch(prediosConsultaProvider);
    final municipiosAsync = ref.watch(municipiosLimitesProvider);
    final importedGeoJsonAsync = ref.watch(importedGeoJsonPrediosProvider);

    return Scaffold(
      body: Stack(
        children: [
          // ─── Mapa ───────────────────────────────────────────────────────
          prediosAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (predios) => _buildMap(
              predios,
              municipiosAsync.valueOrNull ?? const [],
              importedGeoJsonAsync.valueOrNull ?? const [],
            ),
          ),

          // ─── TopBar ─────────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(
              prediosAsync.valueOrNull ?? [],
              municipiosAsync.valueOrNull ?? const [],
              importedGeoJsonAsync.valueOrNull ?? const [],
            ),
          ),

          // ─── Panel de detalle ────────────────────────────────────────────
          if (_selectedImportedFeature != null)
            Positioned(
              right: 0,
              top: 112,
              bottom: 0,
              width: 320,
              child: _buildDetailPanelForImportedFeature(_selectedImportedFeature!),
            )
          else if (_selectedPredio != null)
            Positioned(
              right: 0,
              top: 112,
              bottom: 0,
              width: 320,
              child: _buildDetailPanel(_selectedPredio!),
            ),

          // ─── Selector de capas ──────────────────────────────────────────────
          Positioned(
            top: 122,
            left: 16,
            child: _buildLayersDropdown(),
          ),

          if ((importedGeoJsonAsync.valueOrNull?.isNotEmpty ?? false))
            Positioned(
              top: 170,
              left: 16,
              child: _buildFocusGeoJsonButton(
                importedGeoJsonAsync.valueOrNull ?? const [],
              ),
            ),

          // ─── Leyenda ─────────────────────────────────────────────────────
          Positioned(
            left: 16,
            bottom: 16,
            child: _buildLegend(),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(
    List<Predio> predios,
    List<MunicipioLimite> municipios,
    List<GeoJsonPredioFeature> importedGeoJsonPredios,
  ) {
    const pkFilterEnabled = false;
    final filteredPredios = _applyAllFilters(predios);
    final filteredImportedGeoJson = _applyAllImportedFilters(importedGeoJsonPredios);
    _ensureImportedGeoJsonFocus(filteredImportedGeoJson);
    _ensureInitialFocus(predios, importedGeoJsonPredios);
    final polygons = <Polygon>[];
    final envolventePolygons = <Polygon>[];
    final importedPolygons = <Polygon>[];
    final envolventePolylines = <Polyline>[];
    final importedPolylines = <Polyline>[];
    final importedPkMarkers = <Marker>[];
    final importedGroupMarkers = <Marker>[];
    final sedatuLabelMarkers = <Marker>[];
    final municipalPolygons = <Polygon>[];
    final municipalPolylines = <Polyline>[];
    final predioGroupMarkers = <Marker>[];
    final bucketSize = _bucketSizeForZoom(_currentZoom);
    final bucketed = <String, _HeatBucket>{};
    final importedBucketed = <String, _HeatBucket>{};
    // Nueva jerarquía de capas y etiquetas por zoom
    final showContinentLabels = false;
    final showCountryBorders = false;
    final showCountryLabels = false;
    final showStateBorders = false;
    final showStateLabels = false;
    final showCityLabels = false;
    final showMetropolitanRoutes = false;
    final showStreetLabels = false;
    final showNeighborhoodLabels = false;
    final showExtremeDetailLabels = false;
    final showMunicipalBorders = _currentZoom >= 10;

    // Polígonos y límites
    bool shouldDrawPolygons() => _currentZoom >= 10;
    bool shouldDrawImportedGroups() =>
      _agruparMarcadores && bucketSize > 0;

    for (final p in filteredPredios) {
        final estatus = p.estatus?.trim().toLowerCase();
        final color = (estatus == 'liberado')
          ? const Color(0xFFCDDC39)
          : (_colorMode == _ColorMode.estado
            ? _colorEstado(p)
            : _colorTipo(p));

      final geo = p.geometry;
      LatLng? markerPoint;

      if (geo != null) {
        final polys = _extractPolygons(geo);
        if (shouldDrawPolygons()) {
          for (final coords in polys) {
            if (coords.isNotEmpty) {
              final drawCoords = _simplifyGeometryForZoom(
                coords,
                _currentZoom,
                isPolygon: true,
              );
              if (drawCoords.length < 3) continue;
              polygons.add(Polygon(
                points: drawCoords,
                color: color.withOpacity(0.35),
                borderColor: color.withOpacity(0.95),
                borderStrokeWidth: 3.6,
              ));
            }
          }
        }

        if (polys.isNotEmpty && polys.first.isNotEmpty) {
          markerPoint = _centroid(polys.first);
        }
      } else if (p.latitud != null && p.longitud != null) {
        markerPoint = LatLng(p.latitud!, p.longitud!);
      }

      if (markerPoint == null) continue;
      if (_mostrarEtiquetas) {
        final sedatuClave = p.claveCatastral.trim();
        if (sedatuClave.isNotEmpty) {
          sedatuLabelMarkers.add(
            _buildSedatuLabelMarker(markerPoint, sedatuClave),
          );
        }
      }
      if (_agruparMarcadores && bucketSize > 0) {
        final bucket = _putInBucket(bucketed, p, markerPoint, bucketSize);
        bucket.sample ??= p;
      }
    }

    if (_agruparMarcadores && bucketSize > 0) {
      final mergedBuckets =
          _mergeOverlappingBuckets(bucketed.values.toList(), bucketSize);
      for (final bucket in mergedBuckets) {
        predioGroupMarkers.add(_buildHeatMarker(bucket));
      }
    }

    for (final feature in filteredImportedGeoJson) {
      final isEnvelopeFeature = _isEnvelopeFeature(feature);
      final rings = _extractPolygons(feature.geometry);
      final lines = _extractPolylines(feature.geometry);
      LatLng? markerPoint = _extractRepresentativePoint(feature.geometry);
      final sourceAsset =
          (feature.properties['__source_asset'] ?? '').toString().toLowerCase();
      final isPkAsset = sourceAsset.endsWith('pks.geojson');
      final estatus = feature.estatus?.trim().toLowerCase();
        final fillColor = isEnvelopeFeature
          ? const Color(0xFF1976D2)
          : (estatus == 'liberado'
              ? const Color(0xFFCDDC39)
              : const Color(0xFFD32F2F));
      final borderColor = feature.esEstacion
          ? const Color(0xFFFFD54F)
          : fillColor.withOpacity(0.95);
      final polygonOpacity = _currentZoom >= 12 ? 0.35 : 0.18;
      final borderWidth = feature.esEstacion
          ? (_currentZoom >= 11 ? 3.4 : 2.2)
          : (_currentZoom >= 11 ? 3.0 : 1.6);

      for (final ring in rings) {
        if (ring.length < 3) continue;
        final drawRing = _simplifyGeometryForZoom(
          ring,
          _currentZoom,
          isPolygon: true,
        );
        if (drawRing.length < 3) continue;
        final targetPolygons = isEnvelopeFeature
            ? envolventePolygons
            : importedPolygons;
        targetPolygons.add(
          Polygon(
            points: drawRing,
            color: fillColor.withOpacity(polygonOpacity),
            borderColor: borderColor,
            borderStrokeWidth: borderWidth,
          ),
        );
        markerPoint ??= _centroid(ring);
      }

      for (final line in lines) {
        if (line.length < 2) continue;
        final drawLine = _simplifyGeometryForZoom(
          line,
          _currentZoom,
          isPolygon: false,
        );
        if (drawLine.length < 2) continue;
        final targetPolylines = isEnvelopeFeature
            ? envolventePolylines
            : importedPolylines;
        targetPolylines.add(
          Polyline(
            points: drawLine,
            strokeWidth: _currentZoom >= 11 ? 2.4 : 1.4,
            color: borderColor.withOpacity(0.92),
          ),
        );
        markerPoint ??= _centroid(line);
      }

      if (_mostrarEtiquetas && markerPoint != null && !isEnvelopeFeature) {
        final sedatuClave = _getClaveFromFeature(feature.properties);
        if (sedatuClave.isNotEmpty) {
          sedatuLabelMarkers.add(
            _buildSedatuLabelMarker(markerPoint, sedatuClave),
          );
        }
      }

      if (isPkAsset && pkFilterEnabled && _mostrarPks && markerPoint != null) {
        importedPkMarkers.add(
          _buildImportedFeatureMarker(feature, markerPoint, borderColor),
        );
        continue;
      }

      if (shouldDrawImportedGroups() && markerPoint != null && !isEnvelopeFeature) {
        final bucket = _putPointInCountBucket(importedBucketed, markerPoint, bucketSize);
        final estatusLower = feature.estatus?.trim().toLowerCase() ?? '';
        if (estatusLower == 'liberado') bucket.liberados++;
        if (estatusLower.contains('no liberado')) bucket.noLiberados++;
      }
    }

    if (shouldDrawImportedGroups()) {
      final mergedImportedBuckets =
          _mergeOverlappingBuckets(importedBucketed.values.toList(), bucketSize);
      for (final bucket in mergedImportedBuckets) {
        final clusterColor = bucket.liberados > bucket.noLiberados
            ? const Color(0xFF388E3C)
            : bucket.noLiberados > 0
                ? const Color(0xFFD32F2F)
                : const Color(0xFFF9A825);
        importedGroupMarkers.add(
          _buildCountMarker(bucket.center, bucket.count, clusterColor),
        );
      }
    }

    // Multi-municipio: resalta todos los seleccionados
    if (_selectedMunicipios.isNotEmpty) {
      for (final municipioSeleccionado in _selectedMunicipios) {
        if (municipioSeleccionado == 'Sin municipio') continue;
        final selectedKey = _normalizeMunicipioName(municipioSeleccionado);
        final selectedBoundaryPoints = <LatLng>[];
        for (final municipio in municipios.where(
          (m) => _normalizeMunicipioName(m.nombre) == selectedKey,
        )) {
          final rings = _extractPolygons(municipio.geometry);
          for (final ring in rings) {
            if (ring.length < 3) continue;
            selectedBoundaryPoints.addAll(ring);
            municipalPolygons.add(
              Polygon(
                points: ring,
                color: const Color(0xFF42A5F5).withOpacity(0.10),
                borderColor: Colors.transparent,
                borderStrokeWidth: 0,
              ),
            );
            municipalPolylines.add(
              Polyline(
                points: ring,
                strokeWidth: 6.0,
                color: Colors.white.withOpacity(0.55),
              ),
            );
            municipalPolylines.add(
              Polyline(
                points: ring,
                strokeWidth: 2.6,
                color: const Color(0xFF0D47A1).withOpacity(0.98),
              ),
            );
          }
        }
        _focusSelectedMunicipioBoundary(selectedKey, selectedBoundaryPoints);
      }
    } else {
      _lastFocusedMunicipioKey = null;
    }

    // Icono de ubicación para el feature GeoJSON seleccionado
    final selectedFeaturePin = <Marker>[];
    if (_selectedImportedFeature != null) {
      final rings = _extractPolygons(_selectedImportedFeature!.geometry);
      LatLng? pinPos;
      if (rings.isNotEmpty && rings.first.isNotEmpty) {
        pinPos = _centroid(rings.first);
      } else {
        final lines = _extractPolylines(_selectedImportedFeature!.geometry);
        if (lines.isNotEmpty) pinPos = _centroid(lines.first);
      }
      if (pinPos != null) {
        selectedFeaturePin.add(Marker(
          point: pinPos,
          width: 40,
          height: 44,
          child: const Icon(
            Icons.location_on,
            color: Color(0xFFFF5722),
            size: 38,
          ),
        ));
      }
    }

    return FlutterMap(
      mapController: _mapCtrl,
      options: MapOptions(
        initialCenter: _defaultCenter,
        initialZoom: _defaultZoom,
        onTap: (_, point) {
          final tappedPredio = _findPredioAtPoint(point, filteredPredios);
          final nonEnvolventes =
              filteredImportedGeoJson.where((f) => !_isEnvelopeFeature(f)).toList();
          final tappedImported = _findImportedFeatureAtPoint(point, nonEnvolventes);
          setState(() {
            // Muestra solo una ficha: prioriza la última ficha implementada
            // (GeoJSON importado) cuando ambos elementos se traslapan.
            if (tappedImported != null) {
              _selectedImportedFeature = tappedImported;
              _selectedPredio = null;
            } else {
              _selectedPredio = tappedPredio;
              _selectedImportedFeature = null;
            }
          });
        },
        onPositionChanged: (position, hasGesture) {
          final nextZoom = position.zoom ?? _currentZoom;
          final nextStep = (nextZoom * 2).round();
          if (nextStep != _zoomRenderStep) {
            setState(() {
              _currentZoom = nextZoom;
              _zoomRenderStep = nextStep;
            });
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: _getTileUrl(),
          userAgentPackageName: 'mx.sao.geoportal_consulta',
          maxZoom: 23,
        ),
        // Nivel 0-3: Vista global, nombres de continentes/planeta (solo base, sin overlays)
        // Nivel 4-9: Países, estados, grandes cadenas montañosas y sus nombres
        // Envolventes al fondo de todas las capas vectoriales.
        if (envolventePolygons.isNotEmpty)
          PolygonLayer(polygons: envolventePolygons),
        if (envolventePolylines.isNotEmpty)
          PolylineLayer(polylines: envolventePolylines),
        if (showCountryBorders)
          TileLayer(
            urlTemplate: 'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
            userAgentPackageName: 'mx.sao.geoportal_consulta',
            maxZoom: 23,
          ),
        if (showStateBorders)
          TileLayer(
            urlTemplate: 'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Administrative_Boundaries/MapServer/tile/{z}/{y}/{x}',
            userAgentPackageName: 'mx.sao.geoportal_consulta',
            maxZoom: 23,
          ),
        // Nivel 10-14: Ciudades, áreas metropolitanas, rutas, avenidas principales y nombres
        if (showMunicipalBorders && municipalPolygons.isNotEmpty)
          PolygonLayer(polygons: municipalPolygons),
        if (showMunicipalBorders && municipalPolylines.isNotEmpty)
          PolylineLayer(polylines: municipalPolylines),
        if (showMunicipalBorders && polygons.isNotEmpty)
          PolygonLayer(polygons: polygons),
        // Capas importadas SIEMPRE visibles
        if (importedPolygons.isNotEmpty)
          PolygonLayer(polygons: importedPolygons),
        if (importedPolylines.isNotEmpty)
          PolylineLayer(polylines: importedPolylines),
        if (_agruparMarcadores && importedGroupMarkers.isNotEmpty)
          MarkerLayer(markers: importedGroupMarkers),
        if (_agruparMarcadores && predioGroupMarkers.isNotEmpty)
          MarkerLayer(markers: predioGroupMarkers),
        if (pkFilterEnabled && _mostrarPks && importedPkMarkers.isNotEmpty)
          MarkerLayer(markers: importedPkMarkers),
        // Nivel 15-17: Calles, vecindarios, colonias, parques y nombres
        if (showStreetLabels)
          TileLayer(
            urlTemplate: 'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Transportation/MapServer/tile/{z}/{y}/{x}',
            userAgentPackageName: 'mx.sao.geoportal_consulta',
            maxZoom: 23,
          ),
        if (showNeighborhoodLabels)
          TileLayer(
            urlTemplate: 'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
            userAgentPackageName: 'mx.sao.geoportal_consulta',
            maxZoom: 23,
          ),
        // Nivel 18-23: Detalle extremo, edificios, manzanas, entradas y nombres
        if (showExtremeDetailLabels)
          TileLayer(
            urlTemplate: 'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Transportation/MapServer/tile/{z}/{y}/{x}',
            userAgentPackageName: 'mx.sao.geoportal_consulta',
            maxZoom: 23,
          ),
        if (_mostrarEtiquetas && sedatuLabelMarkers.isNotEmpty)
          MarkerLayer(markers: sedatuLabelMarkers),
        if (pkFilterEnabled && _mostrarPks && selectedFeaturePin.isNotEmpty)
          MarkerLayer(markers: selectedFeaturePin),
      ],
    );
  }

  LatLng? _markerPointForPredio(Predio p) {
    if (p.geometry != null) {
      final polys = _extractPolygons(p.geometry!);
      if (polys.isNotEmpty && polys.first.isNotEmpty) {
        return _centroid(polys.first);
      }
    }
    if (p.latitud != null && p.longitud != null) {
      return LatLng(p.latitud!, p.longitud!);
    }
    return null;
  }

  Predio? _findPredioAtPoint(LatLng point, List<Predio> predios) {
    for (final p in predios.reversed) {
      final geo = p.geometry;
      if (geo == null) continue;
      final polys = _extractPolygons(geo);
      for (final ring in polys) {
        if (ring.length < 3) continue;
        if (_isPointInPolygon(point, ring)) {
          return p;
        }
      }
    }
    return null;
  }

  GeoJsonPredioFeature? _findImportedFeatureAtPoint(
    LatLng point,
    List<GeoJsonPredioFeature> features,
  ) {
    for (final feature in features.reversed) {
      final polys = _extractPolygons(feature.geometry);
      for (final ring in polys) {
        if (ring.length < 3) continue;
        if (_isPointInPolygon(point, ring)) {
          return feature;
        }
      }
    }
    return null;
  }

  bool _isPointInPolygon(LatLng point, List<LatLng> ring) {
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

  void _focusSelectedMunicipioBoundary(
    String municipioKey,
    List<LatLng> boundaryPoints,
  ) {
    if (boundaryPoints.isEmpty) return;
    if (_lastFocusedMunicipioKey == municipioKey) return;
    _lastFocusedMunicipioKey = municipioKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapCtrl.fitCamera(
        CameraFit.coordinates(
          coordinates: boundaryPoints,
          padding: const EdgeInsets.fromLTRB(40, 140, 40, 40),
        ),
      );
    });
  }

  Marker _buildHeatMarker(_HeatBucket bucket) {
    final color = _heatColor(bucket);
    return _buildCountMarker(bucket.center, bucket.count, color);
  }

  Marker _buildCountMarker(LatLng center, int count, Color color) {
    final size = count >= 25
        ? 50.0
        : count >= 10
            ? 42.0
            : 36.0;
    return Marker(
      point: center,
      width: size,
      height: size,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          '$count',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: count >= 100 ? 11 : 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  _HeatBucket _putInBucket(
    Map<String, _HeatBucket> buckets,
    Predio p,
    LatLng point,
    double bucketSize,
  ) {
    final latIdx = (point.latitude / bucketSize).floor();
    final lngIdx = (point.longitude / bucketSize).floor();
    final key = '$latIdx:$lngIdx';

    final existing = buckets[key];
    if (existing == null) {
      final seed = _HeatBucket(center: point, count: 1);
      if (_isLiberado(p)) seed.liberados = 1;
      if (_isNoLiberado(p)) seed.noLiberados = 1;
      buckets[key] = seed;
      return seed;
    }

    final nextCount = existing.count + 1;
    existing.center = LatLng(
      ((existing.center.latitude * existing.count) + point.latitude) / nextCount,
      ((existing.center.longitude * existing.count) + point.longitude) /
          nextCount,
    );
    existing.count = nextCount;
    if (_isLiberado(p)) existing.liberados++;
    if (_isNoLiberado(p)) existing.noLiberados++;
    return existing;
  }

  _HeatBucket _putPointInCountBucket(
    Map<String, _HeatBucket> buckets,
    LatLng point,
    double bucketSize,
  ) {
    final latIdx = (point.latitude / bucketSize).floor();
    final lngIdx = (point.longitude / bucketSize).floor();
    final key = '$latIdx:$lngIdx';

    final existing = buckets[key];
    if (existing == null) {
      final seed = _HeatBucket(center: point, count: 1);
      buckets[key] = seed;
      return seed;
    }

    final nextCount = existing.count + 1;
    existing.center = LatLng(
      ((existing.center.latitude * existing.count) + point.latitude) / nextCount,
      ((existing.center.longitude * existing.count) + point.longitude) /
          nextCount,
    );
    existing.count = nextCount;
    return existing;
  }

  List<_HeatBucket> _mergeOverlappingBuckets(
    List<_HeatBucket> buckets,
    double bucketSize,
  ) {
    // Evitar costo O(n^2) en zoom lejano con muchos grupos.
    if (buckets.length > 220) return buckets;
    if (buckets.length <= 1) return buckets;

    final pending = [...buckets]..sort((a, b) => b.count.compareTo(a.count));
    final merged = <_HeatBucket>[];
    final mergeThreshold = bucketSize * 0.85;

    while (pending.isNotEmpty) {
      final base = pending.removeAt(0);
      int i = 0;
      while (i < pending.length) {
        final candidate = pending[i];
        final distance = _distanceBetweenPoints(base.center, candidate.center);
        if (distance <= mergeThreshold) {
          final total = base.count + candidate.count;
          base.center = LatLng(
            ((base.center.latitude * base.count) +
                    (candidate.center.latitude * candidate.count)) /
                total,
            ((base.center.longitude * base.count) +
                    (candidate.center.longitude * candidate.count)) /
                total,
          );
          base.count = total;
          base.liberados += candidate.liberados;
          base.noLiberados += candidate.noLiberados;
          base.sample ??= candidate.sample;
          pending.removeAt(i);
          continue;
        }
        i++;
      }
      merged.add(base);
    }

    return merged;
  }

  double _distanceBetweenPoints(LatLng a, LatLng b) {
    final avgLatRad = ((a.latitude + b.latitude) / 2) * (math.pi / 180);
    final latDelta = (a.latitude - b.latitude).abs();
    final lngDelta =
        ((a.longitude - b.longitude).abs() * math.cos(avgLatRad)).abs();
    return math.sqrt((latDelta * latDelta) + (lngDelta * lngDelta));
  }

  Marker _buildMarker(Predio p, LatLng pos, Color color) {
    final pkLabel = _pkLabelFromPredio(p);
    return Marker(
      point: pos,
      width: 112,
      height: 44,
      child: GestureDetector(
        onTap: () => setState(() => _selectedPredio = p),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.location_on, color: Colors.white, size: 15),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: color.withOpacity(0.75), width: 1.2),
                ),
                child: Text(
                  pkLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF17332A),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Marker _buildImportedFeatureMarker(
    GeoJsonPredioFeature feature,
    LatLng pos,
    Color color,
  ) {
    final pkLabel = _pkLabelFromImportedFeature(feature.properties);
    return Marker(
      point: pos,
      width: 128,
      height: 40,
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedImportedFeature = feature;
          _selectedPredio = null;
        }),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: color.withOpacity(0.92),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.22),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(Icons.place, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: color.withOpacity(0.75), width: 1.1),
                ),
                child: Text(
                  pkLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF17332A),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Marker _buildSedatuLabelMarker(LatLng pos, String claveSedatu) {
    return Marker(
      point: pos,
      width: 120,
      height: 24,
      alignment: Alignment.topCenter,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xE6FFFDE7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF6D4C41), width: 1),
          ),
          child: Text(
            claveSedatu,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF3E2723),
            ),
          ),
        ),
      ),
    );
  }

  String _pkLabelFromPredio(Predio p) {
    final start = p.kmInicio;
    final end = p.kmFin;
    if (start != null && end != null) {
      return 'PK ${_kmFmt(start)}-${_kmFmt(end)}';
    }
    if (start != null) return 'PK ${_kmFmt(start)}';
    if (end != null) return 'PK ${_kmFmt(end)}';
    return 'PK s/d';
  }

  String _pkLabelFromImportedFeature(Map<String, dynamic> properties) {
    final cadenamiento = _extractPropertyByKeyFragments(
      properties,
      ['CADEN'],
      fallbackFragments: ['PK'],
    );
    final cleanCadenamiento = cadenamiento.trim();
    if (cleanCadenamiento.isNotEmpty) {
      return cleanCadenamiento.toUpperCase().startsWith('PK')
          ? cleanCadenamiento
          : 'PK $cleanCadenamiento';
    }

    final kmInicio = _getKmInicioFromFeature(properties).trim();
    final kmFin = _getKmFinFromFeature(properties).trim();
    if (kmInicio.isNotEmpty && kmFin.isNotEmpty) {
      return 'PK $kmInicio-$kmFin';
    }
    if (kmInicio.isNotEmpty) return 'PK $kmInicio';
    if (kmFin.isNotEmpty) return 'PK $kmFin';
    return 'PK s/d';
  }

  Widget _buildTopBar(
    List<Predio> predios,
    List<MunicipioLimite> municipios,
    [List<GeoJsonPredioFeature> importedFeatures = const []]
  ) {
    final prediosOperative = predios.where((p) => !_isEnvolventePredio(p)).toList();
    final importedOperative = importedFeatures
      .where((f) => !_isEnvelopeFeature(f) && !f.esEstacion)
      .toList();
    final liberacionFiltered = _applyLiberacionFilter(prediosOperative);
    final filteredPredios = _applyAllFilters(prediosOperative);
    final tipoProyectoCounts = countByFieldUnified(
      predios: prediosOperative,
      imported: importedOperative,
      predioSelector: (p) => _tipoProyectoLabel(p.proyecto),
      importedSelector: (props) => _tipoProyectoLabel(props['PROYECTO']?.toString()),
      emptyLabel: 'Sin proyecto',
    );
    final allMunicipioCounts = countByFieldUnified(
      predios: prediosOperative,
      imported: importedOperative,
      predioSelector: (p) => (p.municipio ?? p.ejido ?? ''),
      importedSelector: (props) => _getMunicipioFromFeature(props),
      emptyLabel: 'Sin municipio',
    );
    final clasificaCounts = countByFieldUnified(
      predios: prediosOperative,
      imported: importedOperative,
      predioSelector: (p) {
        final tipo = p.tipoPropiedad.toUpperCase().trim();
        if (tipo == 'SOCIAL') return 'Pública';
        if (tipo == 'PRIVADA') return 'Privada';
        return 'Sin clasificación';
      },
      importedSelector: (props) => _getTipoPropiedadFromFeature(props),
      emptyLabel: 'Sin clasificación',
    );
    final segmentoCounts = countByFieldUnified(
      predios: prediosOperative,
      imported: importedOperative,
      predioSelector: (p) => _extractSegmentNumber(p.tramo),
      importedSelector: (props) => _extractSegmentNumber(_getSegmentoFromFeature(props)),
      emptyLabel: 'Sin segmento',
    );
    final estatusCounts = <String, int>{
      'Todos': prediosOperative.length + importedOperative.length,
      'Liberados': prediosOperative.where(_isLiberado).length + importedOperative.where(_isImportedLiberado).length,
      'No liberados': prediosOperative.where(_isNoLiberado).length + importedOperative.where(_isImportedNoLiberado).length,
    };
    return Container(
      height: 112,
      decoration: BoxDecoration(
        color: const Color(0xFF1B4332),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.map_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Geoportal de Consulta',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Vista única: todos los proyectos',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                _ColorModeToggle(
                  mode: _colorMode,
                  onChanged: (m) => setState(() => _colorMode = m),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: _lastRefresh == null
                      ? 'Recargar predios'
                      : 'Última actualización: ${DateFormat('HH:mm:ss').format(_lastRefresh!)}\nToca para recargar',
                  child: InkWell(
                    onTap: _recargar,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isRefreshing
                            ? Colors.white.withOpacity(0.25)
                            : Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RotationTransition(
                            turns: _spinCtrl,
                            child: const Icon(
                              Icons.refresh_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          if (_lastRefresh != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              DateFormat('HH:mm').format(_lastRefresh!),
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () {
                    ref.read(sesionActivaProvider.notifier).state = false;
                    context.go('/login');
                  },
                  icon: const Icon(Icons.logout, color: Colors.white70, size: 18),
                  label: Text(
                    'Salir',
                    style:
                        GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _quickToggleChip(
                            label: 'Agrupación',
                            isOn: _agruparMarcadores,
                            icon: Icons.bubble_chart_rounded,
                            onTap: () => setState(() {
                              _agruparMarcadores = !_agruparMarcadores;
                            }),
                          ),
                          const SizedBox(width: 8),
                          _quickToggleChip(
                            label: 'Etiquetas',
                            isOn: _mostrarEtiquetas,
                            icon: Icons.sell_outlined,
                            onTap: () => setState(() => _mostrarEtiquetas = !_mostrarEtiquetas),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => _openAdvancedFiltersPanel(
                              predios,
                              importedFeatures,
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withOpacity(0.45)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.tune_rounded, size: 14),
                            label: Text(
                              _segmentoQueries.isEmpty &&
                                      _selectedEstatus.isEmpty &&
                                      _selectedEjidos.isEmpty &&
                                      _selectedClasificaciones.isEmpty &&
                                      _selectedMunicipios.isEmpty &&
                                      _liberacionFilter == _LiberacionFilter.todos &&
                                      !_filterSoloEstaciones
                                  ? 'Filtros avanzados'
                                  : 'Filtros avanzados *',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickToggleChip({
    required String label,
    required bool isOn,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final onColor = const Color(0xFFD4AF37);
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(
          color: isOn ? onColor : Colors.white.withOpacity(0.35),
          width: isOn ? 1.6 : 1,
        ),
        backgroundColor: isOn ? onColor.withOpacity(0.16) : Colors.white.withOpacity(0.04),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      icon: Icon(icon, size: 16),
      label: Text(
        '$label ${isOn ? 'ON' : 'OFF'}',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _openAdvancedFiltersPanel(
    List<Predio> predios,
    List<GeoJsonPredioFeature> importedFeatures,
  ) async {
    final prediosOperative = predios.where((p) => !_isEnvolventePredio(p)).toList();
    final importedOperative = importedFeatures
      .where((f) => !_isEnvelopeFeature(f) && !f.esEstacion)
      .toList();
    final estacionesCount = importedFeatures.where((f) => f.esEstacion).length;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar filtros avanzados',
      barrierColor: Colors.black45,
      pageBuilder: (dialogContext, __, ___) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Map<String, int> sanitizeCounts(Map<String, int> source) {
              final cleaned = <String, int>{};
              source.forEach((k, v) {
                if (k.trim().isEmpty || v <= 0) return;
                cleaned[k] = v;
              });
              return cleaned;
            }

            String clasificacionPredio(Predio p) {
              final tipo = p.tipoPropiedad.toUpperCase().trim();
              if (tipo == 'SOCIAL') return 'Pública';
              if (tipo == 'PRIVADA') return 'Privada';
              return 'Sin clasificación';
            }

            String ejidoImported(Map<String, dynamic> props) {
              return _getEjidoFromFeature(props);
            }

            Map<String, int> buildDynamicCounts(
              List<Predio> prediosBase,
              List<GeoJsonPredioFeature> importedBase,
              String Function(Predio) predioSelector,
              String Function(Map<String, dynamic>) importedSelector, {
              required String emptyLabel,
            }) {
              final counts = countByFieldUnified(
                predios: prediosBase,
                imported: importedBase,
                predioSelector: predioSelector,
                importedSelector: importedSelector,
                emptyLabel: emptyLabel,
              );
              return sanitizeCounts(counts);
            }

            void sanitizeSelections({
              required Map<String, int> tipoProyectoCounts,
              required Map<String, int> estatusCounts,
              required Map<String, int> segmentoCounts,
              required Map<String, int> ejidoCounts,
              required Map<String, int> municipioCounts,
              required Map<String, int> clasificaCounts,
            }) {
              _selectedTipoProyectos.removeWhere((v) => !tipoProyectoCounts.containsKey(v));
              _selectedEstatus.removeWhere((v) => !estatusCounts.containsKey(v));
              _segmentoQueries.removeWhere((v) => !segmentoCounts.containsKey(v));
              _selectedEjidos.removeWhere((v) => !ejidoCounts.containsKey(v));
              _selectedMunicipios.removeWhere((v) => !municipioCounts.containsKey(v));
              _selectedClasificaciones.removeWhere((v) => !clasificaCounts.containsKey(v));
            }

            List<Predio> prediosForCascade({
              bool applyTipoProyecto = false,
              bool applyEstatus = false,
              bool applySegmento = false,
              bool applyEjido = false,
              bool applyMunicipio = false,
              bool applyClasificacion = false,
            }) {
              if (_filterSoloEstaciones) return const [];
              var filtered = _applyLiberacionFilter(prediosOperative);

              if (applyTipoProyecto && _selectedTipoProyectos.isNotEmpty) {
                filtered = filtered.where((p) {
                  final label = _tipoProyectoLabel(p.proyecto);
                  return _selectedTipoProyectos.contains(label);
                }).toList();
              }
              if (applyEstatus && _selectedEstatus.isNotEmpty) {
                final selectedEstatusKeys =
                    _selectedEstatus.map(_normalizeEstatusFilterLabel).toSet();
                filtered = filtered.where((p) {
                  final estatusKey =
                      _normalizeEstatusFilterLabel(_estatusFilterLabelFromPredio(p));
                  return selectedEstatusKeys.contains(estatusKey);
                }).toList();
              }
              if (applySegmento && _segmentoQueries.isNotEmpty) {
                filtered = filtered.where((p) => _matchesSegmentQuery(p.tramo)).toList();
              }
              if (applyEjido && _selectedEjidos.isNotEmpty) {
                filtered = filtered.where((p) {
                  final key = _normalizeFilterDimensionValue(
                    p.ejido ?? '',
                    emptyLabel: 'Sin ejido',
                  );
                  return _selectedEjidos.contains(key);
                }).toList();
              }
              if (applyMunicipio && _selectedMunicipios.isNotEmpty) {
                filtered = filtered.where((p) {
                  final value = (p.municipio ?? p.ejido ?? '').trim();
                  if (_selectedMunicipios.contains('Sin municipio') && value.isEmpty) {
                    return true;
                  }
                  if (value.isEmpty) return false;
                  final normalized = _normalizeMunicipioName(value);
                  return _selectedMunicipios
                      .any((m) => _normalizeMunicipioName(m) == normalized);
                }).toList();
              }
              if (applyClasificacion && _selectedClasificaciones.isNotEmpty) {
                filtered = filtered.where((p) {
                  final tipo = p.tipoPropiedad.toUpperCase().trim();
                  final clasificacion = tipo == 'SOCIAL'
                      ? 'Pública'
                      : (tipo == 'PRIVADA' ? 'Privada' : 'Sin clasificación');
                  return _selectedClasificaciones.contains(clasificacion);
                }).toList();
              }
              return filtered;
            }

            List<GeoJsonPredioFeature> importedForCascade({
              bool applyTipoProyecto = false,
              bool applyEstatus = false,
              bool applySegmento = false,
              bool applyEjido = false,
              bool applyMunicipio = false,
              bool applyClasificacion = false,
            }) {
              var filtered = importedOperative;

              if (_liberacionFilter != _LiberacionFilter.todos) {
                filtered = filtered.where((feature) {
                  if (_liberacionFilter == _LiberacionFilter.liberados) {
                    return _isImportedLiberado(feature);
                  }
                  return _isImportedNoLiberado(feature);
                }).toList();
              }

              if (applyTipoProyecto && _selectedTipoProyectos.isNotEmpty) {
                filtered = filtered.where((feature) {
                  final label =
                      _tipoProyectoLabel(feature.properties['PROYECTO']?.toString());
                  return _selectedTipoProyectos.contains(label);
                }).toList();
              }
              if (applyEstatus && _selectedEstatus.isNotEmpty) {
                final selectedEstatusKeys =
                    _selectedEstatus.map(_normalizeEstatusFilterLabel).toSet();
                filtered = filtered.where((feature) {
                  final estatusKey = _normalizeEstatusFilterLabel(
                    _estatusFilterLabelFromProperties(feature.properties),
                  );
                  return selectedEstatusKeys.contains(estatusKey);
                }).toList();
              }
              if (applySegmento && _segmentoQueries.isNotEmpty) {
                filtered = filtered.where((feature) {
                  return _matchesSegmentQuery(
                    _getSegmentoFromFeature(feature.properties),
                  );
                }).toList();
              }
              if (applyEjido && _selectedEjidos.isNotEmpty) {
                filtered = filtered.where((feature) {
                  final key = _getEjidoFromFeature(feature.properties).trim();
                  return _selectedEjidos.contains(key);
                }).toList();
              }
              if (applyMunicipio && _selectedMunicipios.isNotEmpty) {
                filtered = filtered.where((feature) {
                  final value = _getMunicipioFromFeature(feature.properties).trim();
                  if (_selectedMunicipios.contains('Sin municipio') && value.isEmpty) {
                    return true;
                  }
                  if (value.isEmpty) return false;
                  final normalized = _normalizeMunicipioName(value);
                  return _selectedMunicipios
                      .any((m) => _normalizeMunicipioName(m) == normalized);
                }).toList();
              }
              if (applyClasificacion && _selectedClasificaciones.isNotEmpty) {
                filtered = filtered.where((feature) {
                  final clasificacion = _getTipoPropiedadFromFeature(feature.properties);
                  final label =
                      clasificacion.isEmpty ? 'Sin clasificación' : clasificacion;
                  return _selectedClasificaciones.contains(label);
                }).toList();
              }

              return filtered;
            }

            final tipoProyectoCounts = buildDynamicCounts(
              prediosForCascade(),
              importedForCascade(),
              (p) => _tipoProyectoLabel(p.proyecto),
              (props) => _tipoProyectoLabel(props['PROYECTO']?.toString()),
              emptyLabel: 'Sin proyecto',
            );
            final estatusCounts = buildDynamicCounts(
              prediosForCascade(applyTipoProyecto: true),
              importedForCascade(applyTipoProyecto: true),
              (p) => _estatusFilterLabelFromPredio(p),
              (props) => _estatusFilterLabelFromProperties(props),
              emptyLabel: 'Sin estatus',
            );
            final segmentoCounts = buildDynamicCounts(
              prediosForCascade(applyTipoProyecto: true, applyEstatus: true),
              importedForCascade(applyTipoProyecto: true, applyEstatus: true),
              (p) => _extractSegmentNumber(p.tramo),
              (props) => _extractSegmentNumber(_getSegmentoFromFeature(props)),
              emptyLabel: 'Sin segmento',
            );
            final ejidoCounts = buildDynamicCounts(
              prediosForCascade(
                applyTipoProyecto: true,
                applyEstatus: true,
                applySegmento: true,
              ),
              importedForCascade(
                applyTipoProyecto: true,
                applyEstatus: true,
                applySegmento: true,
              ),
              (p) => _normalizeFilterDimensionValue(
                p.ejido ?? '',
                emptyLabel: 'Sin ejido',
              ),
              ejidoImported,
              emptyLabel: 'Sin ejido',
            );
            final municipioCounts = buildDynamicCounts(
              prediosForCascade(
                applyTipoProyecto: true,
                applyEstatus: true,
                applySegmento: true,
                applyEjido: true,
              ),
              importedForCascade(
                applyTipoProyecto: true,
                applyEstatus: true,
                applySegmento: true,
                applyEjido: true,
              ),
              (p) => (p.municipio ?? ''),
              (props) => _getMunicipioFromFeature(props),
              emptyLabel: 'Sin municipio',
            );
            final clasificaCounts = buildDynamicCounts(
              prediosForCascade(
                applyTipoProyecto: true,
                applyEstatus: true,
                applySegmento: true,
                applyEjido: true,
                applyMunicipio: true,
              ),
              importedForCascade(
                applyTipoProyecto: true,
                applyEstatus: true,
                applySegmento: true,
                applyEjido: true,
                applyMunicipio: true,
              ),
              clasificacionPredio,
              (props) => _getTipoPropiedadFromFeature(props),
              emptyLabel: 'Sin clasificación',
            );

            sanitizeSelections(
              tipoProyectoCounts: tipoProyectoCounts,
              estatusCounts: estatusCounts,
              segmentoCounts: segmentoCounts,
              ejidoCounts: ejidoCounts,
              municipioCounts: municipioCounts,
              clasificaCounts: clasificaCounts,
            );

            void updateFilters(VoidCallback changes) {
              if (!mounted) return;
              setState(changes);
              setModalState(() {});
            }

            return SafeArea(
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: 360,
                  height: double.infinity,
                  color: const Color(0xFF123529),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: DefaultTextStyle.merge(
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        decoration: TextDecoration.none,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Filtros avanzados',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => Navigator.of(dialogContext).pop(),
                                icon: const Icon(Icons.close, color: Colors.white70),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _countSectionMulti(
                                    title: 'Tipo de proyecto',
                                    counts: tipoProyectoCounts,
                                    selectedLabels: _selectedTipoProyectos,
                                    onChipTap: (tipo) {
                                      updateFilters(() {
                                        if (_selectedTipoProyectos.contains(tipo)) {
                                          _selectedTipoProyectos.remove(tipo);
                                        } else {
                                          _selectedTipoProyectos.add(tipo);
                                        }
                                        _selectedPredio = null;
                                        _selectedImportedFeature = null;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _countSectionMulti(
                                    title: 'Estatus',
                                    counts: estatusCounts,
                                    selectedLabels: _selectedEstatus,
                                    onChipTap: (estatus) {
                                      updateFilters(() {
                                        if (_selectedEstatus.contains(estatus)) {
                                          _selectedEstatus.remove(estatus);
                                        } else {
                                          _selectedEstatus.add(estatus);
                                        }
                                        _selectedPredio = null;
                                        _selectedImportedFeature = null;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _countSectionMulti(
                                    title: 'Segmentos',
                                    counts: segmentoCounts,
                                    selectedLabels: _segmentoQueries,
                                    onChipTap: (segmento) {
                                      updateFilters(() {
                                        if (_segmentoQueries.contains(segmento)) {
                                          _segmentoQueries.remove(segmento);
                                        } else {
                                          _segmentoQueries.add(segmento);
                                        }
                                        _selectedPredio = null;
                                        _selectedImportedFeature = null;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _countSectionMulti(
                                    title: 'Ejidos',
                                    counts: ejidoCounts,
                                    selectedLabels: _selectedEjidos,
                                    onChipTap: (ejido) {
                                      updateFilters(() {
                                        if (_selectedEjidos.contains(ejido)) {
                                          _selectedEjidos.remove(ejido);
                                        } else {
                                          _selectedEjidos.add(ejido);
                                        }
                                        _selectedPredio = null;
                                        _selectedImportedFeature = null;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _countSectionMulti(
                                    title: 'Municipios',
                                    counts: municipioCounts,
                                    selectedLabels: _selectedMunicipios,
                                    onChipTap: (municipio) {
                                      updateFilters(() {
                                        if (_selectedMunicipios.contains(municipio)) {
                                          _selectedMunicipios.remove(municipio);
                                        } else {
                                          _selectedMunicipios.add(municipio);
                                        }
                                        _lastFocusedMunicipioKey = null;
                                        _selectedPredio = null;
                                        _selectedImportedFeature = null;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _countSectionMulti(
                                    title: 'Clasificación',
                                    counts: clasificaCounts,
                                    selectedLabels: _selectedClasificaciones,
                                    onChipTap: (clasificacion) {
                                      updateFilters(() {
                                        if (_selectedClasificaciones.contains(clasificacion)) {
                                          _selectedClasificaciones.remove(clasificacion);
                                        } else {
                                          _selectedClasificaciones.add(clasificacion);
                                        }
                                        _selectedPredio = null;
                                        _selectedImportedFeature = null;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Solo Estaciones',
                                            style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            '$estacionesCount estaciones disponibles',
                                            style: GoogleFonts.inter(
                                              color: Colors.white54,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      Switch.adaptive(
                                        value: _filterSoloEstaciones,
                                        onChanged: (v) => updateFilters(() {
                                          _filterSoloEstaciones = v;
                                          _selectedPredio = null;
                                          _selectedImportedFeature = null;
                                        }),
                                        activeColor: const Color(0xFFFFD54F),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => updateFilters(() {
                                    _liberacionFilter = _LiberacionFilter.todos;
                                    _segmentoQueries.clear();
                                    _selectedTipoProyectos.clear();
                                    _selectedEstatus.clear();
                                    _selectedEjidos.clear();
                                    _selectedClasificaciones.clear();
                                    _selectedMunicipios.clear();
                                    _selectedPredio = null;
                                    _selectedImportedFeature = null;
                                    _lastFocusedMunicipioKey = null;
                                    _filterSoloEstaciones = false;
                                  }),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                        color: Colors.white.withOpacity(0.45)),
                                  ),
                                  child: const Text('Limpiar'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => Navigator.of(dialogContext).pop(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2E7D32),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Aplicar'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_applyAllFilters(prediosOperative).length} predios visibles',
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _liberacionFilterLabel(_LiberacionFilter filter) {
    switch (filter) {
      case _LiberacionFilter.todos:
        return 'Todos';
      case _LiberacionFilter.liberados:
        return 'Liberados';
      case _LiberacionFilter.noLiberados:
        return 'No liberados';
    }
  }

  _LiberacionFilter _liberacionFilterFromLabel(String label) {
    switch (label) {
      case 'Liberados':
        return _LiberacionFilter.liberados;
      case 'No liberados':
        return _LiberacionFilter.noLiberados;
      default:
        return _LiberacionFilter.todos;
    }
  }

  Map<String, int> _countByField(
    List<Predio> predios,
    String? Function(Predio predio) fieldSelector, {
    String emptyLabel = 'Sin dato',
  }) {
    final counts = <String, int>{};
    for (final predio in predios) {
      final raw = fieldSelector(predio)?.trim();
      final key = (raw == null || raw.isEmpty) ? emptyLabel : raw;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  Widget _countSection({
    required String title,
    required Map<String, int> counts,
    String? selectedLabel,
    ValueChanged<String>? onChipTap,
  }) {
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: sorted
              .map(
                (entry) => _countChip(
                  entry.key,
                  entry.value,
                  active: selectedLabel == entry.key,
                  onTap: onChipTap == null
                      ? null
                      : () => onChipTap(entry.key),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _countChip(
    String label,
    int count, {
    bool active = false,
    VoidCallback? onTap,
  }) {
    final borderRadius = BorderRadius.circular(12);
    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: active
                ? Colors.white.withOpacity(0.95)
                : Colors.white.withOpacity(0.16),
            borderRadius: borderRadius,
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: Text(
            '$label ($count)',
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: active ? const Color(0xFF1B4332) : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withOpacity(0.95)
              : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.4)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: active ? const Color(0xFF1B4332) : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
  Widget _buildDetailPanel(Predio predio) {
    final isTapPredio = _tipoProyectoLabel(predio.proyecto) == 'TAP';
    final forceGreenGestion = isTapPredio && _isLiberado(predio);
    final gestionIdentificacion = forceGreenGestion || predio.identificacion;
    final gestionLevantamiento = forceGreenGestion || predio.levantamiento;
    final gestionCop = forceGreenGestion || predio.cop;
    final gestionNegociacion = forceGreenGestion || predio.negociacion;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera del panel
          Container(
            color: const Color(0xFF1B4332),
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    predio.claveCatastral,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => setState(() => _selectedPredio = null),
                ),
              ],
            ),
          ),
          // Contenido
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow(
                    'Segmento',
                    _extractSegmentNumber(predio.tramo).isEmpty
                        ? predio.tramo
                        : _extractSegmentNumber(predio.tramo),
                  ),
                  _infoRow('Propiedad', _propertyLabel(predio.tipoPropiedad)),
                  if (predio.ejido != null)
                    _infoRow('Ejido / Localidad', predio.ejido!),
                  if (predio.kmInicio != null)
                    _infoRow('Km inicio', _kmFmt(predio.kmInicio!)),
                  if (predio.kmFin != null)
                    _infoRow('Km fin', _kmFmt(predio.kmFin!)),
                  if (predio.superficie != null)
                    _infoRow(
                        'Superficie',
                        NumberFormat('#,##0.00', 'es_MX')
                                .format(predio.superficie!) +
                            ' m²'),
                  const Divider(height: 24),
                  _sectionTitle('Estado de gestión'),
                  const SizedBox(height: 8),
                  _estadoChip('Identificación', gestionIdentificacion),
                  _estadoChip('Levantamiento', gestionLevantamiento),
                  _estadoChip('COP firmado', gestionCop),
                  _estadoChip('Negociación', gestionNegociacion),
                  const SizedBox(height: 12),
                  // Barra de progreso
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: predio.porcentajeAvance / 100,
                      backgroundColor: Colors.grey[200],
                      color: _colorEstado(predio),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${predio.porcentajeAvance}% completado · ${predio.estadoLabel}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    final items = _colorMode == _ColorMode.estado
        ? [
            ('Liberado', const Color(0xFF2E7D32)),
            ('No liberado', const Color(0xFFD32F2F)),
            ('Sin estatus', const Color(0xFF757575)),
          ]
        : [
            ('Sin tipo', const Color(0xFF6D6D6D)),
            ('Social', const Color(0xFF7E57C2)),
            ('Privada', const Color(0xFFF57C00)),
          ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Simbología',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 6),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: item.$2,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item.$1,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailPanelForImportedFeature(GeoJsonPredioFeature feature) {
    final props = feature.properties;
    final clave = _getClaveFromFeature(props);
    final proyecto = _tipoProyectoLabel(
      _extractPropertyByKeyFragments(props, ['PROYECTO']),
    );
    final estatus = _getEstatusFromFeature(props);
    final segmento = _getSegmentoFromFeature(props);
    final kmInicio = _getKmInicioFromFeature(props);
    final kmFin = _getKmFinFromFeature(props);
    final kmLineales = _extractPropertyByKeyFragments(
      props,
      ['KM', 'LINEAL'],
    );
    final tipoPropiedad = _getTipoPropiedadFromFeature(props);
    final propietario = _extractPropertyByKeyFragments(
      props,
      ['PROPIETARIO'],
      fallbackFragments: ['TITULAR', 'REGISTRAL'],
    );
    final municipio = _getMunicipioFromFeature(props);
    final estado = _getEstadoFromFeature(props);
    final frente = _extractPropertyByKeyFragments(
      props,
      ['FRENTE'],
      fallbackFragments: ['FRENTE'],
    );
    final anuencia = _extractPropertyByKeyFragments(props, ['ANUENCIA']);
    final estructura = _extractPropertyByKeyFragments(props, ['ESTRUCTURA']);
    final m2 = _extractPropertyByKeyFragments(
      props,
      ['M2'],
      fallbackFragments: ['SUP', 'AFECT'],
    );
    final nuevo = _extractPropertyByKeyFragments(props, ['NUEVO']);
    final observaciones = _extractPropertyByKeyFragments(
      props,
      ['OBSERVA'],
      fallbackFragments: ['ACERCAMIENTO'],
    );
    final folioElectronico = _extractPropertyByKeyFragments(
      props,
      ['FOLIO', 'ELECTR'],
    );
    final sujetoAgrario = _extractPropertyByKeyFragments(
      props,
      ['SUJETO', 'AGRARIO'],
      fallbackFragments: ['SUJ', 'AGRAR'],
    );
    final poseedor = _extractPropertyByKeyFragments(props, ['POSEEDOR']);
    final valorCatastral = _extractPropertyByKeyFragments(
      props,
      ['VALOR', 'CATASTRAL'],
    );
    final valorComercial = _extractPropertyByKeyFragments(
      props,
      ['VALOR', 'COMERCIAL'],
    );
    final negociado = _extractPropertyByKeyFragments(props, ['NEGOCI']);
    final acercamiento = _extractPropertyByKeyFragments(props, ['ACERCAMIENTO']);
    final convenioFirmado = _extractPropertyByKeyFragments(
      props,
      ['CONVENIO'],
    );
    final montoTotal = _extractPropertyByKeyFragments(props, ['MONTO']);
    final pago = _extractPropertyByKeyFragments(props, ['PAGO']);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera del panel
          Container(
            color: const Color(0xFF1B4332),
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Feature GeoJSON',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        feature.id,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () =>
                      setState(() => _selectedImportedFeature = null),
                ),
              ],
            ),
          ),
          // Contenido desplazable
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sección de información principal
                  _sectionTitle('Información'),
                  const SizedBox(height: 8),
                  _infoRow('Proyecto', proyecto),
                  if (clave.isNotEmpty)
                    _infoRow('Clave/Clave SEDATU', clave)
                  else
                    _infoRow('Clave/Clave SEDATU', ''),
                  if (propietario.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _infoRow('Propietario', propietario),
                  ],
                  if (estatus.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _infoRow('Estatus', estatus),
                  ],
                  if (kmInicio.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _infoRow('KM Inicio', kmInicio),
                  ],
                  if (kmFin.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _infoRow('KM Fin', kmFin),
                  ],
                  if (kmLineales.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _infoRow('KM Lineales', kmLineales),
                  ],
                  if (segmento.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _infoRow('Segmento', segmento),
                  ],
                  if (tipoPropiedad.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _infoRow('Tipo de Propiedad', tipoPropiedad),
                  ],
                  if (frente.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _infoRow('Frente', frente),
                  ],
                  if (municipio.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _infoRow('Municipio', municipio),
                  ],
                  if (estado.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _infoRow('Estado', estado),
                  ],
                  if (anuencia.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _infoRow('Anuencia', anuencia),
                  ],
                  if (estructura.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _infoRow('Estructura', estructura),
                  ],
                  if (m2.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _infoRow('M2', m2),
                  ],
                  if (nuevo.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _infoRow('Nuevo', nuevo),
                  ],
                  if (observaciones.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _infoRow('Observaciones', observaciones),
                  ],
                  if (folioElectronico.isNotEmpty ||
                      sujetoAgrario.isNotEmpty ||
                      poseedor.isNotEmpty ||
                      valorCatastral.isNotEmpty ||
                      valorComercial.isNotEmpty ||
                      negociado.isNotEmpty ||
                      acercamiento.isNotEmpty ||
                      convenioFirmado.isNotEmpty ||
                      montoTotal.isNotEmpty ||
                      pago.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _sectionTitle('Datos complementarios TAP'),
                    const SizedBox(height: 8),
                    if (folioElectronico.isNotEmpty)
                      _infoRow('Folio electrónico', folioElectronico),
                    if (sujetoAgrario.isNotEmpty)
                      _infoRow('Sujeto agrario', sujetoAgrario),
                    if (poseedor.isNotEmpty) _infoRow('Poseedor', poseedor),
                    if (valorCatastral.isNotEmpty)
                      _infoRow('Valor catastral', valorCatastral),
                    if (valorComercial.isNotEmpty)
                      _infoRow('Valor comercial', valorComercial),
                    if (negociado.isNotEmpty)
                      _infoRow('Negociado', negociado),
                    if (acercamiento.isNotEmpty)
                      _infoRow('Acercamiento', acercamiento),
                    if (convenioFirmado.isNotEmpty)
                      _infoRow('Convenio firmado', convenioFirmado),
                    if (montoTotal.isNotEmpty)
                      _infoRow('Monto total', montoTotal),
                    if (pago.isNotEmpty) _infoRow('Pago', pago),
                  ],
                  const SizedBox(height: 16),
                  // Sección de estado de gestión (checklist)
                  _sectionTitle('Estado de Gestión'),
                  const SizedBox(height: 8),
                  _buildGestionChecklistForFeature(props),
                  const SizedBox(height: 16),
                  // Banderas de clasificación
                  if (feature.esEstacion || feature.esEnvolvente) ...[
                    _sectionTitle('Clasificación'),
                    const SizedBox(height: 8),
                    if (feature.esEstacion)
                      _classificationTag('Estación', Colors.amber),
                    if (feature.esEnvolvente)
                      _classificationTag('Envolvente', Colors.blue),
                    const SizedBox(height: 16),
                  ],
                  // Botón para cerrar
                  FilledButton.tonal(
                    onPressed: () =>
                        setState(() => _selectedImportedFeature = null),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Extrae clave del feature (busca en CLAVE o NOM_SEDATU)
  String _getClaveFromFeature(Map<String, dynamic> properties) {
    final keys = properties.keys.toList();
    // Busca CLAVE (exacta o case-insensitive)
    for (final key in keys) {
      if (key.toUpperCase() == 'CLAVE') {
        final value = properties[key];
        return value?.toString().trim() ?? '';
      }
    }
    // Busca NOM_SEDATU o variantes
    for (final key in keys) {
      if (key.toUpperCase().contains('SEDATU')) {
        final value = properties[key];
        return value?.toString().trim() ?? '';
      }
    }
    return '';
  }

  /// Extrae estatus (busca ESTATUS con normalización de valores)
  String _getEstatusFromFeature(Map<String, dynamic> properties) {
    final keys = properties.keys.toList();
    for (final key in keys) {
      if (key.toUpperCase() == 'ESTATUS') {
        final value = properties[key]?.toString().trim() ?? '';
        if (value.isEmpty || value.toUpperCase() == 'NONE') return '';
        final normalized = _normalizedStatus(value);
        if (normalized == 'liberado') return 'Liberado';
        if (normalized == 'no_liberado' || normalized == 'noliberado') {
          return 'No liberado';
        }
        return value;
      }
    }
    return '';
  }

  /// Extrae segmento
  String _getSegmentoFromFeature(Map<String, dynamic> properties) {
    final keys = properties.keys.toList();
    for (final key in keys) {
      if (key.toUpperCase() == 'SEGMENTO') {
        final value = properties[key];
        final raw = value?.toString().trim() ?? '';
        if (raw.isNotEmpty && raw.toUpperCase() != 'NONE') return raw;
      }
    }

    final clave = _getClaveFromFeature(properties);
    final claveSegments = _extractSegmentTokensFromClave(clave);
    if (claveSegments.isNotEmpty) {
      return claveSegments.join('-');
    }

    final sourceAsset = (properties['__source_asset'] ?? '').toString().toLowerCase();
    if (sourceAsset.contains('tsn_seg_16_17')) return '16-17';
    if (sourceAsset.contains('tsn_seg_13')) return '13';
    if (sourceAsset.contains('tsn_seg_18')) return '18';

    return '';
  }

  /// Extrae KM Inicio
  String _getKmInicioFromFeature(Map<String, dynamic> properties) {
    final keys = properties.keys.toList();
    for (final key in keys) {
      final upper = key.toUpperCase();
      if (upper.contains('KM') && upper.contains('INICIO')) {
        final value = properties[key];
        return value?.toString().trim() ?? '';
      }
    }
    return '';
  }

  /// Extrae KM Fin
  String _getKmFinFromFeature(Map<String, dynamic> properties) {
    final keys = properties.keys.toList();
    for (final key in keys) {
      final upper = key.toUpperCase();
      if (upper.contains('KM') && upper.contains('FIN')) {
        final value = properties[key];
        return value?.toString().trim() ?? '';
      }
    }
    return '';
  }

  /// Extrae tipo de propiedad (Privada o Social)
  String _getTipoPropiedadFromFeature(Map<String, dynamic> properties) {
    final keys = properties.keys.toList();
    for (final key in keys) {
      final upper = key.toUpperCase();
      if (upper.contains('TIPO') && upper.contains('PROPIEDAD')) {
        final value = properties[key]?.toString().trim() ?? '';
        // Normaliza a Privada o Social
        if (value.toUpperCase().contains('PRIV')) return 'Privada';
        if (value.toUpperCase().contains('SOC')) return 'Social';
        return value;
      }
    }
    return '';
  }

  /// Verifica si la identificación está completada
  bool _isIdentificacionComplete(Map<String, dynamic> properties) {
    final keys = properties.keys.toList();
    for (final key in keys) {
      if (key.toUpperCase().contains('IDENTIFICA')) {
        return _isValueTrue(properties[key]);
      }
    }

    final acercamiento = _extractPropertyByKeyFragments(
      properties,
      ['ACERCAMIENTO'],
    );
    if (_isValueTrue(acercamiento) || _hasMeaningfulValue(acercamiento)) {
      return true;
    }

    final entregado = _extractPropertyByKeyFragments(properties, ['ENTREGADO']);
    if (_isValueTrue(entregado)) return true;

    return false;
  }

  /// Verifica si el levantamiento está completado
  bool _isLevantamientoComplete(Map<String, dynamic> properties) {
    final keys = properties.keys.toList();
    for (final key in keys) {
      if (key.toUpperCase().contains('LEVANTAMIE')) {
        return _isValueTrue(properties[key]);
      }
    }

    final medicionPoligono = _extractPropertyByKeyFragments(
      properties,
      ['MEDICION', 'POLIGONO'],
    );
    if (_isValueTrue(medicionPoligono) || _hasMeaningfulValue(medicionPoligono)) {
      return true;
    }

    final medicionBdt = _extractPropertyByKeyFragments(
      properties,
      ['MEDICION', 'BDT'],
    );
    if (_isValueTrue(medicionBdt) || _hasMeaningfulValue(medicionBdt)) {
      return true;
    }

    final plano = _extractPropertyByKeyFragments(properties, ['PLANO']);
    if (_isValueTrue(plano) || _hasMeaningfulValue(plano)) return true;

    return false;
  }

  /// Verifica si está en negociación
  bool _isNegociacionActive(Map<String, dynamic> properties) {
    final keys = properties.keys.toList();
    for (final key in keys) {
      if (key.toUpperCase().contains('NEGOCIACION')) {
        return _isValueTrue(properties[key]);
      }
    }

    final negociado = _extractPropertyByKeyFragments(properties, ['NEGOCIADO']);
    if (_isValueTrue(negociado) || _hasMeaningfulValue(negociado)) return true;

    final estatus = _getEstatusFromFeature(properties);
    if (_normalizedStatus(estatus).contains('negociacion')) return true;

    return false;
  }

  /// Verifica si el COP está firmado
  bool _isCOPFirmado(Map<String, dynamic> properties) {
    final keys = properties.keys.toList();
    for (final key in keys) {
      final upper = key.toUpperCase();
      if (upper.contains('COP') || upper.contains('C.O.P')) {
        final value = properties[key]?.toString().trim().toUpperCase() ?? '';
        if (_isValueTrue(value)) return true;
      }
    }

    final convenioFirmado = _extractPropertyByKeyFragments(
      properties,
      ['CONVENIO'],
    );
    if (_isValueTrue(convenioFirmado)) return true;

    final fechaCop = _extractPropertyByKeyFragments(properties, ['FECHA', 'COP']);
    if (_hasMeaningfulValue(fechaCop)) return true;

    return false;
  }

  /// Helper para determinar si un valor es "truthy"
  bool _isValueTrue(dynamic value) {
    if (value == null) return false;
    final str = value.toString().trim().toUpperCase();
    return str == 'SÍ' ||
        str == 'SI' ||
        str == 'YES' ||
        str == '1' ||
        str == 'TRUE' ||
        str == 'FIRMADO' ||
        str == 'OK' ||
        str == 'COP' ||
        str == 'AOP';
  }

  bool _hasMeaningfulValue(String value) {
    final str = value.trim().toUpperCase();
    if (str.isEmpty) return false;
    const negatives = {
      'NO',
      '0',
      'FALSE',
      'N/A',
      'NA',
      'NONE',
      'NULL',
      'N/D',
      'ND',
      'SIN DATO',
      'NO APLICA',
    };
    return !negatives.contains(str);
  }

  /// Widget que muestra el checklist de gestión
  Widget _buildGestionChecklistForFeature(Map<String, dynamic> properties) {
    final isTapFeature =
        _tipoProyectoLabel(_extractPropertyByKeyFragments(properties, ['PROYECTO'])) ==
            'TAP';
    final isFeatureLiberado =
        _normalizedStatus(_getEstatusFromFeature(properties)) == 'liberado';
    final forceGreenGestion = isTapFeature && isFeatureLiberado;
    final hasCOPFirmado = forceGreenGestion || _isCOPFirmado(properties);
    final hasIdentificacion =
        forceGreenGestion ||
        _isIdentificacionComplete(properties) ||
        hasCOPFirmado;
    final hasLevantamiento =
        forceGreenGestion || _isLevantamientoComplete(properties);
    final hasNegociacion =
        forceGreenGestion || _isNegociacionActive(properties);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChecklistItem('Identificación', hasIdentificacion),
        const SizedBox(height: 6),
        _buildChecklistItem('Levantamiento', hasLevantamiento),
        const SizedBox(height: 6),
        _buildChecklistItem('Negociación', hasNegociacion),
        const SizedBox(height: 6),
        _buildChecklistItem('COP Firmado', hasCOPFirmado),
      ],
    );
  }

  /// Widget individual para un item del checklist
  Widget _buildChecklistItem(String label, bool isChecked) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            border: Border.all(
              color: isChecked ? Colors.green : Colors.grey[400]!,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(3),
            color: isChecked ? Colors.green.withOpacity(0.1) : Colors.transparent,
          ),
          child: isChecked
              ? const Icon(
                  Icons.check,
                  size: 14,
                  color: Colors.green,
                )
              : null,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isChecked ? Colors.black87 : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Color _colorForStatus(String status) {
    final lower = status.trim().toLowerCase();
    if (lower == 'liberado') return const Color(0xFFCDDC39);
    if (lower == 'no liberado') return const Color(0xFFD32F2F);
    return Colors.grey;
  }

  Widget _classificationTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Colors.grey[800],
      ),
    );
  }

  Widget _estadoChip(String label, bool activo) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            activo ? Icons.check_circle : Icons.radio_button_unchecked,
            color: activo ? const Color(0xFF2E7D32) : Colors.grey[400],
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: activo ? Colors.grey[800] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  String _kmFmt(double km) {
    final int km0 = km.truncate();
    final int m = ((km - km0) * 1000).round();
    return '${km0.toString().padLeft(1, '0')}+${m.toString().padLeft(3, '0')}';
  }

  List<List<LatLng>> _extractPolygons(Map<String, dynamic> geo) {
    final geometryId = 'poly:${identityHashCode(geo)}';
    return _geometryCache.getPolygons(geometryId, geo, (geometry) {
      final type = geometry['type'] as String?;
      if (type == 'Polygon') {
        final coords = geometry['coordinates'] as List?;
        if (coords == null || coords.isEmpty) return const [];
        return [_toLatLngs(coords[0] as List)];
      } else if (type == 'MultiPolygon') {
        final multiCoords = geometry['coordinates'] as List?;
        if (multiCoords == null) return const [];
        return multiCoords
            .map((poly) => _toLatLngs((poly as List)[0] as List))
            .toList();
      }
      return const [];
    });
  }

  List<List<LatLng>> _extractPolylines(Map<String, dynamic> geo) {
    final geometryId = 'line:${identityHashCode(geo)}';
    return _geometryCache.getPolylines(geometryId, geo, (geometry) {
      final type = geometry['type'] as String?;
      if (type == 'LineString') {
        final coords = geometry['coordinates'] as List?;
        if (coords == null || coords.isEmpty) return const [];
        return [_toLatLngs(coords)];
      } else if (type == 'MultiLineString') {
        final multiCoords = geometry['coordinates'] as List?;
        if (multiCoords == null) return const [];
        return multiCoords.map((line) => _toLatLngs(line as List)).toList();
      }
      return const [];
    });
  }

  LatLng? _extractRepresentativePoint(Map<String, dynamic> geo) {
    final type = geo['type'] as String?;
    if (type == 'Point') {
      final coords = geo['coordinates'] as List?;
      if (coords == null || coords.length < 2) return null;
      final lon = (coords[0] as num?)?.toDouble();
      final lat = (coords[1] as num?)?.toDouble();
      if (lat == null || lon == null) return null;
      return LatLng(lat, lon);
    }

    if (type == 'MultiPoint') {
      final coords = geo['coordinates'] as List?;
      if (coords == null || coords.isEmpty) return null;
      final first = coords.first;
      if (first is! List || first.length < 2) return null;
      final lon = (first[0] as num?)?.toDouble();
      final lat = (first[1] as num?)?.toDouble();
      if (lat == null || lon == null) return null;
      return LatLng(lat, lon);
    }

    return null;
  }

  List<LatLng> _simplifyGeometryForZoom(
    List<LatLng> points,
    double zoom, {
    required bool isPolygon,
  }) {
    if (points.length < 8) return points;

    final stride = zoom >= 13
        ? 1
        : zoom >= 12
            ? 2
            : zoom >= 11
                ? 3
                : 5;
    if (stride <= 1) return points;

    final sampled = <LatLng>[];
    for (int i = 0; i < points.length; i += stride) {
      sampled.add(points[i]);
    }

    final last = points.last;
    if (sampled.isEmpty || sampled.last != last) {
      sampled.add(last);
    }

    if (isPolygon && sampled.length < 3) return points;
    if (!isPolygon && sampled.length < 2) return points;
    return sampled;
  }

  List<LatLng> _toLatLngs(List raw) {
    final points = <LatLng>[];
    for (final c in raw) {
      final coord = c as List;
      final lng = (coord[0] as num).toDouble();
      final lat = (coord[1] as num).toDouble();

      // Descarta coordenadas fuera de rango geográfico (datos proyectados o corruptos).
      if (!lng.isFinite || !lat.isFinite) continue;
      if (lng < -180 || lng > 180 || lat < -90 || lat > 90) continue;

      points.add(LatLng(lat, lng));
    }
    return points;
  }

  LatLng _centroid(List<LatLng> points) {
    if (points.isEmpty) return _defaultCenter;
    double lat = 0, lng = 0;
    for (final p in points) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / points.length, lng / points.length);
  }

  List<Predio> _applyLiberacionFilter(List<Predio> predios) {
    switch (_liberacionFilter) {
      case _LiberacionFilter.liberados:
        return predios.where(_isLiberado).toList();
      case _LiberacionFilter.noLiberados:
        return predios.where(_isNoLiberado).toList();
      case _LiberacionFilter.todos:
        return predios;
    }
  }

  List<Predio> _applyAllFilters(List<Predio> predios) {
    // "Solo Estaciones" aplica a capas importadas; ocultar capa base de predios.
    if (_filterSoloEstaciones) return const [];

    final liberacion = _applyLiberacionFilter(predios);
    var filtered = liberacion;
    if (_selectedTipoProyectos.isNotEmpty) {
      filtered = filtered.where((p) {
        final label = _tipoProyectoLabel(p.proyecto);
        return _selectedTipoProyectos.contains(label);
      }).toList();
    }
    if (_selectedClasificaciones.isNotEmpty) {
      filtered = filtered.where((p) {
        final tipo = p.tipoPropiedad.toUpperCase().trim();
        final clasificacion =
            tipo == 'SOCIAL' ? 'Pública' : (tipo == 'PRIVADA' ? 'Privada' : 'Sin clasificación');
        return _selectedClasificaciones.contains(clasificacion);
      }).toList();
    }
    if (_selectedEjidos.isNotEmpty) {
      filtered = filtered.where((p) {
        final key = _normalizeFilterDimensionValue(
          p.ejido ?? '',
          emptyLabel: 'Sin ejido',
        );
        return _selectedEjidos.contains(key);
      }).toList();
    }
    if (_selectedMunicipios.isNotEmpty) {
      filtered = filtered.where((p) {
        final value = (p.municipio ?? p.ejido ?? '').trim();
        if (_selectedMunicipios.contains('Sin municipio') && value.isEmpty) return true;
        final normalized = _normalizeMunicipioName(value);
        return _selectedMunicipios.any((m) => _normalizeMunicipioName(m) == normalized);
      }).toList();
    }
    if (_selectedEstatus.isNotEmpty) {
      final selectedEstatusKeys =
          _selectedEstatus.map(_normalizeEstatusFilterLabel).toSet();
      filtered = filtered.where((p) {
        final estatusKey =
            _normalizeEstatusFilterLabel(_estatusFilterLabelFromPredio(p));
        return selectedEstatusKeys.contains(estatusKey);
      }).toList();
    }
    if (_segmentoQueries.isNotEmpty) {
      filtered = filtered.where((p) {
        return _matchesSegmentQuery(p.tramo);
      }).toList();
    }
    return filtered;
  }

  // Multi-select count section for filters
  Widget _countSectionMulti({
    required String title,
    required Map<String, int> counts,
    required Set<String> selectedLabels,
    required ValueChanged<String> onChipTap,
  }) {
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: sorted
              .map(
                (entry) => _countChip(
                  entry.key,
                  entry.value,
                  active: selectedLabels.contains(entry.key),
                  onTap: () => onChipTap(entry.key),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  String _tipoProyectoLabel(String? proyecto) {
    final value = proyecto?.trim().toUpperCase();
    if (value == null || value.isEmpty) return 'Sin proyecto';
    return value;
  }

  bool _isEnvolventePredio(Predio predio) {
    return _containsEnvolventeKeyword(predio.proyecto) ||
        _containsEnvolventeKeyword(predio.tramo) ||
        _containsEnvolventeKeyword(predio.clasificacionAfectacion) ||
        _containsEnvolventeKeyword(predio.claveCatastral);
  }

  bool _containsEnvolventeKeyword(String? value) {
    final normalized = (value ?? '')
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
    return normalized.contains('envolvente');
  }

  List<GeoJsonPredioFeature> _applyAllImportedFilters(
    List<GeoJsonPredioFeature> features,
  ) {
    // Separar envolventes (SIEMPRE visibles)
    final envolventes = features.where(_isEnvelopeFeature).toList();
    var nonEnvolventes = features.where((f) => !_isEnvelopeFeature(f)).toList();

    // Si Solo Estaciones está activo: SOLO estaciones (+ envolventes al final)
    if (_filterSoloEstaciones) {
      final soloEstaciones =
          nonEnvolventes.where((f) => f.esEstacion).toList();
      // Retornar: estaciones + envolventes siempre
      return [...soloEstaciones, ...envolventes];
    }

    // En modo normal, ocultar estaciones/servicios auxiliares.
    var filtered = nonEnvolventes.where((f) => !f.esEstacion).toList();

    // Aplicar otros filtros solo si NO está "Solo Estaciones"
    if (_liberacionFilter != _LiberacionFilter.todos) {
      filtered = filtered.where((feature) {
        if (_liberacionFilter == _LiberacionFilter.liberados) {
          return _isImportedLiberado(feature);
        }
        return _isImportedNoLiberado(feature);
      }).toList();
    }

    if (_segmentoQueries.isNotEmpty) {
      filtered = filtered.where((feature) {
        return _matchesSegmentQuery(_getSegmentoFromFeature(feature.properties));
      }).toList();
    }

    if (_selectedTipoProyectos.isNotEmpty) {
      filtered = filtered.where((feature) {
        final label = _tipoProyectoLabel(feature.properties['PROYECTO']?.toString());
        return _selectedTipoProyectos.contains(label);
      }).toList();
    }

    if (_selectedClasificaciones.isNotEmpty) {
      filtered = filtered.where((feature) {
        final clasificacion = _getTipoPropiedadFromFeature(feature.properties);
        final label = clasificacion.isEmpty ? 'Sin clasificación' : clasificacion;
        return _selectedClasificaciones.contains(label);
      }).toList();
    }

    if (_selectedEjidos.isNotEmpty) {
      filtered = filtered.where((feature) {
        final value = _getEjidoFromFeature(feature.properties).trim();
        final key = value.isEmpty ? 'Sin ejido' : value;
        return _selectedEjidos.contains(key);
      }).toList();
    }

    if (_selectedMunicipios.isNotEmpty) {
      filtered = filtered.where((feature) {
        final value = _getMunicipioFromFeature(feature.properties).trim();
        if (_selectedMunicipios.contains('Sin municipio') && value.isEmpty) return true;
        if (value.isEmpty) return false;
        final normalized = _normalizeMunicipioName(value);
        return _selectedMunicipios.any((m) => _normalizeMunicipioName(m) == normalized);
      }).toList();
    }

    if (_selectedEstatus.isNotEmpty) {
      final selectedEstatusKeys =
          _selectedEstatus.map(_normalizeEstatusFilterLabel).toSet();
      filtered = filtered.where((feature) {
        final estatusKey = _normalizeEstatusFilterLabel(
          _estatusFilterLabelFromProperties(feature.properties),
        );
        return selectedEstatusKeys.contains(estatusKey);
      }).toList();
    }

    // Retornar: contenido filtrado + envolventes siempre visibles
    return [...filtered, ...envolventes];
  }

  bool _isEnvelopeFeature(GeoJsonPredioFeature feature) {
    if (feature.esEnvolvente) return true;

    final sourceAsset =
        (feature.properties['__source_asset'] ?? '').toString().toLowerCase();
    if (sourceAsset.contains('envolvente')) return true;
    if (sourceAsset.contains('ap-t00-sdef-01-v00-pla-pr_prg-36779_25-a02')) {
      return true;
    }

    final tipoCapa = _extractPropertyByKeyFragments(
      feature.properties,
      ['TIPO', 'CAPA'],
    );
    if (_containsEnvolventeKeyword(tipoCapa)) return true;

    final clave = _getClaveFromFeature(feature.properties);
    return _containsEnvolventeKeyword(clave);
  }

  String _getEjidoFromFeature(Map<String, dynamic> properties) {
    final raw = _extractPropertyByKeyFragments(
      properties,
      ['EJIDO'],
      fallbackFragments: ['LOCALIDAD'],
    );
    return _normalizeFilterDimensionValue(raw, emptyLabel: 'Sin ejido');
  }

  String _normalizeFilterDimensionValue(
    String value, {
    required String emptyLabel,
  }) {
    final raw = value.trim();
    if (raw.isEmpty) return emptyLabel;
    if (RegExp(r'^[-_.\s]+$').hasMatch(raw)) return emptyLabel;

    final normalized = raw
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    const invalidTokens = {
      'null',
      'none',
      'na',
      'n/a',
      'n.d',
      'n/d',
      'nd',
      'sin dato',
      's/d',
      's.d',
    };
    if (invalidTokens.contains(normalized)) return emptyLabel;

    return raw;
  }

  String _getMunicipioFromFeature(Map<String, dynamic> properties) {
    return _extractPropertyByKeyFragments(
      properties,
      ['MUNICIPIO'],
      fallbackFragments: ['EJIDO', 'LOCALIDAD'],
    );
  }

  String _getEstadoFromFeature(Map<String, dynamic> properties) {
    return _extractPropertyByKeyFragments(
      properties,
      ['ESTADO'],
      fallbackFragments: ['UBICACION', 'ENTIDAD'],
    );
  }

  String _extractPropertyByKeyFragments(
    Map<String, dynamic> properties,
    List<String> primaryFragments, {
    List<String> fallbackFragments = const [],
  }) {
    final keys = properties.keys.toList();

    String findByFragments(List<String> fragments) {
      for (final key in keys) {
        final upper = key.toUpperCase();
        final match = fragments.every((fragment) => upper.contains(fragment));
        if (match) {
          return properties[key]?.toString().trim() ?? '';
        }
      }
      return '';
    }

    final primary = findByFragments(primaryFragments);
    if (primary.isNotEmpty) return primary;
    if (fallbackFragments.isEmpty) return '';
    return findByFragments(fallbackFragments);
  }

  String _extractSegmentNumber(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return '';

    final segments = _extractSegmentTokens(raw);
    if (segments.isEmpty) return '';
    return segments.first;
  }

  List<String> _extractSegmentTokens(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return const [];

    final matches = RegExp(r'\d+').allMatches(raw);
    if (matches.isEmpty) return const [];

    final unique = <String>{};
    final ordered = <String>[];
    for (final match in matches) {
      final token = match.group(0);
      if (token == null || token.isEmpty) continue;
      final n = int.tryParse(token);
      if (n == null) continue;
      // Segmentos válidos del portal: 13 a 18.
      if (n < 13 || n > 18) continue;
      final normalized = n.toString();
      if (unique.add(normalized)) {
        ordered.add(normalized);
      }
    }
    return ordered;
  }

  List<String> _extractSegmentTokensFromClave(String? value) {
    final raw = (value ?? '').trim().toUpperCase();
    if (raw.isEmpty) return const [];

    final matches = RegExp(r'(?:^|[-_])(?:S)?0?([1-2][0-9]|30)(?:$|[-_])')
        .allMatches(raw);
    if (matches.isEmpty) return const [];

    final unique = <String>{};
    final ordered = <String>[];
    for (final match in matches) {
      final token = match.group(1);
      if (token == null || token.isEmpty) continue;
      final parsed = int.parse(token);
      if (parsed < 13 || parsed > 18) continue;
      final normalized = parsed.toString();
      if (unique.add(normalized)) {
        ordered.add(normalized);
      }
    }
    return ordered;
  }

  bool _matchesSegmentQuery(String? rawSegmentValue) {
    if (_segmentoQueries.isEmpty) return true;
    final segments = _extractSegmentTokens(rawSegmentValue);
    if (segments.isEmpty) return false;
    return segments.any(_segmentoQueries.contains);
  }

  String _propertyLabel(String value) {
    final normalized = value.trim().toUpperCase();
    if (normalized == 'SOCIAL') return 'Pública';
    if (normalized == 'PRIVADA') return 'Privada';
    return value;
  }

  String _normalizeMunicipioName(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  void _ensureInitialFocus(
    List<Predio> predios,
    List<GeoJsonPredioFeature> importedGeoJsonPredios,
  ) {
    if (_didInitialFocus) return;

    if (predios.isEmpty && importedGeoJsonPredios.isNotEmpty) {
      final firstFeaturePolys = _extractPolygons(importedGeoJsonPredios.first.geometry);
      if (firstFeaturePolys.isNotEmpty && firstFeaturePolys.first.isNotEmpty) {
        final firstCenter = _centroid(firstFeaturePolys.first);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _didInitialFocus) return;
          _mapCtrl.move(firstCenter, 13);
          setState(() {
            _didInitialFocus = true;
          });
        });
        return;
      }
    }

    final points = _collectPredioPoints(predios);
    final fallbackGeoJsonPoints = _collectImportedGeoJsonPoints(importedGeoJsonPredios);
    final target = points.isNotEmpty ? points : fallbackGeoJsonPoints;
    if (target.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didInitialFocus) return;
      if (target.length == 1) {
        _mapCtrl.move(target.first, 14);
      } else {
        _mapCtrl.fitCamera(
          CameraFit.coordinates(
            coordinates: target,
            padding: const EdgeInsets.fromLTRB(40, 130, 40, 40),
          ),
        );
      }
      setState(() {
        _didInitialFocus = true;
      });
    });
  }

  void _ensureImportedGeoJsonFocus(List<GeoJsonPredioFeature> importedGeoJsonPredios) {
    if (_didImportedGeoJsonFocus) return;
    if (importedGeoJsonPredios.isEmpty) return;

    final points = _collectImportedGeoJsonCentroids(importedGeoJsonPredios);
    if (points.isEmpty) return;

    _didImportedGeoJsonFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (points.length == 1) {
        _mapCtrl.move(points.first, 13);
      } else {
        _mapCtrl.fitCamera(
          CameraFit.coordinates(
            coordinates: points,
            padding: const EdgeInsets.fromLTRB(40, 130, 40, 40),
          ),
        );
      }
    });
  }

  void _focusImportedGeoJsonNow(List<GeoJsonPredioFeature> importedGeoJsonPredios) {
    final points = _collectImportedGeoJsonCentroids(importedGeoJsonPredios);
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapCtrl.move(points.first, 13);
      return;
    }
    _mapCtrl.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.fromLTRB(40, 130, 40, 40),
      ),
    );
  }

  List<LatLng> _collectImportedGeoJsonCentroids(
    List<GeoJsonPredioFeature> importedGeoJsonPredios,
  ) {
    final points = <LatLng>[];
    for (final feature in importedGeoJsonPredios) {
      final polys = _extractPolygons(feature.geometry);
      if (polys.isNotEmpty && polys.first.isNotEmpty) {
        points.add(_centroid(polys.first));
        continue;
      }
      final lines = _extractPolylines(feature.geometry);
      if (lines.isNotEmpty && lines.first.isNotEmpty) {
        points.add(_centroid(lines.first));
      }
    }
    return points;
  }

  Widget _buildFocusGeoJsonButton(List<GeoJsonPredioFeature> importedGeoJsonPredios) {
    return Material(
      color: Colors.white,
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _focusImportedGeoJsonNow(importedGeoJsonPredios),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.my_location_rounded, size: 18, color: Color(0xFF444444)),
              const SizedBox(width: 6),
              Text(
                'Ir a GeoJSON',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF444444),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<LatLng> _collectPredioPoints(List<Predio> predios) {
    final points = <LatLng>[];
    for (final p in predios) {
      if (p.geometry != null) {
        final polys = _extractPolygons(p.geometry!);
        if (polys.isNotEmpty && polys.first.isNotEmpty) {
          points.add(_centroid(polys.first));
          continue;
        }
      }
      if (p.latitud != null && p.longitud != null) {
        points.add(LatLng(p.latitud!, p.longitud!));
      }
    }
    return points;
  }

  List<LatLng> _collectImportedGeoJsonPoints(
    List<GeoJsonPredioFeature> importedGeoJsonPredios,
  ) {
    final points = <LatLng>[];
    for (final feature in importedGeoJsonPredios) {
      final polys = _extractPolygons(feature.geometry);
      for (final ring in polys) {
        if (ring.length < 3) continue;
        points.addAll(ring);
      }
      final lines = _extractPolylines(feature.geometry);
      for (final line in lines) {
        if (line.length < 2) continue;
        points.addAll(line);
      }
    }
    return points;
  }

  bool _isLiberado(Predio p) =>
      _normalizedStatus(p.estatus) == 'liberado' || p.cop;

  bool _isNoLiberado(Predio p) {
    if (_isLiberado(p)) return false;
    final status = _normalizedStatus(p.estatus);
    if (status.isNotEmpty) return status != 'liberado';
    return p.identificacion || p.levantamiento || p.negociacion;
  }

  bool _isImportedLiberado(GeoJsonPredioFeature feature) {
    final status = _normalizedStatus(_getEstatusFromFeature(feature.properties));
    if (status == 'liberado') return true;
    return _isCOPFirmado(feature.properties);
  }

  bool _isImportedNoLiberado(GeoJsonPredioFeature feature) {
    if (_isImportedLiberado(feature)) return false;
    final status = _normalizedStatus(_getEstatusFromFeature(feature.properties));
    if (status.isNotEmpty) return status != 'liberado';
    return _isIdentificacionComplete(feature.properties) ||
        _isLevantamientoComplete(feature.properties) ||
        _isNegociacionActive(feature.properties);
  }

  String _estatusFilterLabelFromPredio(Predio p) {
    if (_isLiberado(p)) return 'Liberado';

    final status = _normalizedStatus(p.estatus);
    if (_isNegotiationStatus(status) || p.negociacion) {
      return 'En negociación';
    }
    if (_isNoProgressStatus(status)) {
      return 'Sin avance';
    }
    if (status.isNotEmpty) {
      return 'No liberado';
    }
    if (p.identificacion || p.levantamiento || p.negociacion) {
      return 'No liberado';
    }
    return 'Sin estatus';
  }

  String _estatusFilterLabelFromProperties(Map<String, dynamic> properties) {
    if (_isCOPFirmado(properties)) return 'Liberado';

    final status = _normalizedStatus(_getEstatusFromFeature(properties));
    if (_isNegotiationStatus(status) || _isNegociacionActive(properties)) {
      return 'En negociación';
    }
    if (_isNoProgressStatus(status)) {
      return 'Sin avance';
    }
    if (status == 'liberado') {
      return 'Liberado';
    }
    if (status.isNotEmpty) {
      return 'No liberado';
    }
    if (_isIdentificacionComplete(properties) ||
        _isLevantamientoComplete(properties) ||
        _isNegociacionActive(properties)) {
      return 'No liberado';
    }
    return 'Sin estatus';
  }

  bool _isNegotiationStatus(String status) {
    return status.contains('negociacion');
  }

  bool _isNoProgressStatus(String status) {
    return status.contains('sin_avance');
  }

  String _normalizeEstatusFilterLabel(String value) {
    final compact = _normalizedStatus(value);
    if (compact.isEmpty) return 'sin_estatus';
    if (compact == 'liberado') return 'liberado';
    if (compact == 'no_liberado' || compact == 'noliberado') {
      return 'no_liberado';
    }
    if (_isNegotiationStatus(compact)) return 'en_negociacion';
    if (_isNoProgressStatus(compact)) return 'sin_avance';
    return compact;
  }

  String _normalizedStatus(String? value) {
    final raw = (value ?? '').trim().toLowerCase();
    if (raw.isEmpty) return '';
    final compact = raw
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (compact == 'liberado') return 'liberado';
    if (compact == 'no_liberado' || compact == 'noliberado') {
      return 'no_liberado';
    }
    return compact;
  }

  double _bucketSizeForZoom(double zoom) {
    if (zoom >= 17) return 0.0025;
    if (zoom >= 15) return 0.004;
    if (zoom >= 13) return 0.008;
    if (zoom >= 11) return 0.015;
    if (zoom >= 9) return 0.03;
    return 0.06;
  }

  int _estimateGroups(List<Predio> predios, double zoom) {
    final bucket = _bucketSizeForZoom(zoom);
    if (bucket <= 0) return predios.length;
    final cells = <String, _HeatBucket>{};
    for (final p in predios) {
      LatLng? pos;
      if (p.geometry != null) {
        final polys = _extractPolygons(p.geometry!);
        if (polys.isNotEmpty && polys.first.isNotEmpty) {
          pos = _centroid(polys.first);
        }
      }
      pos ??= (p.latitud != null && p.longitud != null)
          ? LatLng(p.latitud!, p.longitud!)
          : null;
      if (pos == null) continue;
      final latIdx = (pos.latitude / bucket).floor();
      final lngIdx = (pos.longitude / bucket).floor();
      final key = '$latIdx:$lngIdx';
      final existing = cells[key];
      if (existing == null) {
        cells[key] = _HeatBucket(center: pos, count: 1);
      } else {
        final total = existing.count + 1;
        existing.center = LatLng(
          ((existing.center.latitude * existing.count) + pos.latitude) / total,
          ((existing.center.longitude * existing.count) + pos.longitude) /
              total,
        );
        existing.count = total;
      }
    }
    return _mergeOverlappingBuckets(cells.values.toList(), bucket).length;
  }

  String _zoomLabel(double zoom) {
    if (zoom >= 14) return 'cercana';
    if (zoom >= 11) return 'media';
    return 'lejana';
  }

  Color _heatColor(_HeatBucket bucket) {
    // Color based on liberation status ratio
    // Green if mostly liberados, Red if mostly no liberados, Yellow/Orange if mixed
    if (bucket.count == 0) return const Color(0xFF7CB342); // default green
    
    final liberadoRatio = bucket.liberados / bucket.count;
    final noLiberadoRatio = bucket.noLiberados / bucket.count;
    
    // If predominantly liberated (>66%)
    if (liberadoRatio > 0.66) {
      return const Color(0xFF2E7D32); // strong green
    }
    
    // If predominantly not liberated (>66%)
    if (noLiberadoRatio > 0.66) {
      return const Color(0xFFD32F2F); // strong red
    }
    
    // Mixed clusters: use yellow/orange based on slight predominance
    if (bucket.liberados > bucket.noLiberados) {
      return const Color(0xFFFBC02D); // yellow (slightly more liberated)
    } else if (bucket.noLiberados > bucket.liberados) {
      return const Color(0xFFF57C00); // orange (slightly more not liberated)
    }
    
    return const Color(0xFFFBC02D); // balanced: yellow
  }

  String _getTileUrl() {
    if (_baseLayer == _BaseLayer.satelital) {
      return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    }
    return 'https://services.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}';
  }

  Widget _buildLayersDropdown() {
    return Material(
      color: Colors.white,
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      child: PopupMenuButton<_BaseLayer>(
        tooltip: 'Tipo de capa',
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        color: Colors.white,
        icon: const Icon(Icons.layers_outlined, color: Color(0xFF555555), size: 20),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        itemBuilder: (context) => [
          PopupMenuItem<_BaseLayer>(
            value: _BaseLayer.estandar,
            child: Text(
              'Estándar',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: _baseLayer == _BaseLayer.estandar
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ),
          PopupMenuItem<_BaseLayer>(
            value: _BaseLayer.satelital,
            child: Text(
              'Satelital',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: _baseLayer == _BaseLayer.satelital
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ),
        ],
        onSelected: (value) {
          setState(() => _baseLayer = value);
        },
      ),
    );
  }
}

/// Toggle de modo color para el mapa
class _ColorModeToggle extends StatelessWidget {
  final _ColorMode mode;
  final ValueChanged<_ColorMode> onChanged;

  const _ColorModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tab('Estado', _ColorMode.estado),
          _tab('Tipo', _ColorMode.tipo),
        ],
      ),
    );
  }

  Widget _tab(String label, _ColorMode value) {
    final active = mode == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              active ? Colors.white.withOpacity(0.9) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? const Color(0xFF1B4332) : Colors.white70,
          ),
        ),
      ),
    );
  }
}
