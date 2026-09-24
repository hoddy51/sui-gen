# Google Drive → GitHub 自動同期セットアップ

Google Drive の `sui-gen-company/operations/` 配下を、GitHub Actions が毎朝
このリポジトリの `drive/` へ片方向ミラーする。Mac mini の電源は不要。

## 構成

```
Google Drive（正）                    GitHub リポジトリ（ミラー）
  operations/
    CLAUDE.md          ──┐
    workflows/**       ──┼──► Actions (毎朝 06:00 JST) ──► drive/
    knowledge/**       ──┘                                   └ 差分があれば自動コミット

  reports/ inbox/ output/ meetings/ finance/ notion/ handoffs/
    → 同期しない（生成物・日次ログ。git に入れるとコミットノイズになる）
```

**片方向である。** Drive が常に正で、`drive/` 以下をリポジトリ側で編集しても
次回の同期で上書き・削除される。双方向にすると必ず競合するため意図的にこうしている。

## 1. Google Cloud でサービスアカウントを作る

1. <https://console.cloud.google.com/> でプロジェクトを作成（既存のものでもよい）
2. 「API とサービス」→「ライブラリ」→ **Google Drive API** を有効化
3. 「API とサービス」→「認証情報」→「認証情報を作成」→ **サービス アカウント**
   - 名前は `github-drive-sync` など。ロールの付与は不要（Drive 側の共有で制御する）
4. 作成したサービスアカウント →「キー」タブ →「鍵を追加」→「新しい鍵を作成」→ **JSON**
   - JSON ファイルがダウンロードされる。これが認証情報そのものなので取り扱いに注意
5. サービスアカウントのメールアドレスを控える
   （`github-drive-sync@<プロジェクトID>.iam.gserviceaccount.com` の形式）

## 2. Drive フォルダを共有する

Drive で `operations` フォルダを開き、上で控えたサービスアカウントのメールアドレスに
**閲覧者**として共有する。読み取り専用なので編集者にする必要はない。

> Google Workspace で外部共有が制限されている場合、サービスアカウント宛の共有が
> ブロックされることがある。その場合は管理コンソールで対象フォルダの共有を許可するか、
> 共有ドライブにサービスアカウントをメンバー（閲覧者）として追加する。

## 3. GitHub に値を登録する

`Settings` → `Secrets and variables` → `Actions`

**Secrets タブ**（暗号化される）

| 名前 | 値 |
|---|---|
| `GDRIVE_SA_KEY` | 手順1でダウンロードした JSON ファイルの中身を**そのまま全文貼り付け** |

**Variables タブ**（暗号化不要・ログに出てもよい値）

| 名前 | 値 |
|---|---|
| `GDRIVE_ROOT_FOLDER_ID` | `1EeVLQ5AnaD2TJ54QLFgNgGs4ONJ_hOvG` （`operations` フォルダ） |
| `GDRIVE_TEAM_DRIVE_ID` | 共有ドライブ配下なら `0AGJ0B4GFdAo8Uk9PVA`。マイドライブなら**登録しない** |

### 共有ドライブかマイドライブかの見分け方

Drive の左サイドバーで `sui-gen-company` が
「**共有ドライブ**」の下にあれば共有ドライブ、「**マイドライブ**」の下ならマイドライブ。
共有ドライブの場合のみ `GDRIVE_TEAM_DRIVE_ID` を設定する。

### フォルダ ID の調べ方

Drive でフォルダを開いたときの URL の末尾。

```
https://drive.google.com/drive/folders/1EeVLQ5AnaD2TJ54QLFgNgGs4ONJ_hOvG
                                       └────────── これが ID ──────────┘
```

## 4. 初回は必ず dry run で確認する

`Actions` タブ → `Drive sync` → `Run workflow` →
**`差分の確認のみ行い、コミットしない` にチェックを入れて実行**。

ログに「何件見つかったか」と「何が取り込まれるか」が出る。
想定どおりなら、チェックを外して本番実行する。

## 5. スケジュールを有効にするには

`on.schedule` はリポジトリの**デフォルトブランチ上のワークフローしか発火しない**。
このファイルが `main` にマージされるまで、定期実行は始まらない。
それまでは `Run workflow` の手動実行で動く。

なお cron の時刻は UTC 指定。`0 21 * * *` は JST 06:00（前日21時UTC）。

## 安全弁

設定ミスで Drive 側が空に見えたとき、`rclone sync` はミラーを全削除してしまう。
これを防ぐため、取得件数が `MIN_FILES`（既定 5 件）を下回ったら
**同期せずに失敗する**ようにしてある。

Drive 側を意図的に大きく減らした場合はこのチェックに引っかかる。
その場合はワークフローの `Sync from Drive` ステップに `MIN_FILES: 1` を足して実行する。

## 同期対象を変えるには

`scripts/drive-sync.filter` を編集する。上から順に**最初にマッチしたルールが勝つ**ので、
除外ルールは対応する include より前に書く。

```
- /workflows/OLD/**      ← 除外が先
+ /workflows/**          ← include が後
- **                     ← 最後に全落とし
```

## 動作を手元で確かめる

```bash
export SA_KEY_FILE=/path/to/sa.json
export GDRIVE_ROOT_FOLDER_ID=1EeVLQ5AnaD2TJ54QLFgNgGs4ONJ_hOvG
export DRY_RUN=true
./scripts/drive-sync.sh
```

## 既知の制約

- **鍵の有効期限**: サービスアカウントの JSON 鍵に期限はないが、Google Cloud 側で
  鍵を削除・失効させると同期が止まる。失敗は Actions のメール通知で気づく
- **ネイティブ Google 形式**: Docs/Sheets は `--drive-export-formats md,csv` で
  変換して取り込まれる。往復で書式は保たれないため、編集は Drive 側だけで行う
- **ファイル数**: 数千ファイル規模になると 1 回の実行が数分かかる。
  対象を絞るか `--transfers` を上げる
