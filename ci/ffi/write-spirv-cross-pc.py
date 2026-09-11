from pathlib import Path
import shutil

prefix = Path("ffi-prefix").resolve()
lib = prefix / "lib"
inc = prefix / "include"
pc_dir = lib / "pkgconfig"
pc_dir.mkdir(parents=True, exist_ok=True)

needed = [
    "spirv-cross-c",
    "spirv-cross-core",
    "spirv-cross-glsl",
    "spirv-cross-hlsl",
]
missing = [n for n in needed if not (lib / f"{n}.lib").exists()]
if missing:
    raise SystemExit(f"spirv-cross libs missing under {lib}: {missing}")

# CMake installs headers under include/spirv_cross/; libplacebo includes <spirv_cross_c.h>
hdr_nested = inc / "spirv_cross" / "spirv_cross_c.h"
hdr_flat = inc / "spirv_cross_c.h"
if hdr_nested.exists() and not hdr_flat.exists():
    shutil.copy2(hdr_nested, hdr_flat)
    # common sibling headers referenced by spirv_cross_c.h
    for name in ("spirv.h", "spirv_cross.hpp", "spirv_glsl.hpp", "spirv_hlsl.hpp"):
        src = inc / "spirv_cross" / name
        dst = inc / name
        if src.exists() and not dst.exists():
            shutil.copy2(src, dst)
elif not hdr_nested.exists() and not hdr_flat.exists():
    raise SystemExit(f"spirv_cross_c.h not found under {inc}")

libs = " ".join(f"-l{n}" for n in needed)
pc = f"""prefix={prefix.as_posix()}
exec_prefix=${{prefix}}
libdir=${{prefix}}/lib
includedir=${{prefix}}/include

Name: spirv-cross-c-shared
Description: SPIRV-Cross C API (static MSVC build)
Version: 0.59.0
Libs: -L${{libdir}} {libs}
Cflags: -I${{includedir}} -I${{includedir}}/spirv_cross -DSPIRV_CROSS_C_API_GLSL=1 -DSPIRV_CROSS_C_API_HLSL=1
"""
(pc_dir / "spirv-cross-c-shared.pc").write_text(pc, encoding="ascii")
print("wrote", pc_dir / "spirv-cross-c-shared.pc")
print(pc)
print("header nested:", hdr_nested.exists(), "flat:", hdr_flat.exists())
