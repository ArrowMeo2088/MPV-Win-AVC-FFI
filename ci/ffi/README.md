# ci/ffi helpers

Helpers for the **win-x64** `buildffi` GitHub Actions workflow (cmd steps in `.github/workflows/buildffi.yml`).

| File | Purpose |
| --- | --- |
| `patch-libmpv-shared.py` | Turn `libmpv` into `shared_library` so Meson emits a DLL while deps stay static |
| `write-shaderc-pc.py` | Rewrite `shaderc.pc` for the current workspace after MSVC install |
| `write-spirv-cross-pc.py` | Rewrite `spirv-cross-c-shared.pc` after MSVC install |
| `shaderc-glslang.patch` | Fix glslang install generator expr when building shaderc with CMake |
| `shaderc.meson.build` / `spirv-cross.meson.build` | Optional meson cmake wrap references (current pipeline prebuilds with `cl` instead) |

Do not add PowerShell build scripts here; the cloud build is entirely in the workflow YAML.
