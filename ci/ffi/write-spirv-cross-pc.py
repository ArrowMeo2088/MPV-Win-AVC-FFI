from pathlib import Path

prefix = Path("ffi-prefix").resolve()
lib = prefix / "lib"
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

libs = " ".join(f"-l{n}" for n in needed)
pc = f"""prefix={prefix.as_posix()}
exec_prefix=${{prefix}}
libdir=${{prefix}}/lib
includedir=${{prefix}}/include

Name: spirv-cross-c-shared
Description: SPIRV-Cross C API (static MSVC build)
Version: 0.59.0
Libs: -L${{libdir}} {libs}
Cflags: -I${{includedir}} -DSPIRV_CROSS_C_API_GLSL=1 -DSPIRV_CROSS_C_API_HLSL=1
"""
(pc_dir / "spirv-cross-c-shared.pc").write_text(pc, encoding="ascii")
print("wrote", pc_dir / "spirv-cross-c-shared.pc")
print(pc)
