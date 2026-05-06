# Cursor Personal Settings

Cursor の個人設定を最小の常時コンテキストで管理するためのリポジトリです。

日常的に有効化する設定は `rules/personal-defaults.mdc` だけです。特定の技術、固定手順、実装プロセス、ローカル実行フックは既定では含めません。

## Structure

```text
.
├── agents/          # 将来用。既定では無効
├── hooks/           # 将来用。既定では無効
├── rules/           # 常時適用する最小ルール
├── scripts/         # ~/.cursor への反映スクリプト
└── skills/          # 将来用。既定では無効
```

## Active Rule

`rules/personal-defaults.mdc` は以下だけを扱います。

- 必要なファイルだけを読む
- ローカルの事実を確認してから答える
- 依頼範囲を広げない
- 秘密情報や破壊的操作に注意する
- 変更内容と確認結果を簡潔に報告する

## Deploy

既定では `rules/*.mdc` だけを `~/.cursor/rules/` にコピーします。

```bash
bash scripts/deploy.sh --dry-run
bash scripts/deploy.sh
bash scripts/deploy.sh --status
bash scripts/deploy.sh --uninstall
```

将来、任意カテゴリを追加した場合だけ明示的に指定します。

```bash
bash scripts/deploy.sh --with-agents
bash scripts/deploy.sh --with-skills
bash scripts/deploy.sh --with-hooks
```

## Policy

- 常時適用ルールは少なく保つ。
- 技術固有の知識はプロジェクト側から読む。
- 固定手順は個人設定に入れない。
- hooks、skills、agents は必要性が明確な場合だけ追加する。
