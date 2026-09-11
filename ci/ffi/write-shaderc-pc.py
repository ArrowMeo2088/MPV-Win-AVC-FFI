from pathlib import Path

prefix = Path("ffi-prefix").resolve()
lib = prefix / "lib"
pc_dir = lib / "pkgconfig"
pc_dir.mkdir(parents=True, exist_ok=True)

combined = lib / "shaderc_combined.lib"
shaderc = lib / "shaderc.lib"
util = lib / "shaderc_util.lib"

libs = []
if combined.exists():
    libs = ["-lshaderc_combined"]
elif shaderc.exists():
    libs = ["-lshaderc"]
    if util.exists():
        libs.append("-lshaderc_util")
    for name in (
        "SPIRV-Tools-opt",
        "SPIRV-Tools",
        "glslang",
        "MachineIndependent",
        "GenericCodeGen",
        "OSDependent",
        "SPIRV",
        "glslang-default-resource-limits",
    ):
        if (lib / f"{name}.lib").exists():
            libs.append(f"-l{name}")
else:
    raise SystemExit(f"shaderc libs not found under {lib}")

# Static MSVC shaderc needs these when linked into clang/lld builds.
libs += ["-ladvapi32", "-luser32"]

pc = f"""prefix={prefix.as_posix()}
exec_prefix=${{prefix}}
libdir=${{prefix}}/lib
includedir=${{prefix}}/include

Name: shaderc
Description: A library for compiling shader strings into SPIR-V
Version: 2024.1
Libs: -L${{libdir}} {" ".join(libs)}
Cflags: -I${{includedir}}
"""
(pc_dir / "shaderc.pc").write_text(pc, encoding="ascii")
print("wrote", pc_dir / "shaderc.pc")
print(pc)
