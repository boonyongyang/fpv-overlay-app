#!/usr/bin/env python3
"""
FPV Batch Overlay Tool - UNIFIED
Processes both .srt (text) and .osd (binary DJI) files automatically
Usage: python3 batch-overlay-unified.py <input_folder> <output_folder>
"""

import os
import sys
import subprocess
from pathlib import Path

def find_file_pairs(input_dir):
    """Find all video + (.srt OR .osd) pairs"""
    input_path = Path(input_dir)
    
    if not input_path.exists():
        print(f"❌ Input directory not found: {input_dir}")
        sys.exit(1)
    
    # Find videos
    videos = {}
    for ext in ['*.mp4', '*.mov']:
        for f in input_path.glob(ext):
            videos[f.stem] = f
    
    # Find subtitles/OSD
    srt_files = {f.stem: f for f in input_path.glob('*.srt')}
    osd_files = {f.stem: f for f in input_path.glob('*.osd')}
    
    # Match pairs (prefer .osd if both exist)
    pairs = []
    for name in videos:
        if name in osd_files:
            pairs.append({
                'name': name,
                'video': videos[name],
                'overlay': osd_files[name],
                'type': 'osd'
            })
        elif name in srt_files and srt_files[name].stat().st_size > 0:
            pairs.append({
                'name': name,
                'video': videos[name],
                'overlay': srt_files[name],
                'type': 'srt'
            })
    
    return pairs

def process_srt(video_path, srt_path, output_path):
    """Process using ffmpeg subtitle overlay (FAST)"""
    cmd = [
        'ffmpeg',
        '-i', str(video_path),
        '-vf', f"subtitles='{srt_path}'",
        '-c:v', 'libx264',
        '-crf', '23',
        '-preset', 'medium',
        '-c:a', 'aac',
        '-y',
        str(output_path)
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=7200)
        if result.returncode == 0:
            return True, "Success"
        else:
            return False, "ffmpeg error"
    except subprocess.TimeoutExpired:
        return False, "Timeout (>2h)"
    except Exception as e:
        return False, str(e)

def process_osd(video_path, osd_path, output_path, o3_tool_path):
    """Process using O3_OverlayTool (SLOW but professional)"""
    try:
        sys.path.insert(0, str(o3_tool_path))
        from VideoMaker import VideoMaker
        from TransparentVideoMaker import TransparentVideoMaker
        from OsdFileReader import OsdFileReader
        
        # Load OSD
        osd_reader = OsdFileReader(str(osd_path), framerate=60)
        
        # Create video maker (transparent background)
        font_path = o3_tool_path / 'fonts/WS_BFx4_Nexus_Moonlight_2160p.png'
        if not font_path.exists():
            font_path = o3_tool_path / 'fonts/WS_BTFL_Conthrax_Moonlight_1440p.png'
        
        video_maker = TransparentVideoMaker(osd_reader, str(font_path), fps=60)
        
        # Create video with overlay
        video_maker.create_video(str(output_path), str(video_path))
        
        return True, "Success"
    
    except Exception as e:
        return False, str(e)

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 batch-overlay-unified.py <input_folder> <output_folder>")
        print("")
        print("Supports both:")
        print("  • .srt files  (text telemetry) - FAST (~30s per video)")
        print("  • .osd files  (DJI graphics)   - SLOW (~5min per video)")
        print("")
        print("Example:")
        print("  python3 batch-overlay-unified.py ~/videos ~/videos-done")
        sys.exit(1)
    
    input_dir = sys.argv[1]
    output_dir = sys.argv[2]
    
    os.makedirs(output_dir, exist_ok=True)
    
    # Check ffmpeg (needed for both)
    try:
        subprocess.run(['ffmpeg', '-version'], capture_output=True, timeout=5, check=True)
    except:
        print("❌ ffmpeg not found: brew install ffmpeg")
        sys.exit(1)
    
    # Find O3_OverlayTool for .osd files
    o3_tool = Path.home() / 'Downloads' / 'O3_OverlayTool-1.1.0'
    
    # Find pairs
    pairs = find_file_pairs(input_dir)
    
    if not pairs:
        print("❌ No video + (.srt or .osd) pairs found")
        sys.exit(1)
    
    print("🚀 FPV Batch Overlay Tool (UNIFIED)")
    print(f"📁 Input:  {Path(input_dir).resolve()}")
    print(f"📁 Output: {Path(output_dir).resolve()}")
    print("")
    
    # Count by type
    srt_count = sum(1 for p in pairs if p['type'] == 'srt')
    osd_count = sum(1 for p in pairs if p['type'] == 'osd')
    
    if srt_count:
        print(f"📄 SRT files: {srt_count} (will use ffmpeg - fast)")
    if osd_count:
        if o3_tool.exists():
            print(f"🎨 OSD files: {osd_count} (will use O3_OverlayTool - slow)")
        else:
            print(f"🎨 OSD files: {osd_count} (O3_OverlayTool not found!)")
    
    print("")
    print(f"✅ Found {len(pairs)} pair(s):")
    for i, p in enumerate(pairs, 1):
        icon = "📄" if p['type'] == 'srt' else "🎨"
        print(f"   {i}. {icon} {p['name']} ({p['type'].upper()})")
    print("")
    
    processed = 0
    failed = 0
    
    for pair in pairs:
        name = pair['name']
        video = pair['video']
        overlay = pair['overlay']
        overlay_type = pair['type']
        output = Path(output_dir) / f"{name}-overlay.mp4"
        
        icon = "📄" if overlay_type == 'srt' else "🎨"
        print(f"{icon} {name} ({overlay_type.upper()})")
        
        try:
            if overlay_type == 'srt':
                success, msg = process_srt(video, overlay, output)
            else:  # osd
                if not o3_tool.exists():
                    print(f"   ❌ O3_OverlayTool not found at: {o3_tool}")
                    failed += 1
                    continue
                success, msg = process_osd(video, overlay, output, o3_tool)
            
            if success:
                size_mb = output.stat().st_size / 1024 / 1024
                print(f"   ✅ ({size_mb:.1f} MB)")
                processed += 1
            else:
                print(f"   ❌ {msg}")
                failed += 1
        
        except Exception as e:
            print(f"   ❌ {str(e)}")
            failed += 1
        
        print("")
    
    print("=" * 60)
    print(f"📊 RESULTS")
    print(f"   ✅ Processed: {processed}/{len(pairs)}")
    print(f"   ❌ Failed:    {failed}/{len(pairs)}")
    print("=" * 60)

if __name__ == '__main__':
    main()
