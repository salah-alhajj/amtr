#!/usr/bin/env python3
import os
from collections import deque
from PIL import Image

def generate_sharp_square_logo():
    """
    Reconstructs the logo with sharp 90-degree square corners (unrounded).
    Fills corner cutouts with the natural background blue gradient so that
    corners are completely sharp and square without any pre-rounded masks.
    Systems (iOS, Android, etc.) will apply their own clipping and corner rounding.
    """
    src_path = '/tmp/original_icon.jpg'
    if not os.path.exists(src_path):
        raise FileNotFoundError(f"Source icon not found at {src_path}")

    orig = Image.open(src_path).convert('RGB')
    # Exact square bounds of the blue logo tile
    tile = orig.crop((180, 180, 844, 844)) # size: (664, 664)
    w, h = tile.size
    pixels = tile.load()

    # Identify corner cutouts (non-blue background) in the 4 corners
    is_corner = [[False]*h for _ in range(w)]
    for x in range(w):
        for y in range(h):
            in_tl = (x < 180 and y < 180)
            in_tr = (x > w - 180 and y < 180)
            in_bl = (x < 180 and y > h - 180)
            in_br = (x > w - 180 and y > h - 180)
            if in_tl or in_tr or in_bl or in_br:
                r, g, b = pixels[x, y]
                # High luminance / background pixels
                if r > 115 and g > 115:
                    is_corner[x][y] = True

    # BFS outward from boundary of non-corner to fill is_corner pixels with edge colors
    q = deque()
    filled = [[not is_corner[x][y] for y in range(h)] for x in range(w)]

    for x in range(w):
        for y in range(h):
            if not is_corner[x][y]:
                for dx, dy in ((1,0), (-1,0), (0,1), (0,-1)):
                    nx, ny = x+dx, y+dy
                    if 0 <= nx < w and 0 <= ny < h and is_corner[nx][ny]:
                        q.append((x, y))
                        break

    while q:
        cx, cy = q.popleft()
        for dx, dy in ((1,0), (-1,0), (0,1), (0,-1)):
            nx, ny = cx+dx, cy+dy
            if 0 <= nx < w and 0 <= ny < h and is_corner[nx][ny] and not filled[nx][ny]:
                pixels[nx, ny] = pixels[cx, cy]
                filled[nx][ny] = True
                q.append((nx, ny))

    # Smooth the infilled corners using 8 iterations of local averaging
    for _ in range(8):
        temp = [[pixels[x, y] for y in range(h)] for x in range(w)]
        for x in range(w):
            for y in range(h):
                if is_corner[x][y]:
                    neighbors = []
                    for dx in (-1, 0, 1):
                        for dy in (-1, 0, 1):
                            nx, ny = x+dx, y+dy
                            if 0 <= nx < w and 0 <= ny < h:
                                neighbors.append(temp[nx][ny])
                    avg_r = sum(c[0] for c in neighbors) // len(neighbors)
                    avg_g = sum(c[1] for c in neighbors) // len(neighbors)
                    avg_b = sum(c[2] for c in neighbors) // len(neighbors)
                    pixels[x, y] = (avg_r, avg_g, avg_b)

    # Scale up to high-resolution 1024x1024 sharp square image
    sharp_logo = tile.resize((1024, 1024), Image.Resampling.LANCZOS)
    return sharp_logo

def main():
    print("Generating sharp 90-degree square logo...")
    sharp_logo = generate_sharp_square_logo()

    # 1. In-app master PNG: Sharp 90-degree corners, completely square, zero margins
    sharp_logo_rgba = sharp_logo.convert('RGBA')
    sharp_logo_rgba.save('assets/icons/amtr_audit_icon.png', 'PNG', optimize=True)
    print("Saved sharp unrounded assets/icons/amtr_audit_icon.png (corners are 90-degree sharp).")

    # Ensure white background backup JPEG is removed
    jpg_backup = 'assets/icons/amtr_audit_icon.jpg'
    if os.path.exists(jpg_backup):
        os.remove(jpg_backup)
        print(f"Removed {jpg_backup}")

    # 2. iOS AppIcon (all 15 sizes, sharp 90-degree square, system clips squircle)
    ios_base_dir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    os.makedirs(ios_base_dir, exist_ok=True)
    ios_sizes = {
        'Icon-App-1024x1024@1x.png': 1024,
        'Icon-App-83.5x83.5@2x.png': 167,
        'Icon-App-76x76@2x.png': 152,
        'Icon-App-76x76@1x.png': 76,
        'Icon-App-60x60@3x.png': 180,
        'Icon-App-60x60@2x.png': 120,
        'Icon-App-40x40@3x.png': 120,
        'Icon-App-40x40@2x.png': 80,
        'Icon-App-40x40@1x.png': 40,
        'Icon-App-29x29@3x.png': 87,
        'Icon-App-29x29@2x.png': 58,
        'Icon-App-29x29@1x.png': 29,
        'Icon-App-20x20@3x.png': 60,
        'Icon-App-20x20@2x.png': 40,
        'Icon-App-20x20@1x.png': 20,
    }
    for filename, sz in ios_sizes.items():
        out_path = os.path.join(ios_base_dir, filename)
        resized = sharp_logo.resize((sz, sz), Image.Resampling.LANCZOS)
        resized.save(out_path, 'PNG', optimize=True)
    print("Generated all iOS AppIcon sizes with sharp 90-degree square corners.")

    # 3. Android launcher icons (Legacy + Adaptive)
    # Legacy: Sharp 90-degree square icons
    android_legacy_sizes = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192,
    }
    res_dir = 'android/app/src/main/res'
    for folder, sz in android_legacy_sizes.items():
        folder_path = os.path.join(res_dir, folder)
        os.makedirs(folder_path, exist_ok=True)
        resized = sharp_logo_rgba.resize((sz, sz), Image.Resampling.LANCZOS)
        resized.save(os.path.join(folder_path, 'ic_launcher.png'), 'PNG', optimize=True)

    # Adaptive icons foreground
    adaptive_sizes = {
        'mipmap-mdpi': 108,
        'mipmap-hdpi': 162,
        'mipmap-xhdpi': 216,
        'mipmap-xxhdpi': 324,
        'mipmap-xxxhdpi': 432,
    }
    for folder, sz in adaptive_sizes.items():
        folder_path = os.path.join(res_dir, folder)
        # Place centered sharp icon within adaptive safe area (72%)
        canvas = Image.new('RGBA', (sz, sz), (0, 0, 0, 0))
        target_sz = int(sz * 0.72)
        resized = sharp_logo_rgba.resize((target_sz, target_sz), Image.Resampling.LANCZOS)
        pos = (sz - target_sz) // 2
        canvas.paste(resized, (pos, pos), resized)
        canvas.save(os.path.join(folder_path, 'ic_launcher_foreground.png'), 'PNG', optimize=True)

    print("Generated Android launcher icons with sharp corners.")

    # 4. Web Icons
    web_dir = 'web'
    web_icons_dir = 'web/icons'
    os.makedirs(web_icons_dir, exist_ok=True)
    sharp_logo_rgba.resize((32, 32), Image.Resampling.LANCZOS).save(os.path.join(web_dir, 'favicon.png'), 'PNG', optimize=True)
    sharp_logo_rgba.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, 'Icon-192.png'), 'PNG', optimize=True)
    sharp_logo_rgba.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, 'Icon-512.png'), 'PNG', optimize=True)
    # Maskable PWA
    for sz in (192, 512):
        canvas = Image.new('RGBA', (sz, sz), (15, 36, 139, 255))
        target_sz = int(sz * 0.72)
        resized = sharp_logo_rgba.resize((target_sz, target_sz), Image.Resampling.LANCZOS)
        pos = (sz - target_sz) // 2
        canvas.paste(resized, (pos, pos), resized)
        canvas.save(os.path.join(web_icons_dir, f'Icon-maskable-{sz}.png'), 'PNG', optimize=True)
    print("Generated Web icons with sharp corners.")

    # 5. Windows app_icon.ico
    win_res_dir = 'windows/runner/resources'
    os.makedirs(win_res_dir, exist_ok=True)
    ico_256 = sharp_logo_rgba.resize((256, 256), Image.Resampling.LANCZOS)
    ico_path = os.path.join(win_res_dir, 'app_icon.ico')
    ico_256.save(ico_path, format='ICO', sizes=[(16,16), (24,24), (32,32), (48,48), (64,64), (128,128), (256,256)])
    print("Generated Windows app_icon.ico with sharp corners.")

if __name__ == '__main__':
    main()
