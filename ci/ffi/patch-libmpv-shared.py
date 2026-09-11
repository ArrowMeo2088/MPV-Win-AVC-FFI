from pathlib import Path

p = Path("meson.build")
text = p.read_text(encoding="utf-8")
old = "libmpv = library('mpv'"
new = "libmpv = shared_library('mpv'"
if old not in text:
    raise SystemExit("meson.build: libmpv = library('mpv' not found")
p.write_text(text.replace(old, new, 1), encoding="utf-8")
print("patched meson.build -> shared_library(mpv)")
