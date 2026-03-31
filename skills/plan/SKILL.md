---
name: plan
description: 実装前に要件整理・ステップ分解・リスク評価を行い、Sprint Contractを生成する
disable-model-invocation: true
---

# /plan — 実装計画

コードに触れる前に、要件を整理し実装計画を策定する。

## 手順

1. ユーザーの要件を再確認する
2. **planner サブエージェント** に以下を委譲する:
   - 要件の詳細な仕様展開
   - 影響範囲・依存関係の洗い出し
   - Sprint Contract（実装スコープ + 検証基準）の生成
3. Sprint Contract を `~/.cursor/plans/<YYYYMMDD>-<slug>.md` として保存する
   - 保存主体: 呼び出し元エージェントが Write ツールで実行する（planner には委譲しない）
   - `~/.cursor/plans/` が存在しない場合は Shell ツールで `mkdir -p ~/.cursor/plans` を実行してから保存する
   - slug はタスク要件を2〜4単語で英語化したもの（例: `add-user-auth`）
   - 保存失敗時は処理を停止し、失敗理由をユーザーに報告する（次のステップに進まない）
4. Sprint Contract をユーザーに提示する（保存パスを明記）
5. **ユーザーの明示的な同意を得てから**次のステップに進む

## ルール

- コードを書かない — 計画のみ
- 技術的な実装詳細（ライブラリ選定等）は指定しない
- ユーザーが「proceed」「yes」等で承認するまで実装に進まない

## 引数

`$ARGUMENTS` が指定された場合、その要件に対して計画を策定する。
