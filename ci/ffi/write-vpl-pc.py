from pathlib import Path

prefix = Path("ffi-prefix").resolve()
pc_dir = prefix / "lib" / "pkgconfig"
pc_dir.mkdir(parents=True, exist_ok=True)

# Prefer cmake-installed layout (include/vpl); also expose root include.
pc = f"""prefix={prefix.as_posix()}
exec_prefix=${{prefix}}
libdir=${{prefix}}/lib
includedir=${{prefix}}/include

Name: vpl
Description: Intel Video Processing Library
Version: 2.17.0
Libs: -L${{libdir}} -lvpl
Cflags: -I${{includedir}} -I${{includedir}}/vpl
"""
(pc_dir / "vpl.pc").write_text(pc, encoding="ascii")
print("wrote", pc_dir / "vpl.pc")
print(pc)
