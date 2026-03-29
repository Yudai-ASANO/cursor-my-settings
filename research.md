# Research: 実装エージェントへの GPT-5.4-high 採用とCursor推奨構成

## Date: 2026-03-30

## Scope

ハーネス設計のオーケストレーション構成において、実装者（implementer）エージェントに `gpt-5.4-high` を設定する妥当性と、Cursor の推奨するエージェント構成パターンの調査。

---

## 現状の構成

### 現在のエージェント割り当て

| エージェント | モデル | 役割 | 備考 |
|-------------|--------|------|------|
| architect | claude-opus-4-6 | システム設計評価 | Read-only |
| planner | claude-opus-4-6 | 仕様展開・タスク分解 | Read-only |
| qa-reviewer | **gpt-5.4-high** | コード品質評価 | Read-only, PASS/FAIL判定 |
| researcher | gemini-3.1-pro | 調査・ドキュメント分析 | Read-only, バックグラウンド可 |
| security-reviewer | **gpt-5.4-high** | セキュリティ脆弱性評価 | Read-only, PASS/FAIL判定 |
| **implementer** | **（未定義）** | 実装 | 現在はメインセッションが直接実行 |

### 重要な発見

現在の構成には **実装者エージェントが定義されていない**。実装はオーケストレーションフロー内でメインの Claude Code セッション（claude-opus-4-6）が直接担当している。

---

## GPT-5.4-high とは

「GPT-5.4-high」は独立したモデルではなく、**GPT-5.4 の reasoning effort を `high` に設定したもの**。

### Reasoning Effort レベル

| レベル | 挙動 | コスト | 適用場面 |
|--------|------|--------|---------|
| none | 非思考モード、最速 | 最安 | 単純タスク |
| low | 軽い推論 | 低 | 簡単なQ&A |
| medium | 中程度の推論 | 中 | 一般的なコーディング |
| **high** | **深い推論** | **高め** | **複雑な実装、設計** |
| xhigh | 最大深度 | 3-5倍 | 長時間のエージェント推論 |

### コーディングベンチマーク比較

| モデル | SWE-bench スコア | 備考 |
|--------|-----------------|------|
| GPT-5.4 Standard | 57.7% (Pro版) | reasoning effort による変動あり |
| Claude Opus 4.6 | 80.8% (Verified版) | ベンチマーク版が異なるため直接比較は困難 |

> **注意**: SWE-bench Pro と SWE-bench Verified は異なるベンチマークセット。数値の直接比較は不適切だが、一般的に Claude Opus 4.6 の方がコード生成タスクで高評価。

---

## Cursor の推奨エージェント構成

### 公式推奨パターン

1. **Plan Mode（Shift+Tab）を最初に使う** — コードを書く前に計画を立てる
2. **エージェントに検索させる** — 手動でファイルをタグ付けせず、grep/セマンティック検索を活用
3. **TDD アプローチ** — テストを先に書かせ、失敗を確認してから実装
4. **レビュー機能を活用** — 差分を行単位で確認
5. **具体的な指示** — 「コードを最適化して」ではなく「ハッシュテーブルで時間計算量を最適化して」

### Cursor のモデル選択ガイドライン

| 役割 | 推奨モデル | 理由 |
|------|-----------|------|
| Planning | Claude Opus 4.6, GPT-5.4 (high) | 深い推論が必要 |
| Implementation (Agent) | Claude Sonnet, GPT-5.4, GPT-5.4-mini | 速度と品質のバランス |
| Code Review / Ask | Claude Opus 4.6, GPT-5.4 | 深い分析が有益 |
| Debug | Claude Sonnet, GPT-5.4 | 素早いターンアラウンド |

> **Cursor の重要な制約**: モード別のデフォルトモデル設定は 2026年3月時点でまだ完全にはサポートされていない（コミュニティからの機能リクエストあり）。

### Cursor のマルチエージェントパターン

1. **並列エージェント + Git Worktrees** — 最大8エージェント並列、各自が独立したworktreeで作業
2. **階層型ロールベース** — `.cursor/agents/` にYAML frontmatter付きMarkdownで役割定義
3. **構造化ハンドオフ** — Goal, Changes, Open Questions, Next Owner の形式で引き継ぎ
4. **Skills レイヤー** — `.cursor/skills/` にカスタムコマンドを定義

### Cursor Background Agents

- クラウドの隔離環境でリポジトリをクローンして自律的に作業
- 最大8エージェント並列実行
- 別ブランチで作業し、完了時にPR作成
- 使用モデルは公式ドキュメントに明記されていない（Auto選択の可能性）

---

## 実装エージェントに GPT-5.4-high を採用する場合の分析

### メリット

1. **モデル多様性の拡張** — 既にレビュー系で使用しているため、統一的な GPT-5.4 エコシステム活用
2. **深い推論能力** — `high` reasoning effort により複雑なロジック実装に強い
3. **独立した視点** — Claude が設計・統合、GPT が実装という役割分離で「自分のコードを自分でレビュー」問題を回避
4. **Cursor との親和性** — Cursor が GPT-5.4 を「最もスマートなモデル」と評価

### デメリット・リスク

1. **コーディングベンチマークでの優位性が不明確** — Claude Opus 4.6 の方がコード生成タスクで高スコアの報告が多い
2. **コスト増** — `high` reasoning effort はトークンコストが高い。実装は大量のトークンを消費するため影響大
3. **速度低下** — 深い推論モードは応答が遅い。実装タスクではイテレーション速度が重要
4. **コンテキスト管理の複雑化** — 実装エージェントはコードベース全体の理解が必要。ステートレスなサブエージェントへの十分なコンテキスト提供が課題
5. **既存フローとの整合性** — 現在のオーケストレーションは「メインセッションが実装を直接実行」前提で設計されている

### 代替案の比較

| 案 | 構成 | 長所 | 短所 |
|----|------|------|------|
| **A: 現状維持** | メインセッション(Opus 4.6)が実装 | コンテキスト保持◎、実績あり | 自己レビュー問題 |
| **B: GPT-5.4-high 実装者** | 専用エージェント追加 | 独立視点、深い推論 | コスト高、速度低、コンテキスト断絶リスク |
| **C: GPT-5.4（medium）実装者** | reasoning effort を下げて速度重視 | コスト・速度バランス | 複雑なロジックでの品質懸念 |
| **D: Claude Sonnet 実装者** | 高速・低コストの Claude | イテレーション速度◎ | Opus より推論力が劣る |
| **E: タスク種別で動的切替** | 複雑→GPT-5.4-high、単純→Sonnet | 最適化される | フロー複雑化、切替ロジックの保守コスト |

---

## Cursor vs Claude Code のエージェントパターン比較

| 観点 | Cursor | Claude Code（現在の構成） |
|------|--------|------------------------|
| 哲学 | IDE-first: ユーザーが主導 | Agent-first: ユーザーが記述、AIが実行 |
| マルチモデル | 会話単位でモデル切替、並列比較 | CLAUDE.md ルール + bash サブエージェント |
| オーケストレーション | .cursor/agents/ + skills/ + Plan Mode | orchestrate skill + agents/ + ゲートシステム |
| 並列処理 | Background Agents（クラウド、最大8） | Worktree + 並列タスク |
| 実装の分離 | 各エージェントが独立worktreeで作業 | メインセッションが直接実装 |
| コスト | Claude Code の約1/10（同等品質で） | トークン消費量が多いが深い推論 |

---

## Risks & Considerations

### 高リスク
- **コンテキスト断絶**: 実装をサブエージェントに委譲すると、計画フェーズで蓄積されたコンテキストの伝達が不完全になるリスク
- **デバッグ困難化**: 実装者が別モデルの場合、エラー発生時の原因特定が複雑化

### 中リスク
- **コスト予測困難**: GPT-5.4-high の実装タスクでのトークン消費量は事前予測が難しい
- **Cursor 固有機能への依存**: Background Agents 等はCursor特有、Claude Code環境では再現不可

### 低リスク
- **ベンチマーク差の実務影響**: 実際のプロジェクトでは「プロンプト戦略に依存する」との報告が多く、モデル選択よりプロンプト品質の方が影響大

---

## 総合的な結論

### Cursor 環境での推奨

Cursor で実装エージェントに GPT-5.4 を使うのは **合理的な選択**。ただし:

- **`high` より `medium` を推奨** — 実装タスクは速度とイテレーションが重要。deep reasoning が必要な場面は限定的
- **Plan Mode で Claude Opus 4.6 → Agent Mode で GPT-5.4** というフローが Cursor のガイドラインに最も合致
- 並列エージェントで Claude と GPT の結果を比較するA/Bテストから始めるのが低リスク

### Claude Code 環境での推奨

現在のオーケストレーション設計（メインセッションが実装を直接担当）の方が **コンテキスト管理の面で優れている**。GPT-5.4-high を実装者として追加する場合:

- プロンプトの自己完結性とコンテキスト伝達の仕組みを十分に設計する必要がある
- 既にレビュー系で GPT-5.4-high を使用しているため、「実装と評価が同じモデル」になるバイアスリスク

### 推奨アプローチ（段階的導入）

1. **Phase 1**: `GPT-5.4` (medium reasoning) で小規模な実装タスクを試行し、品質・速度・コストを計測
2. **Phase 2**: 計測結果に基づき reasoning effort レベルを調整
3. **Phase 3**: タスク複雑度に応じた動的切り替えルールを策定

---

## 参考ソース

- [Choosing the Right AI Model in Cursor - Steve Kinney](https://stevekinney.com/courses/ai-development/cursor-model-selection)
- [Best practices for coding with agents - Cursor Blog](https://cursor.com/blog/agent-best-practices)
- [Multi-Agent Orchestration in Cursor - Cursor Forum](https://forum.cursor.com/t/multi-agent-orchestration-in-cursor-coordinating-specialized-agents/150022)
- [Default Model Selection Per Mode - Cursor Forum](https://forum.cursor.com/t/default-model-selection-per-mode-agent-ask-plan-debug/150676)
- [Parallel Agents - Cursor Docs](https://cursor.com/docs/configuration/worktrees)
- [Cursor Background Agents - Official Docs](https://docs.cursor.com/en/background-agent)
- [Introducing GPT-5.4 - OpenAI](https://openai.com/index/introducing-gpt-5-4/)
- [GPT-5.4 API Developer Guide - NxCode](https://www.nxcode.io/resources/news/gpt-5-4-api-developer-guide-reasoning-computer-use-2026)
- [Claude Code vs Cursor - DoltHub](https://www.dolthub.com/blog/2025-08-15-cursor-agent-vs-claude-code/)
- [Claude Code vs Cursor: What to Choose in 2026 - Builder.io](https://www.builder.io/blog/cursor-vs-claude-code)

---

## 次のステップ

1. この `research.md` をレビューし、方針を確定
2. `/plan` で具体的な実装計画を作成
3. 小規模タスクでA/Bテストを実施し、定量データを収集
