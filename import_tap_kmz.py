import json
import re
import zipfile
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict
from pathlib import Path
from typing import Dict, List, Optional

from shapely.geometry import Polygon, shape

KMZ_PATH = Path('/Users/jorgeluispriegocruz/Downloads/TAP_25.05.2026_.kmz')
COP_KML_PATH = Path('/Users/jorgeluispriegocruz/Downloads/COPS_KML_TAP.kml')
OUTPUT_PATH = Path('assets/data/TAP_25_05_2026.geojson')

NS = {'k': 'http://www.opengis.net/kml/2.2'}


def _tag_name(element: ET.Element) -> str:
    return element.tag.rsplit('}', 1)[-1]


def _clean_text(value: str) -> str:
    return (value or '').strip()


def _normalize_key(value: str) -> str:
    key = _clean_text(value)
    key = key.replace('\n', ' ')
    key = re.sub(r'\s+', ' ', key)
    return key


def _get_first(props: Dict[str, str], candidates: List[str]) -> str:
    for key in candidates:
        if key in props and _clean_text(props[key]):
            return _clean_text(props[key])
    return ''


def _normalize_cop(value: str) -> str:
    raw = _clean_text(value).lower()
    if not raw:
        return 'NO'
    positives = {
        'si', 's\u00ed', 'yes', 'true', '1', 'firmado', 'convenio firmado',
        'aprobado', 'ok', 'cop', 'aop'
    }
    negatives = {
        'no', 'false', '0', 'pendiente', 'sin convenio', 'no firmado'
    }
    if raw in positives:
        return 'COP'
    if raw in negatives:
        return 'NO'
    if 'firm' in raw or 'cop' in raw or 'aop' in raw:
        return 'COP'
    return 'NO'


def _normalize_estatus(raw_estatus: str, cop_value: str) -> str:
    raw = _clean_text(raw_estatus).lower()
    if raw:
        if 'liber' in raw:
            return 'Liberado'
        if 'negocia' in raw:
            return 'En negociaci\u00f3n'
        if 'sin avance' in raw:
            return 'Sin avance'
        if 'no liber' in raw:
            return 'No liberado'
        return _clean_text(raw_estatus)
    return 'Liberado' if cop_value == 'COP' else 'No liberado'


def _extract_tap_prefix(clave: str) -> str:
    raw = _clean_text(clave).upper()
    match = re.search(r'\bAP-([A-Z]{3})-', raw)
    if not match:
        return ''
    return match.group(1)


def _parse_coordinates(text: str) -> List[List[float]]:
    if not text:
        return []
    coords = []
    for token in text.strip().split():
        parts = token.split(',')
        if len(parts) < 2:
            continue
        try:
            lon = float(parts[0])
            lat = float(parts[1])
        except ValueError:
            continue
        coords.append([lon, lat])
    return coords


def _parse_polygon(pm: ET.Element) -> Optional[Dict]:
    poly = pm.find('.//k:Polygon', NS)
    if poly is None:
        return None

    rings = []
    outer = poly.find('k:outerBoundaryIs/k:LinearRing/k:coordinates', NS)
    if outer is not None and outer.text:
        outer_coords = _parse_coordinates(outer.text)
        if outer_coords:
            rings.append(outer_coords)

    for inner in poly.findall('k:innerBoundaryIs/k:LinearRing/k:coordinates', NS):
        if inner.text:
            inner_coords = _parse_coordinates(inner.text)
            if inner_coords:
                rings.append(inner_coords)

    if not rings:
        return None

    return {
        'type': 'Polygon',
        'coordinates': rings,
    }


def _iter_placemarks(
    node: ET.Element,
    folder_path: Optional[List[str]] = None,
):
    current_path = list(folder_path or [])
    tag_name = _tag_name(node)

    if tag_name == 'Folder':
        name_node = node.find('k:name', NS)
        folder_name = _clean_text(name_node.text if name_node is not None else '')
        if folder_name:
            current_path.append(folder_name)

    if tag_name == 'Placemark':
        yield node, current_path
        return

    for child in list(node):
        child_tag = _tag_name(child)
        if child_tag in {'Document', 'Folder', 'Placemark'}:
            yield from _iter_placemarks(child, current_path)


def _is_nucleo_agrario_folder(folder_path: List[str]) -> bool:
    return any(_clean_text(name).upper() == 'NUCLEOS AGRARIOS' for name in folder_path)


def _load_cop_polygons() -> List[Polygon]:
    if not COP_KML_PATH.exists():
        return []

    with COP_KML_PATH.open('rb') as fh:
        root = ET.parse(fh).getroot()

    polygons = []
    for coordinates_node in root.iter():
        if not coordinates_node.tag.endswith('coordinates'):
            continue

        raw_coordinates = _clean_text(coordinates_node.text or '')
        if not raw_coordinates:
            continue

        points = []
        for token in raw_coordinates.split():
            parts = token.split(',')
            if len(parts) < 2:
                continue
            try:
                lon = float(parts[0])
                lat = float(parts[1])
            except ValueError:
                continue
            points.append((lon, lat))

        if len(points) < 3:
            continue
        if points[0] == points[-1]:
            points = points[:-1]

        polygon = Polygon(points)
        if polygon.is_valid and polygon.area > 0:
            polygons.append(polygon)

    return polygons


def _placemark_properties(pm: ET.Element) -> Dict[str, str]:
    props: Dict[str, str] = {}
    ext = pm.find('k:ExtendedData', NS)
    if ext is None:
        return props

    for data in ext.findall('.//k:Data', NS):
        key = _normalize_key(data.attrib.get('name', ''))
        if not key:
            continue
        value_node = data.find('k:value', NS)
        value = _clean_text(value_node.text if value_node is not None else '')
        props[key] = value

    return props


def convert() -> None:
    if not KMZ_PATH.exists():
        raise FileNotFoundError(f'No existe el archivo KMZ: {KMZ_PATH}')

    with zipfile.ZipFile(KMZ_PATH, 'r') as zf:
        kml_bytes = zf.read('doc.kml')

    root = ET.fromstring(kml_bytes)
    placemark_entries = list(_iter_placemarks(root))
    placemarks = [pm for pm, _ in placemark_entries]

    rows = []
    skipped_non_polygon = 0

    for pm, folder_path in placemark_entries:
        geometry = _parse_polygon(pm)
        if geometry is None:
            skipped_non_polygon += 1
            continue

        raw = _placemark_properties(pm)
        name_node = pm.find('k:name', NS)
        name = _clean_text(name_node.text if name_node is not None else '')

        frente = _get_first(raw, ['Frente', 'frente'])
        municipio = _get_first(raw, ['Municipio', 'MUNICIPIO'])
        estado = _get_first(raw, ['Estado', 'ESTADO', 'Entidad', 'ENTIDAD'])
        raw_estatus = _get_first(raw, ['Estatus_de_LDV', 'ESTATUS', 'estatus'])
        raw_cop = _get_first(raw, ['COP', 'Cop', 'cop', 'Convenio_firmado'])
        cop = _normalize_cop(raw_cop)
        estatus = _normalize_estatus(raw_estatus, cop)
        clave = _get_first(raw, ['Nomenclatura_SEDATU', 'NOM_SEDATU', 'Nucleo8', 'fid'])
        layer_name = folder_path[-1] if folder_path else ''
        es_nucleo_agrario = _is_nucleo_agrario_folder(folder_path)

        properties = {
            'ID': _get_first(raw, ['id', 'ID', 'fid']) or clave or name,
            'CLAVE': clave or name,
            'NOM_SEDATU': _get_first(raw, ['NOM_SEDATU']) or name,
            'PROYECTO': 'TAP',
            'FRENTE': frente,
            'MUNICIPIO': municipio,
            'ESTADO': estado,
            'ESTATUS': estatus,
            'COP': cop,
            'TIPO_DE_PROPIEDAD': _get_first(raw, ['Tipo_de_Propiedad_']),
            'CUENTA_CATASTRAL': _get_first(raw, ['Cuenta_Catastral']),
            'TITULAR_REGISTRAL': _get_first(raw, ['Titular_Registral']),
            'FOLIO_ELECTRONICO': _get_first(raw, ['Folio_Electr__nico']),
            'SUJETO_AGRARIO': _get_first(raw, ['Sujeto_Agrario', 'Suj_Agrar']),
            'POSEEDOR': _get_first(raw, ['Poseedor']),
            'ULTIMO_ACTO_REGISTRADO': _get_first(raw, ['Ultimo_acto_registrado']),
            'EJIDO': _get_first(raw, ['Ejido']),
            'PARCELA': _get_first(raw, ['Parcela', 'Parcela_o_']),
            'VALOR_CATASTRAL': _get_first(raw, ['Valor_Catastral']),
            'VALOR_COMERCIAL': _get_first(raw, ['Valor_Comercial']),
            'MONTO_TOTAL': _get_first(raw, ['Monto_tota']),
            'PAGO': _get_first(raw, ['Pago']),
            'ACERCAMIENTO': _get_first(raw, ['Acercamiento']),
            'NEGOCIADO': _get_first(raw, ['Negociado']),
            'CONVENIO_FIRMADO': _get_first(raw, ['Convenio_firmado']),
            'PLANO': _get_first(raw, ['Plano']),
            'MEDICION_POLIGONO': _get_first(raw, ['Medici__n_pol__gono']),
            'MEDICION_BDT': _get_first(raw, ['Medici__n_BDT']),
            'SUP_QGIS': _get_first(raw, ['SUP_QGIS']),
            'SUP_AFECT': _get_first(raw, ['Sup_Afect']),
            'SUP_TOTAL': _get_first(raw, ['Sup_Total']),
            'SUP_M2_AU': _get_first(raw, ['Sup m2 [Au']),
            'M2': _get_first(raw, ['M2']),
            'CENTROIDE_X': _get_first(raw, ['Cent X']),
            'CENTROIDE_Y': _get_first(raw, ['Cent Y']),
            'ESTACION': _get_first(raw, ['ESTACION']),
            'TREN': _get_first(raw, ['Tren']),
            'TIPO_DE_PREDIO': _get_first(raw, ['Tipo_de_pr']),
            'ANT_NOM_SEDATU': _get_first(raw, ['ANT_NOM_SE']),
            'NOMBRE_E': _get_first(raw, ['Nombre___E']),
            'PLAZO': _get_first(raw, ['Plazo_para']),
            'FECHA_COP': _get_first(raw, ['Fecha COP']),
            'FECHA_E': _get_first(raw, ['Fecha_de_e']),
            'FECHA_F': _get_first(raw, ['Fecha_de_f']),
            'FECHA_O': _get_first(raw, ['Fecha_de_o']),
            'FECHA_P': _get_first(raw, ['Fecha_de_p']),
            'FECHA_S': _get_first(raw, ['Fecha_de_s']),
            'FECHAS_DE': _get_first(raw, ['Fechas_de_']),
            'ENTREGADO': _get_first(raw, ['Entregado_']),
            'FUENTE': 'TAP_25.05.2026_.kmz',
            'CAPA_ORIGEN': layer_name,
            'ES_NUCLEO_AGRARIO': 'SI' if es_nucleo_agrario else 'NO',
        }

        rows.append({'properties': properties, 'geometry': geometry})

    cop_polygons = _load_cop_polygons()
    cop_matches = set()
    if cop_polygons:
        geo_shapes = []
        for index, row in enumerate(rows):
            geometry = row['geometry']
            if geometry is None:
                continue
            try:
                geo_shapes.append((index, shape(geometry)))
            except Exception:
                continue

        for cop_polygon in cop_polygons:
            best_index = None
            best_ratio = 0.0
            for index, geo_shape in geo_shapes:
                intersection = cop_polygon.intersection(geo_shape)
                if intersection.is_empty:
                    continue
                ratio = intersection.area / cop_polygon.area if cop_polygon.area else 0.0
                if ratio > best_ratio:
                    best_ratio = ratio
                    best_index = index

            if best_index is not None and best_ratio >= 0.95:
                cop_matches.add(best_index)

        for index in cop_matches:
            rows[index]['properties']['C.O.P'] = 'COP'
            rows[index]['properties']['COP'] = 'COP'

    # Inferencia de municipio/estado por prefijo AP-XXX- cuando falten datos.
    municipio_by_prefix: Dict[str, Counter] = defaultdict(Counter)
    estado_by_prefix: Dict[str, Counter] = defaultdict(Counter)
    estado_by_municipio: Dict[str, Counter] = defaultdict(Counter)

    for row in rows:
        props = row['properties']
        prefix = _extract_tap_prefix(props.get('CLAVE', '') or props.get('NOM_SEDATU', ''))
        municipio = _clean_text(props.get('MUNICIPIO', ''))
        estado = _clean_text(props.get('ESTADO', ''))

        if prefix and municipio:
            municipio_by_prefix[prefix][municipio] += 1
        if prefix and estado:
            estado_by_prefix[prefix][estado] += 1
        if municipio and estado:
            estado_by_municipio[municipio][estado] += 1

    for row in rows:
        props = row['properties']
        prefix = _extract_tap_prefix(props.get('CLAVE', '') or props.get('NOM_SEDATU', ''))
        municipio = _clean_text(props.get('MUNICIPIO', ''))
        estado = _clean_text(props.get('ESTADO', ''))

        if not municipio and prefix in municipio_by_prefix and municipio_by_prefix[prefix]:
            props['MUNICIPIO'] = municipio_by_prefix[prefix].most_common(1)[0][0]
            municipio = props['MUNICIPIO']

        if not estado:
            if prefix in estado_by_prefix and estado_by_prefix[prefix]:
                props['ESTADO'] = estado_by_prefix[prefix].most_common(1)[0][0]
            elif municipio in estado_by_municipio and estado_by_municipio[municipio]:
                props['ESTADO'] = estado_by_municipio[municipio].most_common(1)[0][0]

    features = []
    for row in rows:
        features.append({
            'type': 'Feature',
            'properties': row['properties'],
            'geometry': row['geometry'],
        })

    fc = {
        'type': 'FeatureCollection',
        'name': 'TAP_25_05_2026',
        'features': features,
    }

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(fc, ensure_ascii=False), encoding='utf-8')

    print(f'placemarks_total={len(placemarks)}')
    print(f'features_poligono_exportadas={len(features)}')
    print(f'features_no_poligono_omitidas={skipped_non_polygon}')
    print(f'features_cop_actualizadas={len(cop_matches)}')
    print(f'archivo_salida={OUTPUT_PATH}')


if __name__ == '__main__':
    convert()
