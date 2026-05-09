# SUI-GEN Website

株式会社SUI-GEN コーポレートサイト（静的）。

- Hosting: Cloudflare Pages
- Domain: sui-gen.jp
- Pages: `index.html` / `about.html` / `real.html` / `tech.html`

## ローカル確認

```bash
# 任意のサーバで OK
python3 -m http.server 8000
# → http://localhost:8000
```

## デプロイ

`main` ブランチへの push で Cloudflare Pages が自動ビルド・公開する想定。
（ビルドコマンドなし、出力ディレクトリ `/`。静的HTMLそのまま配信）
