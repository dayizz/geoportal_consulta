import math
import requests
from PIL import Image
import io

def deg2num(lat_deg, lon_deg, zoom):
    lat_rad = math.radians(lat_deg)
    n = 2**zoom
    xtile = int((lon_deg + 180.0) / 360.0 * n)
    ytile = int((1.0 - math.log(math.tan(lat_rad) + (1 / math.cos(lat_rad))) / math.pi) / 2.0 * n)
    return (xtile, ytile)

def analyze_image(url):
    try:
        headers = {'User-Agent': 'Mozilla/5.0'}
        response = requests.get(url, headers=headers, timeout=10)
        if response.status_code != 200:
            return None
        img = Image.open(io.BytesIO(response.content)).convert('RGBA')
        pixels = img.load()
        width, height = img.size
        count = 0
        for y in range(height):
            for x in range(width):
                r, g, b, a = pixels[x, y]
                # Not transparent and not pure white
                if a > 0 and not (r == 255 and g == 255 and b == 255):
                    count += 1
        return (count / (width * height)) * 100
    except Exception as e:
        return None

lat, lon = 20.72, -100.35
zooms = [10, 12, 14, 16]

sources = {
    "ArcGIS_Transp": "https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Transportation/MapServer/tile/{z}/{y}/{x}",
    "ArcGIS_Bound": "https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}",
    "Carto_Labels": "https://basemaps.cartocdn.com/light_only_labels/{z}/{x}/{y}.png"
}

print(f"{'Source':<15} | {'Z':<2} | {'X':<7} | {'Y':<7} | {'Content %'}")
print("-" * 50)

for name, url_template in sources.items():
    for z in zooms:
        x, y = deg2num(lat, lon, z)
        url = url_template.format(z=z, x=x, y=y)
        pct = analyze_image(url)
        if pct is not None:
            print(f"{name:<15} | {z:<2} | {x:<7} | {y:<7} | {pct:.2f}%")
        else:
            print(f"{name:<15} | {z:<2} | {x:<7} | {y:<7} | Error/Empty")
