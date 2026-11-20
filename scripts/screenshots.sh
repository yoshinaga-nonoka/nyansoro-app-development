#!/bin/bash
# シミュレーターで場面ごとの画面を撮る（Mac / GitHub Actions 用）
# 使い方: scripts/screenshots.sh   → shots/ に PNG ができる
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/dd/Build/Products/Debug-iphonesimulator/Nyansoro.app
mkdir -p shots

echo "== ビルド"
xcodebuild -project Nyansoro.xcodeproj -scheme Nyansoro -destination 'generic/platform=iOS Simulator' -configuration Debug \
  -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO build > build.log 2>&1 || { grep -E "error:" build.log | sort -u | head -50; exit 1; }

# アプリの ID（Xcode で Bundle Identifier を変えても動くように、ビルドしたアプリから読む）
BID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP/Info.plist")
echo "== アプリ: $BID"

# 名前が一致する端末（なければ、その種類の最初の端末）の UDID
pick() {
  xcrun simctl list devices available -j > devices.json
  python3 - "$1" "$2" <<'PY'
import json, sys
want, kind = sys.argv[1], sys.argv[2]
devs = [d for rt, l in json.load(open("devices.json"))["devices"].items() if "iOS" in rt for d in l]
exact = [d for d in devs if d["name"] == want]
any_kind = [d for d in devs if d["name"].startswith(kind)]
print((exact or any_kind)[-1]["udid"])
PY
}

start() {
  local U=$1
  xcrun simctl boot "$U" 2>/dev/null || true
  xcrun simctl bootstatus "$U" -b > /dev/null
  xcrun simctl status_bar "$U" override --time 9:41 --batteryLevel 100 --batteryState charged 2>/dev/null || true
  xcrun simctl install "$U" "$APP"
  # 入れた直後の1回目の起動は遅く、最初の1枚が真っ白になることがあるので、一度起動して慣らしておく
  xcrun simctl launch "$U" "$BID" -scenario title > /dev/null
  sleep 12
  xcrun simctl terminate "$U" "$BID" > /dev/null 2>&1 || true
}

shoot() {
  local U=$1 P=$2; shift 2
  for sc in "$@"; do
    xcrun simctl terminate "$U" "$BID" > /dev/null 2>&1 || true
    xcrun simctl launch "$U" "$BID" -scenario "$sc" > /dev/null
    sleep "${WAIT:-7}"
    xcrun simctl io "$U" screenshot "shots/$P-$sc.png" > /dev/null 2>&1
    echo "  shots/$P-$sc.png"
  done
}

PHONE=$(pick "iPhone 16" "iPhone")
echo "== iPhone ($PHONE)"
start "$PHONE"
xcrun simctl ui "$PHONE" appearance light
shoot "$PHONE" iphone onboarding onboarding-signin onboarding-roles onboarding-riichi practice tutorial tutorial-riichi tutorial-clear riichi help-yaku
shoot "$PHONE" iphone game claim help settings round-result near-miss match-result rankup ranks title revive daily-result streak lesson missions help-cats
WAIT=20 shoot "$PHONE" iphone ad-test
# 広告のプライバシー：年齢の確認・設定の「広告とプライバシー」・追跡の確認・欧州の同意画面（Services/AdPrivacy.swift）
shoot "$PHONE" iphone age-check privacy privacy-child
# 追跡の確認は答えないと次の場面にも残るので、いちばん最後に撮る
WAIT=15 shoot "$PHONE" iphone consent-eea att-prompt
xcrun simctl ui "$PHONE" appearance dark
shoot "$PHONE" iphone-dark title game round-result help-cats onboarding-roles riichi
xcrun simctl shutdown "$PHONE" || true

PAD=$(pick "iPad Pro 11-inch (M4)" "iPad")
echo "== iPad ($PAD)"
start "$PAD"
xcrun simctl ui "$PAD" appearance light
shoot "$PAD" ipad title game help onboarding riichi
