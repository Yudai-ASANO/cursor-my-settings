---
name: tdd
description: テスト駆動開発（RED→GREEN→REFACTOR）をフルチェーンで実行する
disable-model-invocation: true
---

# /tdd — テスト駆動開発

RED → GREEN → REFACTOR のサイクルをエージェントチェーンで実行する。

## 手順

1. 実装したい機能を特定する
2. `workflow.mdc` の **tdd チェーン** を起動する:
   1. **planner サブエージェント** に TDD 前提の Sprint Contract を生成させる（検証基準に RED→GREEN→REFACTOR の各ステップを含む）
   2. **qa-reviewer サブエージェント** に Contract の検証基準をレビューさせる（Gate 0）
   3. **ユーザー確認** を得る（Gate 1）
   4. **generator サブエージェント** に TDD モードで実装を委譲する:
      - Step 1 RED: 失敗するテストを先に書き、テスト実行で**失敗を確認**する
      - Step 2 GREEN: テストが通る**最小限**のコードを書き、テスト実行で**全パスを確認**する
      - Step 3 REFACTOR: テストがパスした状態を維持しつつコードを改善し、テスト再実行で**全パスを確認**する
   5. **qa-reviewer サブエージェント** に実装の品質レビューを委譲する

## ルール

- テストを書く前にプロダクションコードを書いてはいけない
- 各ステップでテストの実行結果を明示的に報告する
- カバレッジ 80% 以上を目標とする
- テストが失敗した場合、テストではなく実装を修正する（テスト自体が間違っている場合を除く）
- tdd チェーン（planner → qa-reviewer → generator(TDD) → qa-reviewer）を必ず完走させる

## 引数

`$ARGUMENTS` が指定された場合、その機能/修正に対してTDDサイクルを適用する。
