#!/usr/bin/env python3
"""TestFlight の内部テストを用意する（App Store Connect API）。

- 内部テストのグループ「開発チーム」がなければ作る（全部のビルドが自動で届く設定）
- チームのユーザー全員を、そのグループのテスターにする
- 最新ビルドの処理状況を表示する

使う環境変数：ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8, BUNDLE_ID
リポジトリが公開なので、ログにはメールアドレスや名前を出さない（人数だけ）。
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

import jwt  # PyJWT

API = "https://api.appstoreconnect.apple.com"
GROUP_NAME = "開発チーム"


def token():
    now = int(time.time())
    return jwt.encode(
        {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 15 * 60, "aud": "appstoreconnect-v1"},
        os.environ["ASC_KEY_P8"],
        algorithm="ES256",
        headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"},
    )


TOKEN = token()


def call(method, path, body=None):
    req = urllib.request.Request(API + path, method=method)
    req.add_header("Authorization", "Bearer " + TOKEN)
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, data) as r:
            raw = r.read()
            return r.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        raw = e.read()
        try:
            return e.code, json.loads(raw)
        except ValueError:
            return e.code, {"raw": raw.decode(errors="replace")}


def must(status, res, what):
    if status >= 300:
        errs = [f"{x.get('status')} {x.get('code')}: {x.get('title')} / {x.get('detail')}" for x in res.get("errors", [])]
        print(f"::error::{what} に失敗（HTTP {status}）: " + " | ".join(errs or [str(res)[:300]]))
        sys.exit(1)
    return res


# 1. アプリ
bid = os.environ.get("BUNDLE_ID", "com.nonoka.nyansoro")
res = must(*call("GET", f"/v1/apps?filter[bundleId]={bid}&limit=1"), "アプリの検索")
if not res["data"]:
    print(f"::error::App Store Connect に {bid} のアプリが見つかりません（「マイ App」で新規作成が必要）")
    sys.exit(1)
app_id = res["data"][0]["id"]
print(f"アプリ: {res['data'][0]['attributes'].get('name')}（{bid}）")

# 2. 内部テストのグループ
res = must(*call("GET", f"/v1/apps/{app_id}/betaGroups?limit=200"), "グループの一覧")
group = next((g for g in res["data"] if g["attributes"].get("isInternalGroup") and g["attributes"].get("name") == GROUP_NAME), None)
if group:
    print(f"グループ「{GROUP_NAME}」はもうある")
    if not group["attributes"].get("hasAccessToAllBuilds"):
        must(*call("PATCH", f"/v1/betaGroups/{group['id']}", {
            "data": {"type": "betaGroups", "id": group["id"], "attributes": {"hasAccessToAllBuilds": True}}}), "全ビルドを届ける設定")
        print("  → 全部のビルドが自動で届くように変更")
else:
    res = must(*call("POST", "/v1/betaGroups", {"data": {
        "type": "betaGroups",
        "attributes": {"name": GROUP_NAME, "isInternalGroup": True, "hasAccessToAllBuilds": True},
        "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
    }}), "グループの作成")
    group = res["data"]
    print(f"グループ「{GROUP_NAME}」を作った（全部のビルドが自動で届く）")
gid = group["id"]

# 3. チームのユーザーをテスターに
res = must(*call("GET", "/v1/users?limit=200"), "チームのユーザー一覧")
users = res["data"]
res = must(*call("GET", f"/v1/betaGroups/{gid}/betaTesters?limit=200"), "グループのテスター一覧")
already = {(t["attributes"].get("email") or "").lower() for t in res["data"]}
added = skipped = 0
for u in users:
    a = u["attributes"]
    email = a.get("username") or ""
    print(f"::add-mask::{email}")
    if not email or email.lower() in already:
        skipped += 1
        continue
    st, r = call("POST", "/v1/betaTesters", {"data": {
        "type": "betaTesters",
        "attributes": {"email": email, "firstName": a.get("firstName") or "", "lastName": a.get("lastName") or ""},
        "relationships": {"betaGroups": {"data": [{"type": "betaGroups", "id": gid}]}},
    }})
    if st == 409:
        # テスターとしてはもういる → グループに入れるだけ
        st2, r2 = call("GET", f"/v1/betaTesters?filter[email]={urllib.request.quote(email)}&limit=1")
        if st2 < 300 and r2.get("data"):
            must(*call("POST", f"/v1/betaGroups/{gid}/relationships/betaTesters",
                       {"data": [{"type": "betaTesters", "id": r2["data"][0]["id"]}]}), "テスターをグループに追加")
        else:
            must(st, r, "テスターの追加")
    else:
        must(st, r, "テスターの追加")
    added += 1
print(f"テスター: 追加 {added} 人、もう入っていた {skipped} 人（チームのユーザー {len(users)} 人）")

# 4. 最新ビルドの状況
res = must(*call("GET", f"/v1/builds?filter[app]={app_id}&sort=-uploadedDate&limit=3"), "ビルドの一覧")
for b in res["data"]:
    a = b["attributes"]
    print(f"ビルド {a.get('version')}: {a.get('processingState')}（アップロード {a.get('uploadedDate')}）")
print("iPhone に「TestFlight」アプリを入れて、同じ Apple アカウントでサインインすると「にゃんそろ」が出ます。")
