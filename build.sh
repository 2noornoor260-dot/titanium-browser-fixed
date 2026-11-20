```bash
#!/bin/bash

set -e

source common.sh

export VERSION=$(grep -m1 -o '[0-9]\+\(\.[0-9]\+\)\{3\}' vanadium/args.gn)
export CHROMIUM_SOURCE=https://chromium.googlesource.com/chromium/src.git
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get install -y sudo lsb-release file nano git curl python3 python3-pillow imagemagick librsvg2-bin

sudo dpkg --add-architecture i386
sudo apt-get update
sudo apt-get install -y libgcc-s1:i386

git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git

export PATH="$PWD/depot_tools:$PATH"

mkdir -p chromium/src/out/Default
cd chromium/src

git init
git remote add origin "$CHROMIUM_SOURCE"
git fetch --depth 1 "$CHROMIUM_SOURCE" "+refs/tags/$VERSION:chromium_$VERSION"
git checkout "$VERSION"

cp "$SCRIPT_DIR/.gclient" ../.gclient

# Remove unnecessary patches
rm -rf "$SCRIPT_DIR"/vanadium/patches/*trichrome-{apk-build-targets,browser-apk-targets}.patch
rm -rf "$SCRIPT_DIR"/vanadium/patches/*{detailed,supported}-language*.patch
rm -rf "$SCRIPT_DIR"/vanadium/patches/*javascript-optimizer-{site-setting,settings-UI}.patch
rm -rf "$SCRIPT_DIR"/vanadium/patches/*component-updates.patch
rm -rf "$SCRIPT_DIR"/vanadium/patches/*{pdf,PDF,for-content-public,toolbar-button,configs-from-config-app,config-app-parsing,new-tab-card,predictive-back}*.patch

replace "$SCRIPT_DIR/vanadium/patches" "VANADIUM" "TITANIUM"
replace "$SCRIPT_DIR/vanadium/patches" "Vanadium" "Titanium"
replace "$SCRIPT_DIR/vanadium/patches" "vanadium" "titanium"

git am --whitespace=nowarn --keep-non-patch "$SCRIPT_DIR"/vanadium/patches/*.patch

gclient sync -D --no-history --nohooks
gclient runhooks

./build/install-build-deps.sh --no-prompt

source "$SCRIPT_DIR/patch.sh"

cp "$SCRIPT_DIR/args.gn" out/Default/args.gn

gn gen out/Default

mkdir -p out/tmp out/release

autoninja -C out/Default chrome_public_apk

mv $(find out/Default/apks -name 'Chrome*.apk') "out/tmp/$VERSION-armeabi-v7a.apk"

sed -i 's/target_cpu = "arm"/target_cpu = "arm64"/' out/Default/args.gn

autoninja -C out/Default chrome_public_apk chrome_public_bundle

mv $(find out/Default/apks -name 'Chrome*.apk') "out/tmp/$VERSION-arm64-v8a.apk"
mv $(find out/Default/apks -name 'Chrome*.aab') "out/tmp/$VERSION-arm64-v8a.aab"

# Signing setup
export PATH="$PWD/third_party/jdk/current/bin/:$PATH"
export ANDROID_HOME="$PWD/third_party/android_sdk/public"

mkdir -p "$SCRIPT_DIR/keys"

keytool -genkeypair -noprompt \
    -keystore "$SCRIPT_DIR/keys/test.jks" \
    -storetype JKS \
    -storepass android \
    -keypass android \
    -alias titanium \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -dname "CN=Titanium,O=Personal,C=US"

printf 'keyAlias=titanium\nkeyPassword=android\nstorePassword=android\n' > "$SCRIPT_DIR/keys/local.properties"

# Sign APK and AAB
sign_apk "out/tmp/$VERSION-armeabi-v7a.apk" "out/release/$VERSION-armeabi-v7a.apk"

sign_apk "out/tmp/$VERSION-arm64-v8a.apk" "out/release/$VERSION-arm64-v8a.apk"

sign_aab "out/tmp/$VERSION-arm64-v8a.aab" "out/release/$VERSION-arm64-v8a.aab"

rm -rf "$SCRIPT_DIR/keys"
```
