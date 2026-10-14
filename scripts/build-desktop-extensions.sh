#!/usr/bin/env bash
set -euo pipefail
umask 022

# The final image must have the same KDE/Qt ABI as the headers used here.
abi_packages=(kwin kdecoration qt6-qtbase qt6-qtdeclarative qt6-qtsvg
              kf6-kcoreaddons kf6-kconfig kf6-kwindowsystem)
rpm -q "${abi_packages[@]}" > /tmp/runtime-abi.txt

dnf -y install gcc-c++ cmake ninja-build extra-cmake-modules gettext \
    kwin-devel kdecoration-devel libepoxy-devel libdrm-devel vulkan-loader-devel qt6-qtbase-devel qt6-qtdeclarative-devel \
    qt6-qtsvg-devel kf6-kcolorscheme-devel kf6-kconfig-devel \
    kf6-kcoreaddons-devel kf6-kcmutils-devel kf6-ki18n-devel \
    kf6-kwindowsystem-devel kf6-kguiaddons-devel kf6-kiconthemes-devel \
    kf6-frameworkintegration-devel
rpm -q "${abi_packages[@]}" > /tmp/build-abi.txt
diff -u /tmp/runtime-abi.txt /tmp/build-abi.txt

fetch_source() {
    local name="$1" url="$2" revision="$3"
    [[ "$revision" =~ ^[0-9a-f]{40}$ ]]
    git init "/tmp/$name"
    git -C "/tmp/$name" remote add origin "$url"
    git -C "/tmp/$name" fetch --depth=1 origin "$revision"
    git -C "/tmp/$name" checkout --detach FETCH_HEAD
    test "$(git -C "/tmp/$name" rev-parse HEAD)" = "$revision"
}

fetch_source smooth-swipe https://github.com/cesp99/smooth-swipe.git "$SMOOTH_SWIPE_REV"
fetch_source klassy https://github.com/paulmcauley/klassy.git "$KLASSY_REV"

cmake -S /tmp/smooth-swipe -B /tmp/smooth-swipe/build -G Ninja \
    -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release \
    -DKDE_INSTALL_LIBDIR=lib64
cmake --build /tmp/smooth-swipe/build --parallel 2
DESTDIR=/out cmake --install /tmp/smooth-swipe/build

cmake -S /tmp/klassy -B /tmp/klassy/build -G Ninja \
    -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release \
    -DKDE_INSTALL_LIBDIR=lib64 -DKDE_INSTALL_USE_QT_SYS_PATHS=ON \
    -DBUILD_TESTING=OFF -DBUILD_QT5=OFF -DBUILD_QT6=ON
cmake --build /tmp/klassy/build --parallel 2
DESTDIR=/out cmake --install /tmp/klassy/build

install -Dm644 /tmp/smooth-swipe/LICENSE \
    /out/usr/share/licenses/smooth-swipe/LICENSE
mkdir -p /out/usr/share/licenses/klassy
cp -a /tmp/klassy/LICENSES/. /out/usr/share/licenses/klassy/
# Runtime plugins and data only; CMake development exports are not needed.
rm -rf /out/usr/include /out/usr/lib64/cmake
