"""Fail the build if libmpv-2.dll does not actually contain h264_qsv / libvpl linkage."""
from pathlib import Path
import sys

dll = Path(sys.argv[1] if len(sys.argv) > 1 else "ffi-out/libmpv-2.dll")
data = dll.read_bytes()

checks = {
    "nul-terminated codec name h264_qsv": b"h264_qsv\x00" in data,
    "nul-terminated aac codec name": b"aac\x00" in data,
    "libvpl.dll import/string": (b"libvpl.dll" in data) or (b"vpl.dll" in data) or (b"MFXLoad" in data),
}
failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(("OK  " if ok else "MISS") + " " + name)

if failed:
    raise SystemExit("libmpv-2.dll missing required QSV/VPL markers: " + ", ".join(failed))

print("verified", dll)
