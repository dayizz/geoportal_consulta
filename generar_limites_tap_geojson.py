import json
import re
from collections import defaultdict
from pathlib import Path
from typing import Any, Dict, List, Tuple

INPUT_PATH = Path('assets/data/TAP_25_05_2026.geojson')
OUTPUT_PATH = Path('assets/data/TAP_LIMITES_MUNICIPALES_ESTATALES.geojson')


def _clean(value: Any) -> str:
    return str(value or '').strip()


def _norm_text(value: str) -> str:
    return (
        _clean(value)
        .lower()
        .replace('á', 'a')
        .replace('é', 'e')
        .replace('í', 'i')
        .replace('ó', 'o')
        .replace('ú', 'u')
        .replace('ü', 'u')
    )


def _slug(value: str) -> str:
    s = _norm_text(value)
    s = re.sub(r'[^a-z0-9]+', '_', s)
    return s.strip('_') or 'sin_dato'


def _extract_polygons(geometry: Dict[str, Any]) -> List[List[List[List[float]]]]:
    gtype = geometry.get('type')
    coords = geometry.get('coordinates')
    if gtype == 'Polygon' and isinstance(coords, list):
        return [coords]
    if gtype == 'MultiPolygon' and isinstance(coords, list):
        return coords
    return []


def _canonical_municipio(value: str) -> str:
    raw = _clean(value)
    if not raw:
        return ''
    lower = raw.lower()
    return ' '.join(part.capitalize() for part in lower.split())


def _canonical_estado(value: str) -> str:
    raw = _clean(value)
    if not raw:
        return ''
    lower = raw.lower()
    return ' '.join(part.capitalize() for part in lower.split())


def main() -> None:
    if not INPUT_PATH.exists():
        raise FileNotFoundError(f'No existe {INPUT_PATH}')

    data = json.loads(INPUT_PATH.read_text(encoding='utf-8'))
    features = data.get('features', [])

    municipio_geoms: Dict[Tuple[str, str], List[List[List[List[float]]]]] = defaultdict(list)
    estado_geoms: Dict[str, List[List[List[List[float]]]]] = defaultdict(list)

    for feature in features:
        props = feature.get('properties', {}) or {}
        geometry = feature.get('geometry', {}) or {}
        polygons = _extract_polygons(geometry)
        if not polygons:
            continue

        municipio = _canonical_municipio(props.get('MUNICIPIO'))
        estado = _canonical_estado(props.get('ESTADO'))

        if municipio:
            municipio_geoms[(municipio, estado)].extend(polygons)
        if estado:
            estado_geoms[estado].extend(polygons)

    out_features: List[Dict[str, Any]] = []

    for (municipio, estado), polygons in sorted(municipio_geoms.items()):
        if not polygons:
            continue
        out_features.append(
            {
                'type': 'Feature',
                'properties': {
                    'id': f"MUN_{_slug(estado)}_{_slug(municipio)}",
                    'nivel': 'municipio',
                    'nombre': municipio,
                    'municipio': municipio,
                    'estado': estado,
                    'proyecto': 'TAP',
                },
                'geometry': {
                    'type': 'MultiPolygon',
                    'coordinates': polygons,
                },
            }
        )

    for estado, polygons in sorted(estado_geoms.items()):
        if not polygons:
            continue
        out_features.append(
            {
                'type': 'Feature',
                'properties': {
                    'id': f"EDO_{_slug(estado)}",
                    'nivel': 'estado',
                    'nombre': estado,
                    'estado': estado,
                    'proyecto': 'TAP',
                },
                'geometry': {
                    'type': 'MultiPolygon',
                    'coordinates': polygons,
                },
            }
        )

    output = {
        'type': 'FeatureCollection',
        'name': 'TAP_LIMITES_MUNICIPALES_ESTATALES',
        'features': out_features,
    }

    OUTPUT_PATH.write_text(json.dumps(output, ensure_ascii=False), encoding='utf-8')

    total_municipios = len(municipio_geoms)
    total_estados = len(estado_geoms)
    print(f'features_entrada={len(features)}')
    print(f'municipios_detectados={total_municipios}')
    print(f'estados_detectados={total_estados}')
    print(f'features_salida={len(out_features)}')
    print(f'archivo_salida={OUTPUT_PATH}')


if __name__ == '__main__':
    main()
