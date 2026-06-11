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

## 運用設定（Vercel）

### お問い合わせフォーム（`/api/contact`）

お問い合わせフォームは Vercel Serverless Function `api/contact.js` 経由で
Resend API を使い `contact@sui-gen.jp` へメール転送する。

1. [Resend](https://resend.com) で `sui-gen.jp` ドメインを検証し、API キーを発行する
2. Vercel ダッシュボード → 対象プロジェクト → **Settings → Environment Variables** で
   `RESEND_API_KEY` を Production / Preview に設定する
3. 設定後に再デプロイすると有効になる

`RESEND_API_KEY` 未設定の間は API が `503 {"error":"not_configured"}` を返し、
フロント側は `contact@sui-gen.jp` へのメール案内に自動フォールバックする。

### Web Analytics

Vercel ダッシュボード → 対象プロジェクト → **Analytics** タブから
**Web Analytics を Enable** する（全ページに計測スクリプト
`/_vercel/insights/script.js` は組み込み済み。有効化するまで計測されない）。
