# Minimal Windows MSVC build for libmpv FFI (Bili.Net / mpv-kernel).
# Intended for GitHub Actions only — do not run as a local day-to-day build.
#
# Capabilities kept:
#   - Intel QSV H.264 hard decode via FFmpeg h264_qsv + libvpl (no soft h264)
#   - AAC soft decode
#   - HTTP(S) Range streaming
#   - DASH-style A/V via separate demux + mpv audio-file (mov/mpegts/dash)
#   - vo=gpu + d3d11 render path (libplacebo)
#
# Explicitly disabled: HEVC/AV1/VP9 soft+hard, NVDEC/CUDA, AMF, D3D11VA/DXVA2,
# Vulkan video, Lua/JS, cplayer, ass, dav1d/aom/jxl, etc.

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true
Set-StrictMode -Version Latest

$root = Resolve-Path .
$subprojects = Join-Path $root "subprojects"
$prefix = Join-Path $root "ffi-prefix"
$artifactDir = Join-Path $root "ffi-out"
$buildDir = Join-Path $root "build-ffi"

New-Item -ItemType Directory -Force -Path $subprojects, $prefix, $artifactDir | Out-Null

function Invoke-Native([string]$File, [string[]]$ArgList) {
    Write-Host "==> $File $($ArgList -join ' ')"
    & $File @ArgList
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed ($LASTEXITCODE): $File $($ArgList -join ' ')"
    }
}

# --- oneVPL dispatcher (libvpl) ---
$vplSrc = Join-Path $subprojects "libvpl"
$vplBuild = Join-Path $subprojects "libvpl-build"
if (-not (Test-Path $vplSrc)) {
    Invoke-Native git @("clone", "--depth", "1", "--branch", "v2.17.0", "https://github.com/intel/libvpl.git", $vplSrc)
}
if (-not (Test-Path (Join-Path $prefix "lib\pkgconfig\vpl.pc")) -and
    -not (Test-Path (Join-Path $prefix "lib\pkgconfig\libvpl.pc"))) {
    New-Item -ItemType Directory -Force -Path $vplBuild | Out-Null
    Invoke-Native cmake @(
        "-S", $vplSrc,
        "-B", $vplBuild,
        "-G", "Ninja",
        "-DCMAKE_BUILD_TYPE=Release",
        "-DCMAKE_INSTALL_PREFIX=$prefix",
        "-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded",
        "-DBUILD_SHARED_LIBS=ON",
        "-DBUILD_TOOLS=OFF",
        "-DBUILD_EXAMPLES=OFF",
        "-DBUILD_TESTS=OFF"
    )
    Invoke-Native cmake @("--build", $vplBuild, "--config", "Release")
    Invoke-Native cmake @("--install", $vplBuild, "--config", "Release")
}

$env:CMAKE_PREFIX_PATH = $prefix
$env:PKG_CONFIG_PATH = @(
    (Join-Path $prefix "lib\pkgconfig"),
    (Join-Path $prefix "lib64\pkgconfig"),
    (Join-Path $prefix "share\pkgconfig")
) -join ";"
$env:PATH = "$(Join-Path $prefix 'bin');$env:PATH"
$env:INCLUDE = "$(Join-Path $prefix 'include');$env:INCLUDE"
$env:LIB = "$(Join-Path $prefix 'lib');$(Join-Path $prefix 'lib64');$env:LIB"

# --- shaderc wrap (needed by libplacebo / vo=gpu) ---
if (-not (Test-Path "$subprojects/shaderc_cmake")) {
    Invoke-Native git @("clone", "--depth", "1", "https://github.com/google/shaderc", "$subprojects/shaderc_cmake")
    Set-Content -Path "$subprojects/shaderc_cmake/p.diff" -Value @'
diff --git a/third_party/CMakeLists.txt b/third_party/CMakeLists.txt
index 9e9d8b1..fecab91 100644
--- a/third_party/CMakeLists.txt
+++ b/third_party/CMakeLists.txt
@@ -92,7 +92,11 @@ if (NOT TARGET glslang)
       # Glslang tests are off by default. Turn them on if testing Shaderc.
       set(GLSLANG_TESTS ON)
     endif()
-    set(GLSLANG_ENABLE_INSTALL $<NOT:${SKIP_GLSLANG_INSTALL}>)
+    if (SKIP_GLSLANG_INSTALL)
+      set(GLSLANG_ENABLE_INSTALL OFF)
+    else()
+      set(GLSLANG_ENABLE_INSTALL ON)
+    endif()
     set(ENABLE_HLSL "${SHADERC_ENABLE_HLSL}")
     add_subdirectory(${SHADERC_GLSLANG_DIR} glslang)
   endif()
'@
    git -C "$subprojects/shaderc_cmake" apply --ignore-whitespace p.diff
}
if (-not (Test-Path "$subprojects/shaderc")) {
    New-Item -Path "$subprojects/shaderc" -ItemType Directory | Out-Null
}
Set-Content -Path "$subprojects/shaderc/meson.build" -Value @"
project('shaderc', 'cpp', version: '2024.1')

python = find_program('python3')
run_command(python, '../shaderc_cmake/utils/git-sync-deps', check: true)
run_command(python,
    '../shaderc_cmake/third_party/spirv-tools/utils/update_build_version.py',
    '../shaderc_cmake/third_party/spirv-tools/CHANGES',
    '../shaderc_cmake/third_party/spirv-tools/build-version.inc',
    check: true)

cmake = import('cmake')
opts = cmake.subproject_options()
opts.add_cmake_defines({
    'CMAKE_MSVC_RUNTIME_LIBRARY': 'MultiThreaded',
    'CMAKE_POLICY_DEFAULT_CMP0091': 'NEW',
    'SHADERC_SKIP_INSTALL': 'ON',
    'SHADERC_SKIP_TESTS': 'ON',
    'SHADERC_SKIP_EXAMPLES': 'ON',
    'SHADERC_SKIP_COPYRIGHT_CHECK': 'ON'
})
shaderc_proj = cmake.subproject('shaderc_cmake', options: opts)
shaderc_dep = declare_dependency(dependencies: [
    shaderc_proj.dependency('shaderc'),
    shaderc_proj.dependency('shaderc_util'),
    shaderc_proj.dependency('SPIRV-Tools-static'),
    shaderc_proj.dependency('SPIRV-Tools-opt'),
    shaderc_proj.dependency('glslang'),
])
meson.override_dependency('shaderc', shaderc_dep)
"@

if (-not (Test-Path "$subprojects/spirv-cross-c-shared")) {
    New-Item -Path "$subprojects/spirv-cross-c-shared" -ItemType Directory | Out-Null
}
Set-Content -Path "$subprojects/spirv-cross-c-shared/meson.build" -Value @"
project('spirv-cross', 'cpp', version: '0.59.0')
cmake = import('cmake')
opts = cmake.subproject_options()
opts.add_cmake_defines({
    'CMAKE_MSVC_RUNTIME_LIBRARY': 'MultiThreaded',
    'CMAKE_POLICY_DEFAULT_CMP0091': 'NEW',
    'SPIRV_CROSS_EXCEPTIONS_TO_ASSERTIONS': 'ON',
    'SPIRV_CROSS_CLI': 'OFF',
    'SPIRV_CROSS_ENABLE_TESTS': 'OFF',
    'SPIRV_CROSS_ENABLE_MSL': 'OFF',
    'SPIRV_CROSS_ENABLE_CPP': 'OFF',
    'SPIRV_CROSS_ENABLE_REFLECT': 'OFF',
    'SPIRV_CROSS_ENABLE_UTIL': 'OFF',
})
spirv_cross_proj = cmake.subproject('spirv-cross', options: opts)
spirv_cross_c_dep = declare_dependency(dependencies: [
    spirv_cross_proj.dependency('spirv-cross-c'),
    spirv_cross_proj.dependency('spirv-cross-core'),
    spirv_cross_proj.dependency('spirv-cross-glsl'),
    spirv_cross_proj.dependency('spirv-cross-hlsl'),
])
meson.override_dependency('spirv-cross-c-shared', spirv_cross_c_dep)
"@

$projects = @(
    @{
        Path = "$subprojects/ffmpeg.wrap"
        URL = "https://gitlab.freedesktop.org/gstreamer/meson-ports/ffmpeg.git"
        Revision = "meson-8.1"
        Provides = @(
            "dependency_names = libavcodec, libavdevice, libavfilter, libavformat, libavutil, libswresample, libswscale"
            "program_names = ffmpeg"
        )
    },
    @{
        # mpv still hard-depends on libass for OSD; Bili danmaku is separate.
        Path = "$subprojects/libass.wrap"
        URL = "https://github.com/libass/libass"
        Revision = "master"
    },
    @{
        Path = "$subprojects/libplacebo.wrap"
        URL = "https://code.videolan.org/videolan/libplacebo.git"
        Revision = "master"
    },
    @{
        Path = "$subprojects/spirv-cross.wrap"
        URL = "https://github.com/KhronosGroup/SPIRV-Cross"
        Revision = "main"
        Method = "cmake"
    }
)

foreach ($project in $projects) {
    $content = @"
[wrap-git]
url = $($project.URL)
revision = $($project.Revision)
depth = 1
clone-recursive = true
"@
    if ($project.ContainsKey('Method')) {
        $content += "`nmethod = $($project.Method)"
    }
    if ($project.ContainsKey('Provides')) {
        $provide = "[provide]`n$($project.Provides -join "`n")"
        $content += "`n$provide"
    }
    Set-Content -Path $project.Path -Value $content
}

# FFmpeg whitelist / blacklist (meson-ports feature options)
$ffmpegArgs = @(
    # External deps
    "-Dffmpeg:libvpl=enabled",
    "-Dffmpeg:libdav1d=disabled",
    "-Dffmpeg:libaom=disabled",
    "-Dffmpeg:libjxl=disabled",
    "-Dffmpeg:ffnvcodec=disabled",
    "-Dffmpeg:vulkan=disabled",
    "-Dffmpeg:programs=disabled",
    "-Dffmpeg:tests=disabled",
    "-Dffmpeg:network=enabled",
    "-Dffmpeg:gpl=enabled",

    # Decoders: only QSV AVC + AAC soft
    "-Dffmpeg:h264_qsv_decoder=enabled",
    "-Dffmpeg:aac_decoder=enabled",
    "-Dffmpeg:h264_decoder=disabled",
    "-Dffmpeg:hevc_decoder=disabled",
    "-Dffmpeg:av1_decoder=disabled",
    "-Dffmpeg:hevc_qsv_decoder=disabled",
    "-Dffmpeg:av1_qsv_decoder=disabled",
    "-Dffmpeg:vp8_qsv_decoder=disabled",
    "-Dffmpeg:vp9_qsv_decoder=disabled",
    "-Dffmpeg:mpeg2_qsv_decoder=disabled",
    "-Dffmpeg:mjpeg_qsv_decoder=disabled",
    "-Dffmpeg:vc1_qsv_decoder=disabled",
    "-Dffmpeg:vvc_qsv_decoder=disabled",
    "-Dffmpeg:h264_cuvid_decoder=disabled",
    "-Dffmpeg:h264_amf_decoder=disabled",
    "-Dffmpeg:libdav1d_decoder=disabled",
    "-Dffmpeg:libaom_av1_decoder=disabled",

    # Encoders off
    "-Dffmpeg:h264_qsv_encoder=disabled",
    "-Dffmpeg:hevc_qsv_encoder=disabled",
    "-Dffmpeg:av1_qsv_encoder=disabled",
    "-Dffmpeg:h264_nvenc_encoder=disabled",
    "-Dffmpeg:h264_amf_encoder=disabled",

    # Parsers / BSF needed for MP4/fMP4/HLS-style annex-B
    "-Dffmpeg:h264_parser=enabled",
    "-Dffmpeg:aac_parser=enabled",
    "-Dffmpeg:h264_mp4toannexb_bsf=enabled",
    "-Dffmpeg:aac_adtstoasc_bsf=enabled",
    "-Dffmpeg:extract_extradata_bsf=enabled",

    # Demux / protocols for Bilibili HTTP Range + DASH segments
    "-Dffmpeg:mov_demuxer=enabled",
    "-Dffmpeg:mpegts_demuxer=enabled",
    "-Dffmpeg:dash_demuxer=enabled",
    "-Dffmpeg:aac_demuxer=enabled",
    "-Dffmpeg:h264_demuxer=enabled",
    "-Dffmpeg:file_protocol=enabled",
    "-Dffmpeg:http_protocol=enabled",
    "-Dffmpeg:https_protocol=enabled",
    "-Dffmpeg:tcp_protocol=enabled",
    "-Dffmpeg:tls_protocol=enabled",
    "-Dffmpeg:crypto_protocol=enabled",

    # Minimal filters for mpv lavfi pipeline / QSV system-memory path
    "-Dffmpeg:aresample_filter=enabled",
    "-Dffmpeg:aformat_filter=enabled",
    "-Dffmpeg:format_filter=enabled",
    "-Dffmpeg:scale_filter=enabled",
    "-Dffmpeg:hwdownload_filter=enabled",
    "-Dffmpeg:hwupload_filter=enabled",
    "-Dffmpeg:hwmap_filter=enabled",

    # Disable competing H.264 hwaccels (QSV decoder path only)
    "-Dffmpeg:h264_d3d11va_hwaccel=disabled",
    "-Dffmpeg:h264_d3d11va2_hwaccel=disabled",
    "-Dffmpeg:h264_d3d12va_hwaccel=disabled",
    "-Dffmpeg:h264_dxva2_hwaccel=disabled",
    "-Dffmpeg:h264_nvdec_hwaccel=disabled",
    "-Dffmpeg:h264_vulkan_hwaccel=disabled"
)

if (Test-Path $buildDir) {
    Remove-Item -Recurse -Force $buildDir
}

$mesonSetup = @(
    "setup", $buildDir,
    "--prefix=$prefix",
    "--libdir=lib",
    "--wrap-mode=forcefallback",
    "--default-library=shared",
    "--buildtype=release",
    "-Db_vscrt=mt",
    "-Dlibmpv=true",
    "-Dcplayer=false",
    "-Dtests=false",
    "-Dgpl=true",
    "-Dd3d11=enabled",
    "-Dwasapi=enabled",
    "-Dshaderc=enabled",
    "-Dspirv-cross=enabled",
    "-Djavascript=disabled",
    "-Dlua=disabled",
    "-Dsubrandr=disabled",
    "-Dlibarchive=disabled",
    "-Dvapoursynth=disabled",
    "-Drubberband=disabled",
    "-Dlibbluray=disabled",
    "-Ddvdnav=disabled",
    "-Dcdda=disabled",
    "-Duchardet=disabled",
    "-Dzimg=disabled",
    "-Djpeg=disabled",
    "-Dlcms2=disabled",
    "-Dlibavdevice=disabled",
    "-Dlibcurl=disabled",
    "-Dcuda-hwaccel=disabled",
    "-Dcuda-interop=disabled",
    "-Dd3d-hwaccel=disabled",
    "-Dd3d9-hwaccel=disabled",
    "-Damf=disabled",
    "-Dvulkan=disabled",
    "-Dgl=disabled",
    "-Degl=disabled",
    "-Degl-angle=disabled",
    "-Dplain-gl=disabled",
    "-Dwayland=disabled",
    "-Dx11=disabled",
    "-Ddrm=disabled",
    "-Dvaapi=disabled",
    "-Dvdpau=disabled",
    "-Dwin32-smtc=disabled",
    "-Dlibplacebo:demos=false",
    "-Dlibplacebo:tests=false",
    "-Dlibplacebo:vulkan=disabled",
    "-Dlibplacebo:opengl=disabled",
    "-Dlibplacebo:d3d11=enabled",
    "-Dlibplacebo:shaderc=enabled",
    "-Dlibplacebo:lcms=disabled",
    "-Dlibass:test=disabled",
    "-Dharfbuzz:freetype=enabled",
    "-Dxxhash:inline-all=true",
    "-Dxxhash:cli=false"
) + $ffmpegArgs

Invoke-Native meson $mesonSetup
Invoke-Native meson @("compile", "-C", $buildDir, "libmpv")

# Locate shared libmpv output
$candidates = @(
    Get-ChildItem -Path $buildDir -Recurse -Filter "mpv-*.dll" -ErrorAction SilentlyContinue
    Get-ChildItem -Path $buildDir -Recurse -Filter "mpv.dll" -ErrorAction SilentlyContinue
    Get-ChildItem -Path $buildDir -Recurse -Filter "libmpv*.dll" -ErrorAction SilentlyContinue
) | Where-Object { $_ -ne $null }

if (-not $candidates -or $candidates.Count -eq 0) {
    throw "libmpv DLL not found under $buildDir"
}

$builtDll = $candidates | Sort-Object FullName | Select-Object -First 1
Write-Host "Built DLL: $($builtDll.FullName)"

$outDll = Join-Path $artifactDir "libmpv-2.dll"
Copy-Item -Force $builtDll.FullName $outDll

# Bundle oneVPL dispatcher DLL(s)
Get-ChildItem -Path $prefix -Recurse -Include "libvpl.dll", "vpl.dll", "libmfx.dll" -ErrorAction SilentlyContinue |
    ForEach-Object { Copy-Item -Force $_.FullName (Join-Path $artifactDir $_.Name) }

# Drop PDBs from artifact tree if any were copied
Get-ChildItem -Path $artifactDir -Filter "*.pdb" -ErrorAction SilentlyContinue | Remove-Item -Force

Write-Host "FFI artifacts:"
Get-ChildItem $artifactDir | Format-Table Name, Length
