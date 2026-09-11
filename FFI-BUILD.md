# MPV-Win-AVC-FFI minimal libmpv build

Cloud-only MSVC build of **`libmpv-2.dll`** for [mpv-kernel](https://github.com/) / Bili.Net.

## Trigger

```text
GitHub Actions → buildffi → Run workflow
```

Workflow file: `.github/workflows/buildffi.yml`  
Build script: `ci/build-win32-ffi.ps1`  

Push/PR auto builds for the legacy full matrix (`build.yml`, `lint.yml`, …) are **disabled**; those workflows are `workflow_dispatch` only.

## Runtime contract (mpv-kernel)

| Item | Value |
| --- | --- |
| DLL | `libmpv-2.dll` (+ `libvpl.dll` dispatcher when present) |
| API | Standard libmpv client API (`mpv_*` exports) |
| Video out | `vo=gpu`, `gpu-api=d3d11`, `gpu-context=d3d11` |
| Decode | `hwdec=no` — FFmpeg **`h264_qsv` only** (no soft `h264`) |
| Audio | AAC soft decode, WASAPI |
| Network | HTTP(S) Range via FFmpeg protocols |
| DASH A/V | Separate URLs via `loadfile` + `audio-file=` |

## FFmpeg (meson-ports) highlights

Enabled:

- `libvpl`, `h264_qsv_decoder`, `aac_decoder`
- demux: `mov`, `mpegts`, `dash`, `aac`, `h264`
- protocols: `file`, `http`, `https`, `tcp`, `tls`, `crypto`
- parsers/BSF: `h264`, `aac`, `h264_mp4toannexb`, `aac_adtstoasc`, `extract_extradata`
- filters: `aresample`, `aformat`, `format`, `scale`, `hwdownload`, `hwupload`, `hwmap`

Disabled (selected):

- soft `h264_decoder`, `hevc_*`, `av1_*`, other `*_qsv` codecs, NVENC/CUVID/AMF paths
- `ffnvcodec`, FFmpeg `vulkan`, FFmpeg programs

## mpv meson highlights

Enabled: `libmpv`, `d3d11`, `wasapi`, `shaderc`, libplacebo `d3d11`  

Disabled: `cplayer`, `lua`, `javascript`, `cuda-*`, `d3d-hwaccel`, `d3d9-hwaccel`, `amf`, `vulkan`, OpenGL/EGL/ANGLE, dvd/bluray/cdda, etc.

Note: **libass** remains linked (mpv hard dependency for OSD); Bilibili danmaku is still expected to be handled outside mpv.

## Artifact

Upload folder `ffi-out/`:

- `libmpv-2.dll` (renamed from Meson `mpv-*.dll`)
- `libvpl.dll` / related dispatcher DLLs when produced
- **no `.pdb`**

## Notes

- Do **not** rely on local compilation; use Actions.
- Full QSV decode still needs an Intel GPU runtime on the playback machine (dispatcher alone is not enough).
- Legacy `ci/build-win32.ps1` remains for the optional full `build` workflow and is not the FFI path.
