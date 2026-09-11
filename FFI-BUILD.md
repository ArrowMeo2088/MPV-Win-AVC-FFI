# MPV-Win-AVC-FFI minimal libmpv build

Cloud-only build of **`libmpv-2.dll`** for mpv-kernel / Bili.Net.

**仅 Windows x64**（`windows-2025` / MSVC）。无 ARM、无 mingw、无 macOS。

## Trigger

GitHub Actions → **buildffi** → Run workflow  

Workflow: `.github/workflows/buildffi.yml`（**全部 cmd 步骤**，不再使用 PowerShell 构建脚本）

## Toolchain（仅 win-x64）

1. **libvpl / shaderc / spirv-cross**：`VsDevCmd -arch=x64` + **MSVC `cl` + Ninja**，装进 `ffi-prefix`，再写 `.pc`（避免 meson CMake wrap / clang 吃到 Unix 链接参数）
2. **FFmpeg QSV**：meson-ports `depgraph.py` 默认 `qsv` 只依赖 `libmfx`；构建前用 `ci/ffi/patch-ffmpeg-qsv-libvpl.py` 改为 `deps_any: libmfx|libvpl`，否则 `-Dlibvpl=enabled` 时 `h264_qsv` 不会真正编进
3. **libmpv / FFmpeg / libplacebo**：同一 DevShell + **VS `VC\Tools\Llvm\x64` 的 clang / lld-link**（须让 VS LLVM 排在独立 `C:\Program Files\LLVM` 之前）
4. 依赖：`pkgconfiglite`、`NASM`、`ccache`、`meson`、`ninja`
5. Meson：`--default-library=static`，并用 `ci/ffi/patch-libmpv-shared.py` 把 `libmpv` 改成 `shared_library` 以产出 DLL
6. 必须 `-Dffmpeg:vvc_decoder=disabled`（meson-ports `meson-8.1` 在 aarch64 脚本里误引用 `libavcodec_x86_optional_sources`）
7. 打包阶段校验：`dumpbin` 依赖含 `libvpl.dll`，且 DLL 内有 `h264_qsv\0`

## Cache

`.ccache`、`ffi-prefix`、`subprojects/libvpl`、`subprojects/shaderc_cmake`、`subprojects/spirv-cross-src`  
每次运行会按当前 workspace **重写** `vpl.pc` / `shaderc.pc` / `spirv-cross-c-shared.pc`，避免 cache 里绝对路径失效。

## Runtime contract

| Item | Value |
| --- | --- |
| DLL | `libmpv-2.dll` (+ `libvpl.dll`) |
| Arch | **win-x64 only** |
| API | libmpv client API |
| VO | `vo=gpu` + d3d11 |
| Decode | `hwdec=no`，FFmpeg **h264_qsv only** |
| Audio | AAC soft + WASAPI |
| Net | HTTP(S) Range；DASH 靠 `audio-file=` |

## Helpers

`ci/ffi/`：`patch-libmpv-shared.py`、`write-shaderc-pc.py`、`write-spirv-cross-pc.py`、`shaderc-glslang.patch`（以及可选的 meson wrap 参考文件，当前流水线不再用 meson cmake 编 shaderc/spirv-cross）。
