import requests
from PIL import Image
import io

url = "https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Reference_Overlay/MapServer/tile/16/28097/14498"
r = requests.get(url)
print(f"Status: {r.status_code}")
print(f"Content-Type: {r.headers.get('Content-Type')}")
img = Image.open(io.BytesIO(r.content))
print(f"Mode: {img.mode}, Size: {img.size}")
if img.mode == 'RGBA':
    extrema = img.getchannel('A').getextrema()
    print(f"Alpha range: {extrema}")
