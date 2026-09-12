#!/usr/bin/env bash
# =============================================================================
# Flind Player — Icon generation pipeline
# =============================================================================
# Re-runnable script that produces every platform icon from the master artwork.
#
# PREREQUISITES:
#   - ffmpeg (image manipulation)
#   - Python 3 (ICO generation, monochrome tray icon)
#   - flutter_launcher_icons (installed as a dev dependency)
#
# USAGE:
#   ./tool/generate_icons.sh            # full pipeline
#   ./tool/generate_icons.sh --skip-flutter  # skip the flutter_launcher_icons step
#
# TO UPDATE THE ARTWORK:
#   1. Replace docs/FlindPlayer.png (1120x1120 RGBA, transparent rounded corners)
#      and/or docs/FlindPlayer.ico with your refined artwork.
#   2. Run this script — everything regenerates automatically.
#
# The script uses two approaches for the foreground:
#   - A Python pixel-manipulation step for precise alpha handling (coral removal
#     while preserving original transparent corners).
#   - ffmpeg for scaling and color operations.
#
# CAVEAT: The foreground extraction uses a Euclidean RGB distance threshold of
#   50 against the coral colour (#FE9288). This produces clean results for the
#   current artwork. If the maintainer supplies a full-bleed master (no baked-in
#   alpha), replace the Python foreground step with a simpler colourkey approach.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

# --- Configuration -----------------------------------------------------------
SOURCE_ARTWORK="docs/FlindPlayer.png"
ICON_DIR="assets/icon"
TRAY_DIR="assets/tray"
CORAL_HEX="0xFE9288"
CORAL_RGB=(254 146 136)
COLOR_THRESHOLD=50

SKIP_FLUTTER=false
if [[ "${1:-}" == "--skip-flutter" ]]; then
  SKIP_FLUTTER=true
fi

echo "=== Flind Player Icon Pipeline ==="
echo "Source: $SOURCE_ARTWORK"
echo ""

# --- 1. Prepare output directories -------------------------------------------
mkdir -p "$ICON_DIR" "$TRAY_DIR"

# --- 2. Full-bleed app icon (1024x1024, RGB, no alpha) -----------------------
echo "[1/5] Generating full-bleed app_icon.png (1024x1024, RGB)..."
ffmpeg -y -f lavfi -i "color=c=$CORAL_HEX:s=1120x1120" \
  -i "$SOURCE_ARTWORK" \
  -filter_complex "[0:v][1:v]overlay=format=auto,scale=1024:1024:flags=lanczos" \
  -pix_fmt rgb24 -frames:v 1 -update 1 \
  "$ICON_DIR/app_icon.png" 2>/dev/null
echo "  -> $ICON_DIR/app_icon.png"

# --- 3. Adaptive foreground (1024x1024, RGBA, transparent background) --------
echo "[2/5] Generating adaptive foreground (1024x1024, RGBA, coral removed)..."
python3 - "$SOURCE_ARTWORK" "$ICON_DIR/app_icon_foreground.png" \
  "${CORAL_RGB[0]}" "${CORAL_RGB[1]}" "${CORAL_RGB[2]}" "$COLOR_THRESHOLD" <<'PYEOF'
import subprocess, math, sys

source = sys.argv[1]
output = sys.argv[2]
coral = (int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5]))
threshold = int(sys.argv[6])

# Scale source to 1024x1024 and read as raw RGBA
result = subprocess.run([
    'ffmpeg', '-i', source, '-vf', 'scale=1024:1024:flags=lanczos',
    '-f', 'rawvideo', '-pix_fmt', 'rgba', '-'
], capture_output=True)
data = result.stdout
width, height = 1024, 1024
assert len(data) == width * height * 4, f"unexpected size {len(data)}"

out = bytearray(len(data))
for i in range(0, len(data), 4):
    r, g, b, a = data[i], data[i+1], data[i+2], data[i+3]
    if a == 0:
        # Transparent corner -> keep transparent
        out[i:i+4] = b'\x00\x00\x00\x00'
    else:
        dist = math.sqrt((r-coral[0])**2 + (g-coral[1])**2 + (b-coral[2])**2)
        if dist < threshold:
            # Coral pixel -> transparent
            out[i:i+4] = b'\x00\x00\x00\x00'
        else:
            # Mark pixel -> keep original
            out[i] = r; out[i+1] = g; out[i+2] = b; out[i+3] = a

proc = subprocess.Popen([
    'ffmpeg', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgba',
    '-s', f'{width}x{height}', '-r', '1', '-i', '-',
    '-frames:v', '1', '-update', '1', output
], stdin=subprocess.PIPE, stderr=subprocess.PIPE)
proc.communicate(bytes(out))
assert proc.returncode == 0, "ffmpeg write failed"
print(f"  -> {output}")
PYEOF

# --- 4. Linux icon (256x256, RGB, no alpha) ----------------------------------
echo "[3/5] Generating app_icon_256.png (256x256, RGB)..."
ffmpeg -y -i "$ICON_DIR/app_icon.png" \
  -vf "scale=256:256:flags=lanczos" \
  -pix_fmt rgb24 -frames:v 1 -update 1 \
  "$ICON_DIR/app_icon_256.png" 2>/dev/null
echo "  -> $ICON_DIR/app_icon_256.png"

# --- 5. Monochrome tray icon (96x96, white on transparent) ------------------
echo "[4/5] Generating monochrome tray_icon.png (96x96, white on transparent)..."
python3 - "$ICON_DIR/app_icon_foreground.png" "$TRAY_DIR/tray_icon.png" <<'PYEOF'
import subprocess, sys

source = sys.argv[1]
output = sys.argv[2]

# Scale foreground to 96x96 and read as raw RGBA
result = subprocess.run([
    'ffmpeg', '-i', source, '-vf', 'scale=96:96:flags=lanczos',
    '-f', 'rawvideo', '-pix_fmt', 'rgba', '-'
], capture_output=True)
data = result.stdout
width, height = 96, 96
assert len(data) == width * height * 4

out = bytearray(len(data))
for i in range(0, len(data), 4):
    a = data[i+3]
    out[i] = 255; out[i+1] = 255; out[i+2] = 255; out[i+3] = a

proc = subprocess.Popen([
    'ffmpeg', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgba',
    '-s', f'{width}x{height}', '-r', '1', '-i', '-',
    '-frames:v', '1', '-update', '1', output
], stdin=subprocess.PIPE, stderr=subprocess.PIPE)
proc.communicate(bytes(out))
assert proc.returncode == 0, "ffmpeg write failed"
print(f"  -> {output}")
PYEOF

# --- 6. Run flutter_launcher_icons for platform-specific assets ---------------
echo "[5/5] Running flutter_launcher_icons..."
if [ "$SKIP_FLUTTER" = true ]; then
  echo "  (skipped --use --skip-flutter to bypass)"
else
  dart run flutter_launcher_icons 2>&1
fi

echo ""
echo "=== Pipeline complete ==="
echo ""
echo "Generated artifacts:"
ls -lh "$ICON_DIR/" 2>/dev/null
ls -lh "$TRAY_DIR/" 2>/dev/null
echo ""
echo "Run 'file' on each artifact to verify format and alpha channel."
