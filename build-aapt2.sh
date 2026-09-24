#!/bin/bash
set -e

echo "=== Setup ==="
apt-get update -qq

echo "=== Download NDK r26b ==="
cd /opt
if [ ! -d /opt/ndk ]; then
    wget -q https://dl.google.com/android/repository/android-ndk-r26b-linux.zip
    unzip -q android-ndk-r26b-linux.zip
    mv android-ndk-r26b ndk
    rm android-ndk-r26b-linux.zip
fi
export ANDROID_NDK=/opt/ndk

echo "=== Init AOSP repo ==="
mkdir -p /work/aosp && cd /work/aosp

curl -s https://storage.googleapis.com/git-repo-downloads/repo > /usr/local/bin/repo
chmod +x /usr/local/bin/repo

repo init -u https://android.googlesource.com/platform/manifest \
    -b android-14.0.0_r1 --depth=1 2>&1 | tail -3

echo "=== Sync (minimal set yang benar) ==="
repo sync -c -j8 --no-tags --no-clone-bundle --force-sync \
    build/soong \
    build/blueprint \
    build/make \
    build/kati \
    frameworks/base \
    frameworks/native \
    system/core \
    system/logging \
    system/libbase \
    system/libziparchive \
    system/libprocinfo \
    system/tools/aidl \
    system/unwinding \
    system/security \
    external/zlib \
    external/googletest \
    external/protobuf \
    external/fmtlib \
    external/libpng \
    external/freetype \
    external/selinux \
    external/tinyxml2 \
    external/expat \
    external/libcxx \
    external/libcxxabi \
    external/boringssl \
    external/modp_b64 \
    external/sqlite \
    external/icu \
    external/re2 \
    external/safe-iop \
    external/markdown \
    prebuilts/clang/host/linux-x86 \
    prebuilts/build-tools \
    prebuilts/gcc/linux-x86 \
    prebuilts/go/linux-x86 \
    prebuilts/misc \
    prebuilts/sdk \
    prebuilts/jdk \
    tools/repohooks \
    tools/metadata 2>&1 | tail -10

echo "=== Cek microfactory ==="
if [ ! -f /work/aosp/build/blueprint/microfactory/microfactory.bash ]; then
    echo "❌ microfactory masih tidak ada"
    echo "Isi build/blueprint:"
    ls /work/aosp/build/blueprint/ 2>/dev/null || echo "(folder tidak ada)"
    exit 1
fi
echo "✅ microfactory ada"

echo "=== Setup env & build host aapt2 ==="
cd /work/aosp
source build/envsetup.sh
lunch aosp_arm64-userdebug 2>&1 | tail -3
m -j8 aapt2 2>&1 | tail -15

HOST_AAPT2="/work/aosp/out/host/linux-x86/bin/aapt2"
mkdir -p /work/out
if [ -f "$HOST_AAPT2" ]; then
    cp "$HOST_AAPT2" /work/out/aapt2-x86_64
    echo "✅ Host aapt2 saved"
    file /work/out/aapt2-x86_64
fi

echo "=== Cross-compile untuk ARM64 ==="
AAPT2_SRC="/work/aosp/frameworks/base/tools/aapt2"
if [ ! -d "$AAPT2_SRC" ]; then
    AAPT2_SRC="/work/aosp/tools/aapt2"
fi
echo "Source: $AAPT2_SRC"
ls "$AAPT2_SRC" 2>/dev/null | head -10

mkdir -p /work/aapt2-arm
cd /work/aapt2-arm

cat > CMakeLists.txt << 'CMEOF'
cmake_minimum_required(VERSION 3.10)
project(aapt2_android CXX C)
set(CMAKE_CXX_STANDARD 17)
set(AOSP_ROOT /work/aosp)
set(AAPT2_SRC ${AOSP_ROOT}/frameworks/base/tools/aapt2)
if(NOT EXISTS ${AAPT2_SRC})
    set(AAPT2_SRC ${AOSP_ROOT}/tools/aapt2)
endif()
file(GLOB_RECURSE AAPT2_SOURCES "${AAPT2_SRC}/*.cpp")
list(FILTER AAPT2_SOURCES EXCLUDE REGEX "_test\\.cpp$")
list(FILTER AAPT2_SOURCES EXCLUDE REGEX "/tests?/")
list(LENGTH AAPT2_SOURCES N)
message(STATUS "Source count: ${N}")
add_executable(aapt2 ${AAPT2_SOURCES})
target_include_directories(aapt2 PRIVATE
    ${AAPT2_SRC}
    ${AOSP_ROOT}/frameworks/base/libs/androidfw/include
    ${AOSP_ROOT}/system/core/libcutils/include
    ${AOSP_ROOT}/system/core/libutils/include
    ${AOSP_ROOT}/system/core/liblog/include
    ${AOSP_ROOT}/system/libbase/include
    ${AOSP_ROOT}/system/libziparchive/include
    ${AOSP_ROOT}/external/zlib
    ${AOSP_ROOT}/external/libpng
    ${AOSP_ROOT}/external/freetype/include
    ${AOSP_ROOT}/external/protobuf/src
)
target_link_libraries(aapt2 z log android)
CMEOF

cmake -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-26 \
    -DANDROID_STL=c++_static \
    -DCMAKE_BUILD_TYPE=Release \
    -S . -B build 2>&1 | tail -10 || echo "CMake config gagal"

cmake --build build -j8 2>&1 | tail -30 || echo "Build gagal"

if [ -f build/aapt2 ]; then
    cp build/aapt2 /work/out/aapt2-arm64-v8a
    echo "✅ ARM64 binary jadi"
fi

cat > /work/out/README.txt << 'EOF'
aapt2 build result
- aapt2-x86_64: host binary
- aapt2-arm64-v8a: ARM64 (kalau ada)
EOF

echo "=== HASIL ==="
ls -la /work/out/
