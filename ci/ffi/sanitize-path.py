import os
from pathlib import Path

bad = {
    r"C:\Program Files\LLVM\bin",
    r"C:\Program Files\CMake\bin",
    r"C:\Strawberry\c\bin",
}
parts = [p for p in os.environ.get("PATH", "").split(";") if p and p not in bad]
Path("_path.txt").write_text(";".join(parts), encoding="utf-8")
print("wrote _path.txt with", len(parts), "entries")
