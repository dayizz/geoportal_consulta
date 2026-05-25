
def deg2num(lat_deg, lon_deg, zoom):
    lat_rad = math.radians(lat_deg)
    n = 2.0 ** zoom
    xtile = int((lon_deg + 180.0) / 360.0 * n)
    ytile = int((1.0 - math.log(math.tan(lat_rad) + (1 / math.cos(lat_rad))) / math.pi) / 2.0 * n)
    return (xtile, ytile)

def get_non_transparent_percentage(url):
    try:
        response = requests.get(url, timeout=10)
        if response.status_code != 200:
            return None
        img = Image.open(io.BytesIO(response.content))
        if img.mode != 'RGBA':
            return 100.0  # If no alpha channel, assume 100% opaque
        
        alpha = img.getchannel('A')
        non_transparent = 0
        total = alpha.width * alpha.height
        for pixel in alpha.getdata():
            if pixel > 0:
                non_transparent += 1
        return (non_transparent / total) * 100
    except Exception as e:
        print(f"Error processing {url}: {e}")
        return None

lat, lon = 20.72, -100.35
zooms = [10, 12, 14, 16]

sources = {
    "World_Reference_Overlay": "https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Reference_Overlay/MapServer/tile/{z}/{y}/{x}"
}

print(f"{'Zoom':<6} | {'Source':<25} | {'Non-Transparent %':<20}")
print("-" * 55)

for z in zooms:
    xtile, ytile = deg2num(lat, lon, z)
    for name, template in sources.items():
        url = template.format(z=z, y=ytile, x=xtile)
        pct = get_non_transparent_percentage(url)
        if pct is not None:
            print(f"{z:<6} | {name:<25} | {pct:>18.2f}%")
        else:
            print(f"{z:<6} | {name:<25} | {'Error/No Tile':>18}")

def deg2num(lat_deg, lon_deg, zoom):
    lat_rad = math.radians(lat_deg)
    n = 2.0 ** zoom
    xtile = int((lon_deg + 180.0) / 360.0 * n)
    ytile = int((1.0 - math.log(math.tan(lat_rad) + (1 / math.cos(lat_rad))) / math.pi) / 2.0 * n)
    return (xtile, ytile)

def get_non_transparent_percentage(url):
    try:
        response = requests.get(url, timeout=10)
        if response.status_code != 200:
            return None
        img = Image.open(io.BytesIO(response.content))
        if img.mode != 'RGBA':
            return 100.0  # If no alpha channel, assume 100% opaque
        
        alpha = img.getchannel('A')
        non_transparent = 0
        total = alpha.width * alpha.height
        for pixel in alpha.getdata():
            if pixel > 0:
                non_transparent += 1
        return (non_transparent / total) * 100
    except Exception as e:
        print(f"Error processing {url}: {e}")
        return None

lat, lon = 20.72, -100.35
zooms = [10, 12, 14, 16]

sources = {
    "World_Reference_Overlay": "https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Reference_Overlay/MapServer/tile/{z}/{y}/{x}"
}

print(f"{'Zoom':<6} | {'Source':<25} | {'Non-Transparent %':<20}")
print("-" * 55)

for z in zooms:
    xtile, ytile = deg2num(lat, lon, z)
    for name, template in sources.items():
        url = template.format(z=z, y=ytile, x=xtile)
        pct = get_non_transparent_percentage(url)
        if pct is not None:
            print(f"{z:<6} | {name:<25} | {pct:>18.2f}%")
        else:
            print(f"{z:<6} | {name:<25} | {'Error/No Tile':>18}")
