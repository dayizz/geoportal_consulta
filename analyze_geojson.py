
import os
import json

# Lista de archivos geojson a analizar
files = [
    "/Users/dayana/Documents/ATTRAPI/TSNL/TSNL_19_05_26/SUBIR/TSN_SEG_18.geojson",
    "/Users/dayana/Documents/ATTRAPI/TSNL/TSNL_19_05_26/SUBIR/TSN_SEG_16_17.geojson",
    "/Users/dayana/Documents/ATTRAPI/TSNL/TSNL_19_05_26/SUBIR/TSN_SEG_13.geojson",
    "/Users/dayana/Documents/ATTRAPI/TSNL/TSNL_19_05_26/SUBIR/ENVOLVENTE_COMPLETA.geojson"
]

results = []
for file_path in files:
    filename = os.path.basename(file_path)
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"Error reading {filename}: {e}")
        continue

    features = data.get('features', [])
    total_features = len(features)
    keys_count = 0
    values_count = 0
    filename_match = "estacion" in filename.lower()

    for feature in features:
        props = feature.get('properties', {})
        if not props:
            continue
        # Check keys
        if any("estacion" in str(k).lower() for k in props.keys()):
            keys_count += 1
        # Check values
        if any("estacion" in str(v).lower() for v in props.values()):
            values_count += 1

    results.append({
        "Archivo": filename,
        "Total": total_features,
        "Keys": keys_count,
        "Values": values_count,
        "Filename": "Sí" if filename_match else "No"
    })

# Print Table
print(f"{'Archivo':<50} | {'Total':<6} | {'Keys':<6} | {'Values':<6} | {'Filename':<8}")
print("-" * 85)
for r in results:
    print(f"{r['Archivo']:<50} | {r['Total']:<6} | {r['Keys']:<6} | {r['Values']:<6} | {r['Filename']:<8}")

# Special check for TSN_SEG_16_17.geojson (nueva ruta)
print("\n--- 10 Features Examples for TSN_SEG_16_17.geojson ---")
tsnl_path = '/Users/dayana/Documents/ATTRAPI/TSNL/TSNL_19_05_26/SUBIR/TSN_SEG_16_17.geojson'
if os.path.exists(tsnl_path):
    with open(tsnl_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
        features = data.get('features', [])
        for i, feat in enumerate(features[:10]):
            print(f"Feature {i+1}: {json.dumps(feat.get('properties'), ensure_ascii=False)}")
