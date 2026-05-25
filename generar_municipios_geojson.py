import json
from collections import defaultdict
from shapely.geometry import shape, mapping, MultiPolygon
from shapely.ops import unary_union

# Archivos de entrada
segment_files = [
    "assets/data/TSN_SEG_13.geojson",
    "assets/data/TSN_SEG_16_17.geojson",
    "assets/data/TSN_SEG_18.geojson"
]

municipios = defaultdict(list)

# Extraer municipios y geometrías
for file in segment_files:
    with open(file, encoding="utf-8") as f:
        data = json.load(f)
        for feat in data["features"]:
            props = feat.get("properties", {})
            municipio = props.get("municipio") or props.get("MUNICIPIO") or props.get("nom_mun") or props.get("NOM_MUN")
            if municipio and feat.get("geometry"):
                municipios[municipio].append(shape(feat["geometry"]))

# Unir geometrías por municipio
features = []
for nombre, geoms in municipios.items():
    union = unary_union(geoms)
    if union.geom_type == "Polygon":
        union = MultiPolygon([union])
    features.append({
        "type": "Feature",
        "properties": {"municipio": nombre},
        "geometry": mapping(union)
    })

# Crear FeatureCollection
out = {
    "type": "FeatureCollection",
    "features": features
}

with open("assets/data/municipios.geojson", "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False)

print(f"Generado municipios.geojson con {len(features)} municipios.")
