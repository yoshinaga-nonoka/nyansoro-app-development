#!/bin/bash
# App Store に載せる画面を、提出に必要な大きさで撮る（Mac / GitHub Actions 用）
#   iPhone 6.9インチ（1320×2868）と iPad 13インチ（2064×2752）
# 使い方: scripts/store-screenshots.sh   → store/iphone-69/ と store/ipad-13/ に PNG ができる
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/dd/Build/Products/Debug-iphonesimulator/Nyansoro.app
rm -rf store && mkdir -p store/iphone-69 store/ipad-13

if [ ! -d "$APP" ]; then
  echo "== ビルド"
  xcodebuild -project Nyansoro.xcodeproj -scheme Nyansoro -destination 'generic/platform=iOS Simulator' -configuration Debug \
    -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO build > build.log 2>&1 || { grep -E "error:" build.log | sort -u | head -50; exit 1; }
fi
BID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP/Info.plist")
# 提出に必要なものがアプリに入っているか
test -f "$APP/PrivacyInfo.xcprivacy" || { echo "PrivacyInfo.xcprivacy がアプリに入っていない"; exit 1; }
echo "== $BID $(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Info.plist") ($(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$APP/Info.plist"))" \
  "暗号化の申告: $(/usr/libexec/PlistBuddy -c "Print ITSAppUsesNonExemptEncryption" "$APP/Info.plist")"

# 名前が完全に一致する端末の UDID（大きさが決まっているので、似た端末で代用しない）
pick() {
  xcrun simctl list devices available -j > devices.json
  python3 - "$@" <<'PY'
import json, sys
devs = [d for rt, l in json.load(open("devices.json"))["devices"].items() if "iOS" in rt for d in l]
for want in sys.argv[1:]:
    hit = [d for d in devs if d["name"] == want]
    if hit:
        print(hit[-1]["udid"]); sys.exit(0)
sys.stderr.write("見つからない: %s\nある端末: %s\n" % (sys.argv[1:], sorted({d["name"] for d in devs})))
sys.exit(1)
PY
}

start() {
  local U=$1
  xcrun simctl boot "$U" 2>/dev/null || true
  xcrun simctl bootstatus "$U" -b > /dev/null
  xcrun simctl status_bar "$U" override --time 9:41 --batteryLevel 100 --batteryState charged \
    --cellularBars 4 --wifiBars 3 2>/dev/null || true
  xcrun simctl ui "$U" appearance light
  xcrun simctl install "$U" "$APP"
  # 入れた直後の1回目の起動は遅いので、一度起動して慣らしておく
  xcrun simctl launch "$U" "$BID" -scenario title > /dev/null
  sleep 12
  xcrun simctl terminate "$U" "$BID" > /dev/null 2>&1 || true
}

# 撮る順番＝ストアに並べる順番（ファイル名の頭に番号を付ける）
shoot() {
  local U=$1 DIR=$2; shift 2
  local n=1
  for sc in "$@"; do
    xcrun simctl terminate "$U" "$BID" > /dev/null 2>&1 || true
    xcrun simctl launch "$U" "$BID" -scenario "$sc" > /dev/null
    sleep "${WAIT:-8}"
    local f
    f=$(printf "%s/%02d-%s.png" "$DIR" "$n" "$sc")
    xcrun simctl io "$U" screenshot "$f" > /dev/null 2>&1
    echo "  $f ($(sips -g pixelWidth -g pixelHeight "$f" | awk '/pixel/{printf "%s ", $2}'))"
    n=$((n + 1))
  done
}

PHONE=$(pick "iPhone 17 Pro Max" "iPhone 16 Pro Max")
echo "== iPhone 6.9インチ"
start "$PHONE"
shoot "$PHONE" store/iphone-69 title game riichi round-result rankup help-yaku lesson missions daily-result
xcrun simctl shutdown "$PHONE" || true

PAD=$(pick "iPad Pro 13-inch (M5)" "iPad Pro 13-inch (M4)")
echo "== iPad 13インチ"
start "$PAD"
shoot "$PAD" store/ipad-13 title game riichi round-result help-yaku lesson missions
xcrun simctl shutdown "$PAD" || true
