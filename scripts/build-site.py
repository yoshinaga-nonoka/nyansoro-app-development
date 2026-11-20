#!/usr/bin/env python3
# 公開用サイト（Cloudflare Pages）を build/site/ に作る。
#   python3 scripts/build-site.py
# docs/privacy-policy.md → privacy-policy.html、docs/app-ads.txt はサイトのいちばん上に置く。
# お問い合わせはメール（CONTACT_EMAIL）。フォームを使うときは CONTACT_FORM_URL に入れると /contact から転送する。
import html
import os
import re
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "build", "site")
CONTACT_EMAIL = "yoshi.app.contact+nyansoro@gmail.com"
CONTACT_FORM_URL = ""  # 例: https://forms.gle/xxxxxxxx

CSS = """
:root { --bg:#F8F4FB; --surface:#FFFFFF; --ink:#4A3F5C; --soft:#776D8D; --line:#ECE4F3; --pink:#C2447A; }
@media (prefers-color-scheme: dark) { :root { --bg:#1D1A29; --surface:#2A2639; --ink:#F2EDFA; --soft:#BAB1CE; --line:#3A3450; --pink:#FF9FC6; } }
* { box-sizing: border-box; }
body { margin:0; background:var(--bg); color:var(--ink); font-family:-apple-system,"Hiragino Sans","Hiragino Kaku Gothic ProN","Noto Sans JP",sans-serif; line-height:1.8; }
main { max-width:760px; margin:0 auto; padding:32px 16px 64px; }
h1 { font-size:1.6rem; line-height:1.4; }
h2 { font-size:1.2rem; margin-top:2em; padding-bottom:.2em; border-bottom:2px solid var(--line); }
h3 { font-size:1.05rem; margin-top:1.5em; }
a { color:var(--pink); word-break:break-all; }
.card { background:var(--surface); border:2px solid var(--line); border-radius:20px; padding:20px; }
table { border-collapse:collapse; width:100%; font-size:.95rem; }
th, td { border:1px solid var(--line); padding:8px; text-align:left; vertical-align:top; }
.table { overflow-x:auto; }
footer { margin-top:48px; color:var(--soft); font-size:.9rem; }
"""


def page(title, body):
    return f"""<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)}</title>
<style>{CSS}</style>
</head>
<body>
<main>
{body}
<footer><a href="/">にゃんそろ</a> ・ <a href="/privacy-policy">プライバシーポリシー</a> ・ <a href="/contact">お問い合わせ</a></footer>
</main>
</body>
</html>
"""


def inline(text):
    t = html.escape(text)
    t = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", t)
    t = re.sub(r"(https?://[^\s<、）)]+)", r'<a href="\1">\1</a>', t)
    # メールアドレスはリンクに（「+」はメールアプリで空白と読まれないよう %2B にする）
    return re.sub(r"([\w.+-]+@[\w-]+\.[\w.]+)", lambda m: f'<a href="mailto:{m.group(1).replace("+", "%2B")}">{m.group(1)}</a>', t)


def markdown_to_html(md):
    """このポリシーで使う書き方（見出し・段落・箇条書き・表）だけを変換する"""
    out, para, items, rows = [], [], [], []

    def flush():
        if para:
            out.append("<p>" + "<br>".join(inline(l) for l in para) + "</p>")
            para.clear()
        if items:
            out.append("<ul>" + "".join(f"<li>{inline(i)}</li>" for i in items) + "</ul>")
            items.clear()
        if rows:
            head, *body = [r for r in rows if not re.fullmatch(r"\|[-| ]+\|", r)]
            cells = lambda r: [c.strip() for c in r.strip("|").split("|")]
            t = "<tr>" + "".join(f"<th>{inline(c)}</th>" for c in cells(head)) + "</tr>"
            t += "".join("<tr>" + "".join(f"<td>{inline(c)}</td>" for c in cells(r)) + "</tr>" for r in body)
            out.append(f'<div class="table"><table>{t}</table></div>')
            rows.clear()

    for line in md.splitlines():
        line = line.rstrip()
        if line.startswith("<!--"):
            continue
        m = re.match(r"(#{1,3}) (.+)", line)
        if m:
            flush()
            n = len(m.group(1))
            out.append(f"<h{n}>{inline(m.group(2))}</h{n}>")
        elif line.startswith("- "):
            if para:
                flush()
            items.append(line[2:])
        elif line.startswith("|"):
            rows.append(line)
        elif not line:
            flush()
        else:
            if items or rows:
                flush()
            para.append(line)
    flush()
    return "\n".join(out)


def main():
    shutil.rmtree(OUT, ignore_errors=True)
    os.makedirs(OUT)
    with open(os.path.join(ROOT, "docs", "privacy-policy.md"), encoding="utf-8") as f:
        policy = markdown_to_html(f.read())
    write("privacy-policy.html", page("にゃんそろ プライバシーポリシー", policy))
    write("index.html", page("にゃんそろ", """<h1>にゃんそろ</h1>
<div class="card">
<p>猫の絵柄を3枚ずつそろえる、かんたんな麻雀風ゲームです（iPhone / iPad）。</p>
<p>開発者：Yoshi.App</p>
</div>"""))
    if CONTACT_FORM_URL:
        contact = f'<p>お問い合わせは <a href="{html.escape(CONTACT_FORM_URL)}">お問い合わせフォーム</a> からお送りください。</p>'
    else:
        mail = html.escape(CONTACT_EMAIL)
        contact = (f'<div class="card"><p>「にゃんそろ」についてのお問い合わせは、次のメールアドレスまでお送りください。</p>'
                   f'<p><a href="mailto:{mail.replace("+", "%2B")}?subject=にゃんそろ お問い合わせ">{mail}</a></p>'
                   '<p>お返事までお時間をいただくことがあります。</p></div>')
    write("contact.html", page("にゃんそろ お問い合わせ", "<h1>お問い合わせ</h1>\n" + contact))
    shutil.copy(os.path.join(ROOT, "docs", "app-ads.txt"), os.path.join(OUT, "app-ads.txt"))
    redirects = "/privacy /privacy-policy 301\n"
    if CONTACT_FORM_URL:
        redirects += f"/contact {CONTACT_FORM_URL} 302\n"
    write("_redirects", redirects)
    print("build/site:", sorted(os.listdir(OUT)))


def write(name, text):
    with open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
        f.write(text)


if __name__ == "__main__":
    main()
