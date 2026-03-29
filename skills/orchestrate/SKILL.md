---
name: orchestrate
description: タスク種別に応じたエージェントチェーンの自動駆動（feature/bugfix/refactor/security）
disable-model-invocation: true
---

# /orchestrate — ワークフロー駆動

タスク種別を判定し、`rules/workflow.mdc` に定義されたエージェントチェーンを実行する。

## 手順

1. 引数または文脈からタスク種別を判定する（feature / bugfix / refactor / security）
2. `rules/workflow.mdc` のエージェントチェーン定義に従い、各ステップを順次実行する
3. 各ゲート（Contract 交渉 → ユーザー確認 → lint/test → PASS/FAIL）を通過させる
4. Sprint Contract の規模に応じて、generator の並列実行モード（best-of-N / タスク分割）を選択する

## タスク種別の判定

| 種別 | 判定条件 |
|------|---------|
| `feature` | 新機能追加、機能実装の要求 |
| `bugfix` | バグ修正、不具合対応の要求 |
| `refactor` | リファクタリング、構造改善の要求 |
| `security` | セキュリティ修正、脆弱性対応の要求 |

## 並列実行の判断と起動手順

Sprint Contract の「実行モード推奨」を参考に、以下の判断基準でモードを決定する。

### 逐次実行（デフォルト）
通常のタスク。単一の `/generator` を起動する。
**`security` ワークフローは常に逐次実行とする（並列禁止）。**

### best-of-N（品質重視）

**判断基準**: 設計判断が分かれるタスク、最適解が不明確な場合

**起動手順**:
1. Sprint Contract の N 値を確認する（未指定なら N=2）
2. Cursor の Task ツールで `subagent_type="best-of-n-runner"` を使用し、N 個の generator を並列起動する
3. 各 generator は独立した git worktree で作業する
4. 全 generator のハンドオフ artifact が揃ったら、`/qa-reviewer` に Comparative Review を依頼する
5. 全候補 FAIL の場合は逐次実行（単一 generator）にフォールバックする
6. 採択されたブランチをメイン作業ブランチにマージし、不採択 worktree を削除する
7. マージ後のツリーで Gate 2 以降を継続する

### タスク分割（速度重視）

**判断基準**: 互いに独立した複数機能、大規模 Sprint Contract

**起動手順**:
1. Sprint Contract の「分割単位」に従いスコープをグループ化する
2. 各グループに対して Cursor の Task ツールで `subagent_type="best-of-n-runner"` を使用し、generator を並列起動する（best-of-n-runner は独立 worktree を提供する汎用並列 runner であり、タスク分割にも使用する）
3. 各 generator は独立した git worktree で担当グループのみ実装する
4. 全 generator 完了後、オーケストレーター（メインセッション）が統合ステップを実行する:
   - メインブランチに各 worktree の変更を順次マージする
   - 自動マージ可能ならそのまま進行
   - 衝突発生時は停止しユーザーに報告する
5. 統合完了後に Gate 2（lint/format/typecheck/test）を実行する
6. 統合後テスト FAIL 時: 単一グループ特定可 → そのグループに差し戻し。特定不可 → 全並列中止し単一 generator で統合修正。最大3回リトライ（詳細は `rules/workflow.mdc` を参照）

## ルール

- チェーン定義の詳細は `rules/workflow.mdc` を正とする（本 Skill には重複定義しない）
- ゲートを省略しない
- レビュアーごとに最大3回リトライ（qa-reviewer と security-reviewer は別カウント）。同一レビュアーで3回 FAIL → 停止しユーザーにブロッカーを報告する（詳細は `rules/workflow.mdc` の Gate 3 を参照）

## 引数

`/orchestrate feature ユーザー認証の追加` のように `種別 説明` の形式で指定する。種別を省略した場合は文脈から自動判定する。
