import json
import os
import glob

def find_estaciones():
    files = glob.glob('assets/data/**/*.geojson', recursive=True)
    results = []
    
    for file_path in files:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
        except Exception as e:
            print(f"Error loading {file_path}: {e}")
            continue
            
        features = data.get('features', [])
        total_features = len(features)
        estacion_features = []
        
        for feature in features:
            props = feature.get('properties', {})
            # Check all keys and values in properties
            found = False
            for k, v in props.items():
                if 'estacion' in str(k).lower() or 'estación' in str(k).lower():
                    found = True
                    break
                if 'estacion' in str(v).lower() or 'estación' in str(v).lower():
                    found = True
                    break
            
            if found:
                estacion_features.append({
                    "id": feature.get("id"),
                    "properties": props
                })
        
        results.append({
            "file": file_path,
            "total_features": total_features,
            "estacion_count": len(estacion_features),
            "examples": estacion_features[:3] # Limit to 3 examples
        })
        
    for res in results:
        print(f"Archivo: {res['file']}")
        print(f"Total features: {res['total_features']}")
        print(f"Features con 'estacion': {res['estacion_count']}")
        if res['estacion_count'] > 0:
            print("Ejemplos:")
            for ex in res['examples']:
                print(f"  - ID: {ex['id']}")
                print(f"    Props: {json.dumps(ex['properties'], ensure_ascii=False)}")
        print("-" * 40)

if __name__ == "__main__":
    find_estaciones()
