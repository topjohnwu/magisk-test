#!/usr/bin/env bash

set -xe

CF_HOME='/home/runner/aosp_cf_x86_64_phone'

install_bazel() {
  sudo apt-get install -y apt-transport-https curl gnupg
  curl -fsSL https://bazel.build/bazel-release.pub.gpg | gpg --dearmor >bazel-archive-keyring.gpg
  sudo mv bazel-archive-keyring.gpg /usr/share/keyrings
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/bazel-archive-keyring.gpg] https://storage.googleapis.com/bazel-apt stable jdk1.8" | sudo tee /etc/apt/sources.list.d/bazel.list
  sudo apt-get update && sudo apt-get install bazel zip unzip
}

build_cf() {
  git clone https://github.com/google/android-cuttlefish
  cd android-cuttlefish
  # We only want to build the base package
  sed -i '$ d' tools/buildutils/build_packages.sh
  tools/buildutils/build_packages.sh
  sudo dpkg -i ./cuttlefish-base_*_*64.deb || sudo apt-get install -f
  cd ../
}

setup_env() {
  echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' | sudo tee /etc/udev/rules.d/99-kvm4all.rules
  sudo udevadm control --reload-rules
  sudo udevadm trigger
  sudo usermod -aG kvm,cvdnetwork,render $USER
}

download_cf() {
  local BUILD_ID=$(curl -sL https://ci.android.com/builds/branches/aosp-main/status.json | \
    jq -r '.targets[] | select(.name == "aosp_cf_x86_64_phone-trunk_staging-userdebug") | .last_known_good_build')
  local SYS_IMG_URL="https://ci.android.com/builds/submitted/${BUILD_ID}/aosp_cf_x86_64_phone-trunk_staging-userdebug/latest/raw/aosp_cf_x86_64_phone-img-${BUILD_ID}.zip"
  local HOST_PKG_URL="https://ci.android.com/builds/submitted/${BUILD_ID}/aosp_cf_x86_64_phone-trunk_staging-userdebug/latest/raw/cvd-host_package.tar.gz"
  curl -L $SYS_IMG_URL -o aosp_cf_x86_64_phone-img.zip
  curl -LO $HOST_PKG_URL
  mkdir -p $CF_HOME
  tar xvf cvd-host_package.tar.gz -C $CF_HOME
  unzip aosp_cf_x86_64_phone-img.zip -d $CF_HOME
}

run_cf() {
  HOME=$CF_HOME $CF_HOME/bin/launch_cvd --daemon --resume=false --enable_sandbox=false
  adb devices
}

case "$1" in
  setup )
    install_bazel
    build_cf
    setup_env
    download_cf
    ;;
  run )
    run_cf
    ;;
  * )
    exit 1
    ;;
esac
