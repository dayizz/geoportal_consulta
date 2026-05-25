# Copia los archivos GeoJSON de assets/data/ a web/assets/data/ antes del build web
# Uso: bash copy_geojson_to_web.sh

set -e

SRC="$(dirname "$0")/assets/data"
DEST="$(dirname "$0")/web/assets/data"

mkdir -p "$DEST"
cp -v "$SRC"/*.geojson "$DEST"/
echo "GeoJSON copiados a $DEST"
