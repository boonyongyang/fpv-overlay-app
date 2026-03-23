#!/usr/bin/env python3
"""
Generate FPV Logo icons using sips tool (macOS built-in).
"""

import subprocess
import os
import sys


def create_icons_with_pil():
    """Create icons using PIL if available"""
    try:
        from PIL import Image, ImageDraw
        
        def draw_fpv_logo(size, color=(0, 188, 212)):
            """Draw the FPV drone logo"""
            bg_color = (40, 40, 40)
            img = Image.new('RGBA', (size, size), bg_color + (255,))
            draw = ImageDraw.Draw(img)
            
            stroke_width = max(1, int(size * 0.08))
            center = (size / 2, size / 2)
            propeller_radius = size * 0.15
            
            # Draw the "X" frame
            draw.line([(size * 0.2, size * 0.2), (size * 0.8, size * 0.8)], 
                      fill=color, width=stroke_width)
            draw.line([(size * 0.8, size * 0.2), (size * 0.2, size * 0.8)], 
                      fill=color, width=stroke_width)
            
            # Draw the central body
            left = center[0] - (size * 0.125)
            top = center[1] - (size * 0.225)
            right = center[0] + (size * 0.125)
            bottom = center[1] + (size * 0.225)
            radius = int(size * 0.05)
            
            draw.rounded_rectangle(
                [(left, top), (right, bottom)],
                radius=radius,
                fill=color,
                outline=color,
                width=stroke_width
            )
            
            # Draw propellers
            propeller_positions = [
                (size * 0.2, size * 0.2),
                (size * 0.8, size * 0.2),
                (size * 0.2, size * 0.8),
                (size * 0.8, size * 0.8),
            ]
            
            for pos in propeller_positions:
                r = int(propeller_radius)
                draw.ellipse(
                    [(pos[0] - r, pos[1] - r), (pos[0] + r, pos[1] + r)],
                    outline=color,
                    width=stroke_width
                )
                cross_radius = r * 0.5
                draw.line(
                    [(pos[0] - cross_radius, pos[1]), (pos[0] + cross_radius, pos[1])],
                    fill=color,
                    width=int(size * 0.04)
                )
            
            return img
        
        macos_dir = 'macos/Runner/Assets.xcassets/AppIcon.appiconset'
        assets_dir = 'assets/icons'
        
        os.makedirs(macos_dir, exist_ok=True)
        os.makedirs(assets_dir, exist_ok=True)
        
        sizes = [16, 32, 64, 128, 256, 512, 1024]
        cyan_color = (0, 188, 212)
        
        print("Generating FPV Logo icons with PIL/Pillow...\n")
        
        for size in sizes:
            img = draw_fpv_logo(size, cyan_color)
            macos_path = f'{macos_dir}/app_icon_{size}.png'
            img.save(macos_path, 'PNG')
            stat = os.stat(macos_path)
            print(f'✓ Generated: {macos_path} ({stat.st_size} bytes)')
            
            if size == 1024:
                asset_path = f'{assets_dir}/app_icon.png'
                img.save(asset_path, 'PNG')
                print(f'✓ Also saved to: {asset_path}')
        
        return True
        
    except ImportError:
        return False


def main():
    print("=" * 60)
    print("FPV Logo Icon Generator")
    print("=" * 60 + "\n")
    
    # Try PIL first (better quality)
    if create_icons_with_pil():
        print("\n✓ Icons generated successfully with PIL/Pillow!")
        print("\nNext steps:")
        print("1. flutter clean")
        print("2. flutter pub get")
        print("3. Rebuild your app")
        return
    
    print("\n✗ Failed to generate icons with PIL!")
    print("Please install Pillow: python3 -m pip install --user Pillow")
    sys.exit(1)


if __name__ == '__main__':
    main()
