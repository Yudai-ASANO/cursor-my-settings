---
name: orchestrate
description: タスク種別に応じたエージェントチェーンの自動駆動（feature/bugfix/refactor/security）
disable-model-invocation: true
---

# /orchestrate — ワークフロー駆動

タスク種別を判定し、適切なエージェントチェーンを自動実行する。

## タスク種別の判定

引数または文脈から種別を判定する:

| 種別 | 判定条件 |
|------|---------|
| `feature` | 新機能追加、機能実装の要求 |
| `bugfix` | バグ修正、不具合対応の要求 |
| `refactor` | リファクタリング、構造改善の要求 |
| `security` | セキュリティ修正、脆弱性対応の要求 |

## エージェントチェーン

### feature
```
/planner → [ユーザー確認] → 実装 → [lint/format/typecheck/test] → /qa-reviewer → /security-reviewer → 完了
```

### bugfix
```
/researcher → /planner → [ユーザー確認] → 実装 → [lint/format/typecheck/test] → /qa-reviewer → 完了
```

### refactor
```
/architect → /planner → [ユーザー確認] → 実装 → [lint/format/typecheck/test] → /qa-reviewer → 完了
```

### security
```
/security-reviewer(分析) → /planner → [ユーザー確認] → 実装 → [lint/format/typecheck/test] → /security-reviewer(検証) → /qa-reviewer → 完了
```

## 共通ゲート

1. **ユーザー確認ゲート**: Sprint Contract 提示後、ユーザーの同意を得てから実装に進む
2. **lint/test ゲート**: 実装後に lint, format, typecheck, test を必ず実行する
3. **FAIL リトライ**: レビュアーが FAIL を返した場合、修正→再レビュー（最大3回）
4. **停止条件**: 同一ステップで3回 FAIL → 停止してユーザーにブロッカーを報告

## 引数

`/orchestrate feature ユーザー認証の追加` のように `種別 説明` の形式で指定する。種別を省略した場合は文脈から自動判定する。
