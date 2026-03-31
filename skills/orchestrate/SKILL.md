---
name: orchestrate
description: タスク種別に応じたエージェントチェーンの自動駆動（feature/bugfix/refactor/security/debug/tdd）
disable-model-invocation: false
---

# /orchestrate — ワークフロー駆動

引数または文脈からタスク種別を判定し、`workflow.mdc` のエージェントチェーンを実行する。

## 手順

1. `orchestration.mdc` を Read ツールで読み込む（ゲート詳細・並列実行モード・ハンドオフ形式）
2. 引数または文脈から `workflow.mdc` のタスク種別（feature / bugfix / refactor / security / debug / tdd）を判定する
3. `workflow.mdc` のチェーン定義・実行規律に従い、各ゲートを省略せず順次実行する

## 引数

`/orchestrate feature ユーザー認証の追加` のように `種別 説明` の形式で指定する。種別を省略した場合は文脈から自動判定する。
