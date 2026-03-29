---
name: orchestrate
description: タスク種別に応じたエージェントチェーンの自動駆動（feature/bugfix/refactor/security）
disable-model-invocation: true
---

# /orchestrate — ワークフロー駆動

タスク種別を判定し、`rules/workflow.mdc` に定義されたエージェントチェーンを実行する。

## 手順

1. `orchestration.mdc` を Read ツールで読み込む（ゲート詳細・並列実行・ハンドオフ形式）
2. 引数または文脈からタスク種別を判定する（feature / bugfix / refactor / security）
3. `rules/workflow.mdc` のエージェントチェーン定義に従い、各ステップを順次実行する
4. 各ゲート（Contract 交渉 → ユーザー確認 → lint/test → PASS/FAIL）を通過させる
5. Sprint Contract の規模に応じて、`orchestration.mdc` の並列実行モードに従い generator を起動する

## タスク種別の判定

| 種別 | 判定条件 |
|------|---------|
| `feature` | 新機能追加、機能実装の要求 |
| `bugfix` | バグ修正、不具合対応の要求 |
| `refactor` | リファクタリング、構造改善の要求 |
| `security` | セキュリティ修正、脆弱性対応の要求 |

## ルール

- チェーン定義は `rules/workflow.mdc`、実行詳細は `rules/orchestration.mdc` を正とする
- ゲートを省略しない
- レビュアーごとに最大3回リトライ。3回 FAIL → 停止しユーザーにブロッカーを報告

## 引数

`/orchestrate feature ユーザー認証の追加` のように `種別 説明` の形式で指定する。種別を省略した場合は文脈から自動判定する。
