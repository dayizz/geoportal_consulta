import 'dart:convert';

class Predio {
  final String id;
  final String claveCatastral;
  final String? propietarioNombre;
  final String tramo;
  final String tipoPropiedad;
  final String? municipio;
  final String? estado;
  final String? clasificacionAfectacion;
  final String? ejido;
  final double? kmInicio;
  final double? kmFin;
  final double? superficie;
  final bool cop;
  final String? proyecto;
  final bool poligonoInsertado;
  final bool identificacion;
  final bool levantamiento;
  final bool negociacion;
  final String? estatus;
  final double? latitud;
  final double? longitud;
  final Map<String, dynamic>? geometry;
  final DateTime createdAt;

  const Predio({
    required this.id,
    required this.claveCatastral,
    this.propietarioNombre,
    required this.tramo,
    required this.tipoPropiedad,
    this.municipio,
    this.estado,
    this.clasificacionAfectacion,
    this.ejido,
    this.kmInicio,
    this.kmFin,
    this.superficie,
    this.cop = false,
    this.proyecto,
    this.poligonoInsertado = false,
    this.identificacion = false,
    this.levantamiento = false,
    this.negociacion = false,
    this.estatus,
    this.latitud,
    this.longitud,
    this.geometry,
    required this.createdAt,
  });

  factory Predio.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? geometry;
    final geometryRaw = map['geometry'];
    if (geometryRaw != null) {
      if (geometryRaw is String) {
        try {
          geometry = jsonDecode(geometryRaw) as Map<String, dynamic>;
        } catch (_) {
          geometry = null;
        }
      } else if (geometryRaw is Map) {
        geometry = Map<String, dynamic>.from(geometryRaw);
      }
    }

    double? toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.replaceAll(',', '').trim());
      return null;
    }

    bool toBool(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.trim().toLowerCase();
        return s == 'true' || s == '1' || s == 'si' || s == 'sí' || s == 'yes';
      }
      return false;
    }

    final estatusRaw = (map['estatus'] ?? map['ESTATUS'])?.toString().trim();
    final estatusNorm = estatusRaw?.toLowerCase();
    final estatusLiberado = estatusNorm == 'liberado';
    final estatusNoLiberado = estatusNorm == 'no liberado';
    final copFirmado = toBool(map['cop']) || estatusLiberado;
    final identificacionOk =
      copFirmado || estatusNoLiberado || toBool(map['identificacion']);
    final levantamientoOk =
      copFirmado ? true : (estatusNoLiberado ? false : toBool(map['levantamiento']));
    final negociacionOk =
      copFirmado ? true : (estatusNoLiberado ? false : toBool(map['negociacion']));

    return Predio(
      id: map['id'] as String? ?? '',
      claveCatastral: map['clave_catastral'] as String? ??
        map['id_sedatu'] as String? ?? '',
      propietarioNombre: map['propietario_nombre'] as String?,
      tramo: (map['tramo'] ?? map['segmento'] ?? map['SEGMENTO'])?.toString() ??
        'T1',
      tipoPropiedad: map['tipo_propiedad'] as String? ?? 'PRIVADA',
      municipio: (map['municipio'] ?? map['MUNICIPIO'])?.toString(),
      estado: (map['estado'] ?? map['ESTADO'])?.toString(),
      clasificacionAfectacion:
        (map['clasificacion'] ??
          map['CLASIFICACION'] ??
          map['tipo_afectacion'] ??
          map['TIPO_AFECTACION'])
        ?.toString(),
      // Fix: support both 'ejido' and 'EJIDO' keys
      ejido: (map['ejido'] ?? map['EJIDO'])?.toString(),
      kmInicio: toDouble(map['km_inicio']),
      kmFin: toDouble(map['km_fin']),
      superficie: toDouble(map['superficie']),
      cop: copFirmado,
      proyecto: map['proyecto'] as String?,
      poligonoInsertado: toBool(map['poligono_insertado']),
      identificacion: identificacionOk,
      levantamiento: levantamientoOk,
      negociacion: negociacionOk,
      estatus: estatusRaw,
      latitud: toDouble(map['latitud']),
      longitud: toDouble(map['longitud']),
      geometry: geometry,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
        DateTime.now(),
    );
  }

  /// Avance de gestión en porcentaje (0–100)
  int get porcentajeAvance {
    int steps = 0;
    if (identificacion) steps++;
    if (levantamiento) steps++;
    if (cop) steps++;
    if (negociacion) steps++;
    return (steps * 25).clamp(0, 100);
  }

  String get estadoLabel {
    final estatusNorm = estatus?.trim().toLowerCase();
    if (estatusNorm == 'liberado') return 'Liberado';
    if (estatusNorm == 'no liberado') return 'No liberado';
    if (negociacion) return 'Negociación';
    if (cop) return 'COP firmado';
    if (levantamiento) return 'Levantamiento';
    if (identificacion) return 'Identificado';
    return 'Sin gestión';
  }
}
