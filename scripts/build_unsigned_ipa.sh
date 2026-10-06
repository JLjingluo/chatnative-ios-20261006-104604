#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]] || ! command -v xcodebuild >/dev/null 2>&1; then
  echo 'A Mac with full Xcode and the iOS SDK is required to build a real IPA.' >&2
  exit 1
fi

chatnative_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$chatnative_root"
mkdir -p artifacts
chatnative_build_dir="$(mktemp -d "${TMPDIR:-/tmp}/chatnative-ipa.XXXXXX")"
trap 'rm -rf "$chatnative_build_dir"' EXIT

xcodebuild \
  -project ChatNative.xcodeproj \
  -scheme ChatNative \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$chatnative_build_dir/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY='' \
  build 2>&1 | tee artifacts/xcodebuild.log

chatnative_app="$chatnative_build_dir/DerivedData/Build/Products/Release-iphoneos/ChatNative.app"
chatnative_executable="$chatnative_app/ChatNative"
[[ -f "$chatnative_executable" ]] || { echo 'Compiled app executable not found.' >&2; exit 1; }
file "$chatnative_executable" | grep -q 'arm64' || { echo 'Expected an arm64 iPhone executable.' >&2; exit 1; }
if codesign -d "$chatnative_app" >/dev/null 2>&1; then
  echo 'Expected an unsigned app, but a code signature was found.' >&2
  exit 1
fi

mkdir -p "$chatnative_build_dir/package/Payload"
ditto "$chatnative_app" "$chatnative_build_dir/package/Payload/ChatNative.app"
chatnative_output="$chatnative_root/artifacts/ChatNative-unsigned.ipa"
rm -f "$chatnative_output"
(
  cd "$chatnative_build_dir/package"
  /usr/bin/zip -qry "$chatnative_output" Payload
)
unzip -tq "$chatnative_output"
(
  cd artifacts
  shasum -a 256 ChatNative-unsigned.ipa > ChatNative-unsigned.ipa.sha256
)
echo "Created: $chatnative_output"
echo 'Unsigned IPA: installation still requires device-compatible signing or another supported installation mechanism.'
