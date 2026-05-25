sources = {


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
