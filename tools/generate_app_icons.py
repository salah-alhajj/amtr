#!/usr/bin/env python3
import os
from PIL import Image

def get_full_bleed_logo(input_png):
    print(f"Reading master transparent logo from {input_png}...")
    im = Image.open(input_png).convert('RGBA')
    bbox = im.getbbox()
    print(f"Original bbox: {bbox}")
    cropped = im.crop(bbox)
    # Full bleed 1024x1024 square with 0 empty margins
    full_bleed = cropped.resize((1024, 1024), Image.Resampling.LANCZOS)
    print(f"Full bleed bbox: {full_bleed.getbbox()}")
    return full_bleed

def place_on_canvas(cropped_logo, canvas_size, scale_factor=1.0, bg_color=None):
    if isinstance(canvas_size, int):
        cw, ch = canvas_size, canvas_size
    else:
        cw, ch = canvas_size

    mode = 'RGBA' if bg_color is None or (len(bg_color) == 4 and bg_color[3] < 255) else 'RGB'
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
    source_png = 'assets/icons/amtr_audit_icon.png'
    master_logo = get_full_bleed_logo(source_png)

    # 1. Update in-app master transparent PNG: 100% full bleed, 0 empty margins
    master_logo.save('assets/icons/amtr_audit_icon.png', 'PNG', optimize=True)
    print("Saved full-bleed assets/icons/amtr_audit_icon.png with zero empty space.")

    # 2. Delete white background backup JPEG if exists
    jpg_backup = 'assets/icons/amtr_audit_icon.jpg'
    if os.path.exists(jpg_backup):
        os.remove(jpg_backup)
        print(f"Completely removed {jpg_backup}")

    # 3. iOS AppIcon (all 15 sizes, full bleed 1.0, no empty margins)
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
        icon_img = place_on_canvas(master_logo, sz, scale_factor=1.0, bg_color=(255, 255, 255))
        icon_img.save(out_path, 'PNG', optimize=True)
    print("Generated all iOS AppIcon sizes with zero empty margins.")

    # 4. Android launcher icons (Legacy mipmaps + Adaptive icons)
    # Legacy mipmaps: 100% full bleed, zero margins, transparent background
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
        legacy_icon = place_on_canvas(master_logo, sz, scale_factor=1.0, bg_color=None)
        legacy_icon.save(os.path.join(folder_path, 'ic_launcher.png'), 'PNG', optimize=True)

    # Android Adaptive foreground (108dp canvas, safe zone 72%)
    adaptive_sizes = {
        'mipmap-mdpi': 108,
        'mipmap-hdpi': 162,
        'mipmap-xhdpi': 216,
        'mipmap-xxhdpi': 324,
        'mipmap-xxxhdpi': 432,
    }
    for folder, sz in adaptive_sizes.items():
        folder_path = os.path.join(res_dir, folder)
        fg_icon = place_on_canvas(master_logo, sz, scale_factor=0.72, bg_color=None)
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
    print("Generated Android legacy and adaptive launcher icons with zero empty margins.")

    # 5. Web Icons
    web_dir = 'web'
    web_icons_dir = 'web/icons'
    os.makedirs(web_icons_dir, exist_ok=True)
    # Favicon (32x32, 100% full bleed, zero margins)
    fav = place_on_canvas(master_logo, 32, scale_factor=1.0, bg_color=None)
    fav.save(os.path.join(web_dir, 'favicon.png'), 'PNG', optimize=True)

    # Icon-192.png & Icon-512.png (PWA standard full bleed)
    i192 = place_on_canvas(master_logo, 192, scale_factor=1.0, bg_color=None)
    i192.save(os.path.join(web_icons_dir, 'Icon-192.png'), 'PNG', optimize=True)
    i512 = place_on_canvas(master_logo, 512, scale_factor=1.0, bg_color=None)
    i512.save(os.path.join(web_icons_dir, 'Icon-512.png'), 'PNG', optimize=True)

    # Maskable PWA icons (72% safe zone)
    m192 = place_on_canvas(master_logo, 192, scale_factor=0.72, bg_color=(255, 255, 255))
    m192.save(os.path.join(web_icons_dir, 'Icon-maskable-192.png'), 'PNG', optimize=True)
    m512 = place_on_canvas(master_logo, 512, scale_factor=0.72, bg_color=(255, 255, 255))
    m512.save(os.path.join(web_icons_dir, 'Icon-maskable-512.png'), 'PNG', optimize=True)
    print("Generated Web favicon and PWA icons with zero empty margins.")

    # 6. Windows app_icon.ico
    win_res_dir = 'windows/runner/resources'
    os.makedirs(win_res_dir, exist_ok=True)
    ico_master = place_on_canvas(master_logo, 256, scale_factor=1.0, bg_color=None)
    ico_path = os.path.join(win_res_dir, 'app_icon.ico')
    ico_master.save(ico_path, format='ICO', sizes=[(16,16), (24,24), (32,32), (48,48), (64,64), (128,128), (256,256)])
    print("Generated Windows multi-resolution app_icon.ico with zero empty margins.")

if __name__ == '__main__':
    main()
