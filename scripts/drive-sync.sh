#!/usr/bin/env bash
#
# Google Drive → リポジトリ の片方向ミラー。
# Drive 側が常に正。リポジトリ側の該当ディレクトリは上書き・削除される。
# 設定手順は docs/drive-sync-setup.md を参照。
#
set -euo pipefail

SA_KEY_FILE="${SA_KEY_FILE:?SA_KEY_FILE is required}"
ROOT_FOLDER_ID="${GDRIVE_ROOT_FOLDER_ID:?GDRIVE_ROOT_FOLDER_ID is required}"
TEAM_DRIVE_ID="${GDRIVE_TEAM_DRIVE_ID:-}"
DEST_DIR="${DEST_DIR:-drive}"
DRY_RUN="${DRY_RUN:-false}"
# 取得件数がこれを下回ったら同期せず中断する。設定ミスや権限剥奪で
# Drive 側が空に見えたとき、sync がミラーを消し去るのを防ぐ安全弁。
MIN_FILES="${MIN_FILES:-5}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILTER_FILE="$REPO_ROOT/scripts/drive-sync.filter"
CONF_FILE="$(mktemp)"
trap 'rm -f "$CONF_FILE"' EXIT

[ -f "$FILTER_FILE" ] || { echo "::error::filter not found: $FILTER_FILE" >&2; exit 1; }
[ -s "$SA_KEY_FILE" ] || { echo "::error::service account key is empty or missing" >&2; exit 1; }

# rclone 設定を一時ファイルに生成する。秘密情報は鍵ファイルのパス参照のみで、
# 設定内容そのものはログに出さない。
{
  echo "[gdrive]"
  echo "type = drive"
  echo "scope = drive.readonly"
  echo "service_account_file = $SA_KEY_FILE"
  echo "root_folder_id = $ROOT_FOLDER_ID"
  # 共有ドライブ配下の場合のみ必要。マイドライブなら空のままでよい。
  [ -n "$TEAM_DRIVE_ID" ] && echo "team_drive = $TEAM_DRIVE_ID"
} > "$CONF_FILE"

RCLONE_ARGS=(
  --config "$CONF_FILE"
  --filter-from "$FILTER_FILE"
  # Drive は md5 を返すので、更新時刻ではなくチェックサムで差分判定する。
  --checksum
  # ネイティブ Google 形式のファイルが混ざっても壊れないようにする。
  --drive-export-formats md,csv
  --transfers 4
  --retries 3
  --low-level-retries 10
)

echo "==> Drive 側の対象ファイルを数える"
# 数えるだけ。ここで落ちれば書き込みは一切起きていない。
FILE_COUNT="$(rclone lsf "${RCLONE_ARGS[@]}" --recursive --files-only gdrive: | wc -l | tr -d ' ')"
echo "    ${FILE_COUNT} 件"

if [ "$FILE_COUNT" -lt "$MIN_FILES" ]; then
  echo "::error::対象ファイルが ${FILE_COUNT} 件しかない (下限 ${MIN_FILES} 件)。" >&2
  echo "::error::フォルダ ID か共有設定が誤っている可能性が高いため中断する。" >&2
  echo "::error::Drive 側を本当に減らしたのなら MIN_FILES を下げて再実行すること。" >&2
  exit 1
fi

mkdir -p "$REPO_ROOT/$DEST_DIR"

if [ "$DRY_RUN" = "true" ]; then
  echo "==> DRY RUN: 差分のみ表示する（ファイルは変更しない）"
  rclone sync "${RCLONE_ARGS[@]}" --dry-run --verbose gdrive: "$REPO_ROOT/$DEST_DIR"
  exit 0
fi

echo "==> ${DEST_DIR}/ へ同期する"
rclone sync "${RCLONE_ARGS[@]}" --verbose gdrive: "$REPO_ROOT/$DEST_DIR"
echo "==> 完了"
