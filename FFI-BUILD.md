# MPV-Win-AVC-FFI minimal libmpv build

Cloud-only build of **`libmpv-2.dll`** for mpv-kernel / Bili.Net.

## Trigger

GitHub Actions → **buildffi** → Run workflow  

Workflow: `.github/workflows/buildffi.yml`（**全部 cmd 步骤**，不再使用 PowerShell 构建脚本）

## Toolchain（仅 win-x64）

1. **libvpl**：`VsDevCmd -arch=x64` + **MSVC `cl` + Ninja**（避免 clang/lld 吃到 Linux `-z relro`）
2. **libmpv/FFmpeg/libplacebo**：同一 DevShell + **VS `VC\Tools\Llvm\x64` 的 clang / lld-link**（须从 PATH 去掉独立安装的 `C:\Program Files\LLVM`）
3. 依赖：`pkgconfiglite`、`NASM`、`ccache`、`meson`、`ninja`
4. Meson：`--default-library=static`，并用 `ci/ffi/patch-libmpv-shared.py` 把 `libmpv` 改成 `shared_library` 以产出 DLL
5. 必须 `-Dffmpeg:vvc_decoder=disabled`（meson-ports `meson-8.1` 在 aarch64 脚本里有误引用 `libavcodec_x86_optional_sources` 的 bug）

## Cache

`.ccache`、`ffi-prefix`、`subprojects/libvpl`、`subprojects/shaderc_cmake`

## Runtime contract

| Item | Value |
| --- | --- |
| DLL | `libmpv-2.dll` (+ `libvpl.dll`) |
| API | libmpv client API |
| VO | `vo=gpu` + d3d11 |
| Decode | `hwdec=no`，FFmpeg **h264_qsv only** |
| Audio | AAC soft + WASAPI |
| Net | HTTP(S) Range；DASH 靠 `audio-file=` |

## Static wrap helpers

`ci/ffi/` 下放 shaderc/spirv-cross 的 meson wrap 片段与 patch（非构建脚本）。
