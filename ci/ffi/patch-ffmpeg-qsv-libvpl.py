"""Fix meson-ports FFmpeg depgraph: qsv must accept libvpl (not only libmfx).

Upstream depgraph (from configure parse) still has:
  'qsv': {'deps': ['libmfx']}
so -Dlibvpl=enabled + -Dh264_qsv_decoder=enabled never actually enables
CONFIG_QSV / qsvdec / h264_qsv when libmfx is disabled.
"""
from pathlib import Path

candidates = [
    Path("subprojects/ffmpeg/depgraph.py"),
    Path("subprojects/FFmpeg/depgraph.py"),
]
path = next((p for p in candidates if p.exists()), None)
if path is None:
    raise SystemExit("ffmpeg depgraph.py not found under subprojects/")

text = path.read_text(encoding="utf-8")
old = "'qsv': {'deps': ['libmfx']},"
new = "'qsv': {'deps_any': ['libmfx', 'libvpl']},"
if new in text:
    print(f"already patched: {path}")
elif old in text:
    path.write_text(text.replace(old, new, 1), encoding="utf-8")
    print(f"patched {path}: qsv deps_any libmfx|libvpl")
else:
    raise SystemExit(f"{path}: unexpected qsv deps line; cannot patch")
