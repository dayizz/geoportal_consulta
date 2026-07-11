# BUG #6: Divisor Cero en Algoritmo Point-in-Polygon

**Severidad**: 🟡 MEDIA — Comportamiento indefinido  
**Archivo**: `geoportal_consulta/lib/features/mapa/predios_provider.dart` línea 216  
**Tipo**: División por número muy pequeño / Numeric instability  
**Impacto**: Detección incorrecta de municipio en predios con coordenadas colineales  

---

## Problema

En el algoritmo de "point in polygon" (rayo casting), hay una división potencialmente problemática:

```dart
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
                        ((yj - yi).abs() < 1e-12 ? 1e-12 : (yj - yi)) +  // ← AQUÍ
                    xi);
    if (intersects) inside = !inside;
  }
  return inside;
}
```

---

## El Problema Específico

La línea intenta evitar división por cero:
```dart
((yj - yi).abs() < 1e-12 ? 1e-12 : (yj - yi))
```

**Pero hay un fallo lógico**: Si `yj - yi` es exactamente cero o muy cercano a cero, esto indica que el segmento es **horizontal**.

Para un segmento horizontal:
- La función debería tener lógica especial
- Reemplazar el denominador con `1e-12` causa **resultados numéricos incorrectos**
- El algoritmo de rayo casting falla en edges horizontales

---

## Escenario de Error

### Geometría con línea horizontal
```
Polígono rectangular: (0,0) → (10,0) → (10,10) → (0,10) → (0,0)

Punto a probar: (5, 5)
```

Cuando el rayo llega al segmento horizontal de arriba `(0,10) → (10,10)`:
- `yi = 10, yj = 10` → `yj - yi = 0`
- El algoritmo reemplaza con `1e-12`
- Cálculo: `(xj - xi) * (5 - 10) / 1e-12 + xi`
- Resultado: Número enormemente grande → overflow o comportamiento errótico

---

## Consecuencias

1. **Detección de municipio incorrecta**: Predios asignados a municipio equivocado
2. **Visualización en mapa incorrecto**: Filtros por municipio no funcionan
3. **Datos inconsistentes**: Backend dice municipio X, mapa muestra Y

---

## Solución Correcta

Implementar punto-en-polígono robustos (ray casting mejorado):

```dart
bool _pointInPolygon(LatLng point, List<LatLng> ring) {
  var inside = false;
  
  for (int i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final xi = ring[i].longitude;
    final yi = ring[i].latitude;
    final xj = ring[j].longitude;
    final yj = ring[j].latitude;

    final p_lat = point.latitude;
    final p_lng = point.longitude;

    // Verificación estricta de horizontal
    if ((yi - yj).abs() < 1e-12) {
      // Segmento horizontal - saltar o manejar especialmente
      continue;
    }

    // Ray casting estándar (solo para segmentos no-horizontales)
    final intersects =
        ((yi > p_lat) != (yj > p_lat)) &&
            (p_lng < (xj - xi) * (p_lat - yi) / (yj - yi) + xi);
    
    if (intersects) inside = !inside;
  }
  
  return inside;
}
```

---

## Status

🟡 **IDENTIFICADO Y REPORTADO**  
Pendiente: Implementación de fix (usar algoritmo robustos)

---

## Alternativa: Usar librería especializada

En lugar de implementar punto-en-polígono manual, usar:
```dart
// flutter_polyline_points o similar
import 'package:poly/poly.dart';

bool isPointInPolygon = Poly.isPointInPolygon(point, ring);
```

---

## Nota Importante

El algoritmo actual **probablemente funciona** para la mayoría de polígonos reales porque:
- GeoJSON de municipios tiene segmentos con pendientes razonables
- El threshold `1e-12` es muy pequeño
- Casos verdaderamente horizontales son raros

Pero es un bug latente que podría manifestarse con:
- Polígonos irregulares
- Coordenadas mal formatteadas
- Futuras fuentes de datos diferentes

Recomendación: **Bajo riesgo para producción**, pero **buena práctica implementar fix**

