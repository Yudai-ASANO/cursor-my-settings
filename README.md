# Cursor Personal Settings

Cursor の個人設定を最小の常時コンテキストで管理するためのリポジトリです。

常時適用の軸は `rules/defaults.mdc` です。実装方針・セキュリティ・Git は兄弟ルール（`coding-policy.mdc` / `security.mdc` / `git-workflow.mdc`）に分離しています。エージェント定義・スキル・フックはリポジトリに置いてありますが、デプロイ既定ではルールのみです。

## Structure

```text
.
├── agents/          # エージェント定義（*.md）。deploy では --with-agents が必要
├── hooks/           # 任意フック用。hooks.json / *.sh があれば --with-hooks で反映
├── rules/           # 常時・条件付きルール（*.mdc）
├── scripts/         # ~/.cursor への反映スクリプト
└── skills/          # SKILL.md を含むサブディレクトリ。--with-skills が必要
```

### agents/

例: `design-reviewer.md`, `explainer.md`, `rca.md`, `researcher.md`（用途ごとのプロンプト集）。

### rules/

| ファイル | 役割 |
| -------- | ---- |
| `defaults.mdc` | `alwaysApply: true`。言語方針・コンテキスト・スコープ・安全・報告、および兄弟ルールの索引 |
| `coding-policy.mdc` | 実装・設計・変更範囲・品質 |
| `security.mdc` | 認証・API・環境ファイルなど（グロブ一致時に自動適用） |
| `git-workflow.mdc` | コミット・PR |

### skills/

例: `explain/`, `grill-me/`, `research/`（各 `SKILL.md`）。

## Deploy

既定では `rules/*.mdc` だけを `~/.cursor/rules/` にコピーします。

```bash
bash scripts/deploy.sh --dry-run
bash scripts/deploy.sh
bash scripts/deploy.sh --status
bash scripts/deploy.sh --uninstall
```

エージェント・スキル・フックを反映するときだけフラグを付けます。

```bash
bash scripts/deploy.sh --with-agents
bash scripts/deploy.sh --with-skills
bash scripts/deploy.sh --with-hooks
```

## Policy

- 常時適用ルールは `defaults.mdc` を薄く保ち、詳細は兄弟 `.mdc` に寄せる。
- 技術固有の知識はプロジェクト側から読む。
- 固定手順は個人設定に詰め込みすぎない。
- エージェント・スキル・フックは必要性が明確なときだけ `deploy.sh` で有効化する。
