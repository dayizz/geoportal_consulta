import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../auth/auth_provider.dart';
import 'predio_model.dart';
import 'predios_provider.dart';

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
  String? _selectedMunicipio;
  _ColorMode _colorMode = _ColorMode.estado;
  _LiberacionFilter _liberacionFilter = _LiberacionFilter.todos;
  _BaseLayer _baseLayer = _BaseLayer.satelital;
  bool _isRefreshing = false;
  bool _didInitialFocus = false;
  bool _didImportedGeoJsonFocus = false;
  String _segmentoQuery = '';
  String? _lastFocusedMunicipioKey;
  DateTime? _lastRefresh;
  late AnimationController _spinCtrl;
  double _currentZoom = _defaultZoom;

  static const _defaultCenter = LatLng(20.72, -100.35);
  static const _defaultZoom = 10.0;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _lastRefresh = DateTime.now();
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
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
    final proyecto = ref.watch(proyectoActivoProvider) ?? '';
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
              proyecto,
              prediosAsync.valueOrNull ?? [],
              municipiosAsync.valueOrNull ?? const [],
              importedGeoJsonAsync.valueOrNull?.length ?? 0,
            ),
          ),

          // ─── Etiqueta de capa activa ───────────────────────────────────
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _baseLayer == _BaseLayer.estandar ? 'Estandar' : 'Satelital',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),

          // ─── Panel de detalle ────────────────────────────────────────────
          if (_selectedPredio != null)
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
    _ensureImportedGeoJsonFocus(importedGeoJsonPredios);
    final filteredPredios = _applyAllFilters(predios);
    final visiblePredioIds = filteredPredios.map((p) => p.id).toSet();
    _ensureInitialFocus(predios, importedGeoJsonPredios);
    final polygons = <Polygon>[];
    final importedPolygons = <Polygon>[];
    final municipalPolygons = <Polygon>[];
    final municipalPolylines = <Polyline>[];
    final markers = <Marker>[];
    final bucketSize = _bucketSizeForZoom(_currentZoom);
    final bucketed = <String, _HeatBucket>{};

    // Mostrar polígonos desde el zoom inicial para evitar mapa sin geometrías visibles.
    bool shouldDrawPolygons() => _currentZoom >= 10;

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
              polygons.add(Polygon(
                points: coords,
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
      if (bucketSize > 0) {
        final bucket = _putInBucket(bucketed, p, markerPoint, bucketSize);
        bucket.sample ??= p;
      }
    }

    if (bucketSize > 0) {
      final mergedBuckets =
          _mergeOverlappingBuckets(bucketed.values.toList(), bucketSize);
      for (final bucket in mergedBuckets) {
        markers.add(_buildHeatMarker(bucket));
      }
    }

    // Solo pintar icono para el polígono actualmente seleccionado.
    if (_selectedPredio != null) {
      final selected = _selectedPredio!;
      final selectedPos = _markerPointForPredio(selected);
      if (selectedPos != null) {
        final selectedColor = _colorMode == _ColorMode.estado
            ? _colorEstado(selected)
            : _colorTipo(selected);
        markers.add(_buildMarker(selected, selectedPos, selectedColor));
      }
    }

    for (final feature in importedGeoJsonPredios) {
      if (predios.isNotEmpty && !visiblePredioIds.contains(feature.id)) {
        continue;
      }
      final rings = _extractPolygons(feature.geometry);
      final estatus = feature.estatus?.trim().toLowerCase();
          final color = estatus == 'liberado'
            ? const Color(0xFFCDDC39)
          : const Color(0xFFD32F2F);

      for (final ring in rings) {
        if (ring.length < 3) continue;
        importedPolygons.add(
          Polygon(
            points: ring,
            color: color.withOpacity(0.35),
            borderColor: color.withOpacity(0.95),
            borderStrokeWidth: 3.2,
          ),
        );
      }
    }

    final municipioSeleccionado = _selectedMunicipio;
    if (municipioSeleccionado != null && municipioSeleccionado != 'Sin municipio') {
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
    } else {
      _lastFocusedMunicipioKey = null;
    }

    return FlutterMap(
      mapController: _mapCtrl,
      options: MapOptions(
        initialCenter: _defaultCenter,
        initialZoom: _defaultZoom,
        onTap: (_, point) {
          final tappedPredio = _findPredioAtPoint(point, filteredPredios);
          setState(() => _selectedPredio = tappedPredio);
        },
        onPositionChanged: (position, hasGesture) {
          final nextZoom = position.zoom ?? _currentZoom;
          if ((nextZoom - _currentZoom).abs() >= 0.2) {
            setState(() => _currentZoom = nextZoom);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: _getTileUrl(),
          userAgentPackageName: 'mx.sao.geoportal_consulta',
          maxZoom: 19,
        ),
        // Capa adicional de etiquetas para modo satelital
        if (_baseLayer == _BaseLayer.satelital)
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'mx.sao.geoportal_consulta',
            maxZoom: 19,
          ),
        if (importedPolygons.isNotEmpty) PolygonLayer(polygons: importedPolygons),
        if (polygons.isNotEmpty) PolygonLayer(polygons: polygons),
        if (municipalPolygons.isNotEmpty) PolygonLayer(polygons: municipalPolygons),
        if (municipalPolylines.isNotEmpty)
          PolylineLayer(polylines: municipalPolylines),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
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
    final size = bucket.count >= 25
      ? 50.0
        : bucket.count >= 10
        ? 42.0
        : 36.0;

    return Marker(
      point: bucket.center,
      width: size,
      height: size,
      child: GestureDetector(
        onTap: () {
          final targetZoom = (_currentZoom + 1.2).clamp(10.0, 17.0).toDouble();
          _mapCtrl.move(bucket.center, targetZoom);
        },
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${bucket.count}',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: bucket.count >= 100 ? 11 : 12,
                fontWeight: FontWeight.w700,
              ),
            ),
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

  List<_HeatBucket> _mergeOverlappingBuckets(
    List<_HeatBucket> buckets,
    double bucketSize,
  ) {
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
    return Marker(
      point: pos,
      width: 32,
      height: 32,
      child: GestureDetector(
        onTap: () => setState(() => _selectedPredio = p),
        child: Container(
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
          child: const Icon(Icons.location_on, color: Colors.white, size: 16),
        ),
      ),
    );
  }

  Widget _buildTopBar(
    String proyecto,
    List<Predio> predios,
    List<MunicipioLimite> municipios,
    int importedGeoJsonCount,
  ) {
    final liberacionFiltered = _applyLiberacionFilter(predios);
    final filteredPredios = _applyAllFilters(predios);
    final allMunicipioCounts = _countByField(
      liberacionFiltered,
      (p) => p.municipio ?? p.ejido,
      emptyLabel: 'Sin municipio',
    );
    final clasificaCounts = _countByField(
      filteredPredios,
      (p) {
        final tipo = p.tipoPropiedad.toUpperCase().trim();
        if (tipo == 'SOCIAL') return 'Pública';
        if (tipo == 'PRIVADA') return 'Privada';
        return 'Sin clasificación';
      },
      emptyLabel: 'Sin clasificación',
    );
    final segmentoCounts = _countByField(
      liberacionFiltered,
      (p) => _extractSegmentNumber(p.tramo),
      emptyLabel: 'Sin segmento',
    );
    final estatusCounts = <String, int>{
      'Todos': predios.length,
      'Liberados': predios.where(_isLiberado).length,
      'No liberados': predios.where(_isNoLiberado).length,
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
                    'Proyecto: $proyecto',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${filteredPredios.length} predios',
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 11,
                    ),
                  ),
                ),
                if (importedGeoJsonCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD32F2F).withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.35),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'GeoJSON: $importedGeoJsonCount',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
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
                    ref.read(proyectoActivoProvider.notifier).state = null;
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
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => _openAdvancedFiltersPanel(
                    predios,
                    allMunicipioCounts,
                    clasificaCounts,
                    segmentoCounts,
                    estatusCounts,
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
                    _segmentoQuery.isEmpty &&
                            _selectedMunicipio == null &&
                            _liberacionFilter == _LiberacionFilter.todos
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
          ],
        ),
      ),
    );
  }

  Future<void> _openAdvancedFiltersPanel(
    List<Predio> predios,
    Map<String, int> allMunicipioCounts,
    Map<String, int> clasificaCounts,
    Map<String, int> segmentoCounts,
    Map<String, int> estatusCounts,
  ) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar filtros avanzados',
      barrierColor: Colors.black45,
      pageBuilder: (_, __, ___) {
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
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _countSection(
                      title: 'Estatus',
                      counts: estatusCounts,
                      selectedLabel: _liberacionFilterLabel(_liberacionFilter),
                      onChipTap: (estatus) {
                        setState(() {
                          _liberacionFilter = _liberacionFilterFromLabel(estatus);
                          _selectedPredio = null;
                          _selectedMunicipio = null;
                          _lastFocusedMunicipioKey = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _countSection(
                      title: 'Segmentos',
                      counts: segmentoCounts,
                      selectedLabel:
                          _segmentoQuery.isEmpty ? null : _segmentoQuery,
                      onChipTap: (segmento) {
                        setState(() {
                          if (_segmentoQuery == segmento) {
                            _segmentoQuery = '';
                          } else {
                            _segmentoQuery = segmento;
                          }
                          _selectedPredio = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _countSection(
                      title: 'Municipios',
                      counts: allMunicipioCounts,
                      selectedLabel: _selectedMunicipio,
                      onChipTap: (municipio) {
                        setState(() {
                          if (municipio == 'Sin municipio') {
                            _selectedMunicipio = 'Sin municipio';
                          } else if (_selectedMunicipio == municipio) {
                            _selectedMunicipio = null;
                          } else {
                            _selectedMunicipio = municipio;
                          }
                          _lastFocusedMunicipioKey = null;
                          _selectedPredio = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _countSection(
                      title: 'Clasificación',
                      counts: clasificaCounts,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() {
                              _liberacionFilter = _LiberacionFilter.todos;
                              _segmentoQuery = '';
                              _selectedMunicipio = null;
                              _selectedPredio = null;
                              _lastFocusedMunicipioKey = null;
                            }),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withOpacity(0.45)),
                            ),
                            child: const Text('Limpiar'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
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
                      '${_applyAllFilters(predios).length} predios visibles',
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
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? Colors.white.withOpacity(0.95)
            : Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(12),
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
    );
    if (onTap == null) return chip;
    return GestureDetector(onTap: onTap, child: chip);
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
                  _estadoChip('Identificación', predio.identificacion),
                  _estadoChip('Levantamiento', predio.levantamiento),
                  _estadoChip('COP firmado', predio.cop),
                  _estadoChip('Negociación', predio.negociacion),
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
    final type = geo['type'] as String?;
    if (type == 'Polygon') {
      final coords = geo['coordinates'] as List?;
      if (coords == null || coords.isEmpty) return [];
      return [_toLatLngs(coords[0] as List)];
    } else if (type == 'MultiPolygon') {
      final multiCoords = geo['coordinates'] as List?;
      if (multiCoords == null) return [];
      return multiCoords
          .map((poly) => _toLatLngs((poly as List)[0] as List))
          .toList();
    }
    return [];
  }

  List<LatLng> _toLatLngs(List raw) {
    return raw.map((c) {
      final coord = c as List;
      return LatLng(
        (coord[1] as num).toDouble(),
        (coord[0] as num).toDouble(),
      );
    }).toList();
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
    final liberacion = _applyLiberacionFilter(predios);
    final municipio = _selectedMunicipio;
    final withMunicipio = municipio == null
        ? liberacion
        : liberacion.where((p) {
      final value = (p.municipio ?? p.ejido ?? '').trim();
      if (municipio == 'Sin municipio') return value.isEmpty;
      final selectedKey = _normalizeMunicipioName(municipio);
      return _normalizeMunicipioName(value) == selectedKey;
    }).toList();

    final query = _extractSegmentNumber(_segmentoQuery);
    if (query.isEmpty) return withMunicipio;

    return withMunicipio.where((p) {
      final segmento = _extractSegmentNumber(p.tramo);
      return segmento == query;
    }).toList();
  }

  String _extractSegmentNumber(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return '';

    final match = RegExp(r'\d+').firstMatch(raw);
    if (match == null) return '';
    return match.group(0) ?? '';
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
    }
    return points;
  }

  bool _isLiberado(Predio p) =>
      _normalizedStatus(p.estatus) == 'liberado' || p.cop;

  bool _isNoLiberado(Predio p) =>
      _normalizedStatus(p.estatus) == 'no_liberado' ||
      (!_isLiberado(p) && (p.identificacion || p.levantamiento || p.negociacion));

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
    if (zoom >= 15) return 0;
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
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
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
