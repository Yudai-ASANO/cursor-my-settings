---
name: refactor
description: 既存コードの構造改善（振る舞いは保持）。refactor チェーンを駆動する
disable-model-invocation: true
---

# /refactor — リファクタリング

既存コードの構造を改善する。機能は変更しない。

## 手順

1. リファクタリング対象を特定する
2. `workflow.mdc` の **refactor チェーン** を起動する:
   1. **architect サブエージェント** に現状分析とリファクタリング方針の策定を委譲する
   2. **planner サブエージェント** に Sprint Contract を生成させる
   3. **qa-reviewer サブエージェント** に Contract の検証基準をレビューさせる（Gate 0）
   4. **ユーザー確認** を得る（Gate 1）
   5. **generator サブエージェント** にリファクタリングを実装させる（テストがパスする状態を維持）
   6. **qa-reviewer サブエージェント** に実装の品質レビューを委譲する

## ルール

- 機能の追加・変更をしない（振る舞いを保持する）
- テストがパスする状態を常に維持する
- 大きな変更は小さなステップに分割する
- refactor チェーン（architect → planner → qa-reviewer → generator → qa-reviewer）を必ず完走させる

## 引数

`$ARGUMENTS` が指定された場合、その対象をリファクタリングする。
