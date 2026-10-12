#!/usr/bin/env python3
import os
from collections import deque
from PIL import Image, ImageFilter

def isolate_logo(input_path):
    print(f"Reading source logo from {input_path}...")
    orig = Image.open(input_path).convert('RGB')
    w, h = orig.size
    pixels = orig.load()
    bg = (242, 243, 237)

    # BFS from borders to find background with threshold 58
    is_bg = [[False]*h for _ in range(w)]
    q = deque()
    for x in range(w):
        q.append((x, 0))
        q.append((x, h-1))
        is_bg[x][0] = True
        is_bg[x][h-1] = True
    for y in range(h):
        q.append((0, y))
        q.append((w-1, y))
        is_bg[0][y] = True
        is_bg[w-1][y] = True

    while q:
        cx, cy = q.popleft()
        for nx, ny in ((cx+1, cy), (cx-1, cy), (cx, cy+1), (cx, cy-1)):
            if 0 <= nx < w and 0 <= ny < h and not is_bg[nx][ny]:
                p = pixels[nx, ny]
                diff = sum(abs(p[i] - bg[i]) for i in range(3))
                if diff <= 58:
                    is_bg[nx][ny] = True
                    q.append((nx, ny))

    # Create binary mask
    mask = Image.new('L', (w, h), 0)
    m_pixels = mask.load()
    for x in range(w):
        for y in range(h):
            if not is_bg[x][y]:
                m_pixels[x, y] = 255

    # Subtle gaussian blur on mask for clean antialiased edge
    smooth_mask = mask.filter(ImageFilter.GaussianBlur(radius=0.7))

    rgba = orig.convert('RGBA')
    rgba.putalpha(smooth_mask)

    # Get tight bounding box of alpha
    bbox = rgba.getbbox()
    print(f"Isolated logo bbox: {bbox} (width: {bbox[2]-bbox[0]}, height: {bbox[3]-bbox[1]})")
    cropped = rgba.crop(bbox)
    return cropped

def place_on_canvas(cropped_logo, canvas_size, scale_factor, bg_color=None):
    """
    canvas_size: (w, h) tuple or int
    scale_factor: fraction of canvas that the logo should occupy (e.g. 0.85 for 85%)
    bg_color: None for transparent (RGBA), or (R, G, B) for opaque
    """
    if isinstance(canvas_size, int):
        cw, ch = canvas_size, canvas_size
    else:
        cw, ch = canvas_size

    mode = 'RGBA' if bg_color is None or len(bg_color) == 4 and bg_color[3] < 255 else 'RGB'
    if bg_color is None:
        canvas = Image.new('RGBA', (cw, ch), (0, 0, 0, 0))
    elif mode == 'RGBA':
        canvas = Image.new('RGBA', (cw, ch), bg_color)
    else:
        canvas = Image.new('RGB', (cw, ch), bg_color[:3])

    lw, lh = cropped_logo.size
    max_target_dim = min(cw, ch) * scale_factor
    ratio = min(max_target_dim / lw, max_target_dim / lh)
    nw = max(1, int(lw * ratio))
    nh = max(1, int(lh * ratio))

    resized = cropped_logo.resize((nw, nh), Image.Resampling.LANCZOS)
    pos_x = (cw - nw) // 2
    pos_y = (ch - nh) // 2

    canvas.paste(resized, (pos_x, pos_y), resized)
    return canvas

def main():
    source_icon = 'assets/icons/amtr_audit_icon.jpg'
    cropped_logo = isolate_logo(source_icon)

    # 1. Update in-app assets:
    # High-resolution transparent PNG with minimal safe padding (~92% of 1024x1024)
    app_logo_transparent = place_on_canvas(cropped_logo, 1024, 0.92, bg_color=None)
    app_logo_transparent.save('assets/icons/amtr_audit_icon.png', 'PNG', optimize=True)
    print("Saved assets/icons/amtr_audit_icon.png")

    # High-resolution JPEG with white background and tight padding
    app_logo_jpg = place_on_canvas(cropped_logo, 1024, 0.92, bg_color=(255, 255, 255))
    app_logo_jpg.save('assets/icons/amtr_audit_icon.jpg', 'JPEG', quality=95)
    print("Updated assets/icons/amtr_audit_icon.jpg")

    # 2. iOS AppIcon (all 15 standard sizes, opaque background, safe zone ~84% to fit squircle)
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
        icon_img = place_on_canvas(cropped_logo, sz, 0.84, bg_color=(255, 255, 255))
        icon_img.save(out_path, 'PNG', optimize=True)
    print("Generated all iOS AppIcon sizes.")

    # 3. Android launcher icons (Legacy mipmaps + Adaptive icons)
    # Legacy mipmaps:
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
        # For legacy, provide a clean icon with subtle squircle background or transparent
        legacy_icon = place_on_canvas(cropped_logo, sz, 0.86, bg_color=None)
        legacy_icon.save(os.path.join(folder_path, 'ic_launcher.png'), 'PNG', optimize=True)

    # Android Adaptive foreground (108dp canvas, safe zone 66dp = ~61-66%)
    adaptive_sizes = {
        'mipmap-mdpi': 108,
        'mipmap-hdpi': 162,
        'mipmap-xhdpi': 216,
        'mipmap-xxhdpi': 324,
        'mipmap-xxxhdpi': 432,
    }
    for folder, sz in adaptive_sizes.items():
        folder_path = os.path.join(res_dir, folder)
        fg_icon = place_on_canvas(cropped_logo, sz, 0.64, bg_color=None)
        fg_icon.save(os.path.join(folder_path, 'ic_launcher_foreground.png'), 'PNG', optimize=True)

    # Adaptive icon XML in mipmap-anydpi-v26
    anydpi_dir = os.path.join(res_dir, 'mipmap-anydpi-v26')
    os.makedirs(anydpi_dir, exist_ok=True)
    with open(os.path.join(anydpi_dir, 'ic_launcher.xml'), 'w', encoding='utf-8') as f:
        f.write('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
''')

    # Color resource for adaptive background
    values_dir = os.path.join(res_dir, 'values')
    os.makedirs(values_dir, exist_ok=True)
    colors_xml = os.path.join(values_dir, 'colors.xml')
    with open(colors_xml, 'w', encoding='utf-8') as f:
        f.write('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#FFFFFF</color>
</resources>
''')
    print("Generated Android legacy and adaptive launcher icons.")

    # 4. Web Icons
    web_dir = 'web'
    web_icons_dir = 'web/icons'
    os.makedirs(web_icons_dir, exist_ok=True)
    # Favicon (32x32)
    fav = place_on_canvas(cropped_logo, 32, 0.90, bg_color=None)
    fav.save(os.path.join(web_dir, 'favicon.png'), 'PNG', optimize=True)

    # Icon-192.png & Icon-512.png (PWA standard)
    i192 = place_on_canvas(cropped_logo, 192, 0.88, bg_color=None)
    i192.save(os.path.join(web_icons_dir, 'Icon-192.png'), 'PNG', optimize=True)
    i512 = place_on_canvas(cropped_logo, 512, 0.88, bg_color=None)
    i512.save(os.path.join(web_icons_dir, 'Icon-512.png'), 'PNG', optimize=True)

    # Maskable PWA icons (with 60% safe zone)
    m192 = place_on_canvas(cropped_logo, 192, 0.65, bg_color=(255, 255, 255))
    m192.save(os.path.join(web_icons_dir, 'Icon-maskable-192.png'), 'PNG', optimize=True)
    m512 = place_on_canvas(cropped_logo, 512, 0.65, bg_color=(255, 255, 255))
    m512.save(os.path.join(web_icons_dir, 'Icon-maskable-512.png'), 'PNG', optimize=True)
    print("Generated Web favicon and PWA icons.")

    # 5. Windows app_icon.ico
    win_res_dir = 'windows/runner/resources'
    os.makedirs(win_res_dir, exist_ok=True)
    ico_master = place_on_canvas(cropped_logo, 256, 0.90, bg_color=None)
    ico_path = os.path.join(win_res_dir, 'app_icon.ico')
    ico_master.save(ico_path, format='ICO', sizes=[(16,16), (24,24), (32,32), (48,48), (64,64), (128,128), (256,256)])
    print("Generated Windows multi-resolution app_icon.ico.")

if __name__ == '__main__':
    main()
