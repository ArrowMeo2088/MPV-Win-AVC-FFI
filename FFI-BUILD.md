# MPV-Win-AVC-FFI minimal libmpv build

Cloud-only build of **`libmpv-2.dll`** for mpv-kernel / Bili.Net.

## Trigger

GitHub Actions → **buildffi** → Run workflow  

Workflow: `.github/workflows/buildffi.yml`（**全部 cmd 步骤**，不再使用 PowerShell 构建脚本）

## Toolchain

1. **libvpl**：`VsDevCmd` + **MSVC `cl` + Ninja**（避免 clang/lld 吃到 Linux `-z relro`）
2. **libmpv/FFmpeg/libplacebo**：`VsDevCmd` + **clang / lld-link**（与上游 win32 CI 相同 MSVC ABI）
3. 依赖：`pkgconfiglite`、`NASM`、`ccache`、`meson`、`ninja`

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
