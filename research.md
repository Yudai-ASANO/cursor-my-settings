# Research: Cursor 個人用ハーネス設計 — グローバル設定のベストプラクティス

## Date: 2026-03-29

## Scope

Cursorの公式ドキュメントとコミュニティのベストプラクティスを調査し、プロジェクト非依存のグローバル設定（ルール・サブエージェント・スキル・Hooks）の設計方針を策定する。ハーネスエンジニアリングの概念・設計パターンも統合する。

---

## Key Files（Cursor グローバル設定のファイルパス）

| 用途 | パス | 状態 |
|------|------|------|
| グローバルルール | `~/.cursor/rules/*.mdc` | **未作成** |
| グローバルサブエージェント | `~/.cursor/agents/*.md` | **未作成** |
| グローバルスキル | `~/.cursor/skills/*/SKILL.md` | 未作成（skills-cursor/に組み込みのみ） |
| グローバルHooks | `~/.cursor/hooks.json` | **未作成** |
| グローバルMCP | `~/.cursor/mcp.json` | **未作成** |
| パーミッション | `~/.cursor/permissions.json` | **未作成** |
| CLI設定 | `~/.cursor/cli-config.json` | 既存（GPT-5.4設定済み） |
| User Rules（UI設定） | Cursor Settings > Rules テキスト欄 | 未確認 |

---

## Architecture & Patterns

### 1. Cursorの設定階層（優先度順）

```
Enterprise (MDM管理)  ← 最高優先度
  ↓
Team (ダッシュボード管理)
  ↓
Project (.cursor/rules/, .cursor/agents/, AGENTS.md)
  ↓
User (~/.cursor/rules/, ~/.cursor/agents/, User Rules)  ← 最低優先度
```

**重要**: 上位が下位を上書きするため、グローバル設定はデフォルトの「最低限の基盤」として設計し、プロジェクト側で上書き可能にする。

### 2. MDCフォーマット（.mdc）

Cursor独自のルールフォーマット。YAMLフロントマター + Markdownコンテンツ:

```yaml
---
description: "ルールの目的（Apply Intelligently時のAI判断に使用）"
alwaysApply: false
globs: ["**/*.ts", "src/**"]
---

# ルール内容（Markdown）
```

**4つの適用モード**:

| モード | 条件 | フロントマター |
|--------|------|---------------|
| Always Apply | 毎回必ず適用 | `alwaysApply: true` |
| Apply Intelligently | AIが`description`を見て判断 | `alwaysApply: false`, `description`あり, `globs`なし |
| Apply to Specific Files | globマッチするファイル参照時に適用 | `globs`指定 |
| Apply Manually | `@rule-name`で明示呼び出し | フロントマターなし/全フィールド空 |

### 3. サブエージェント定義

ファイル: `~/.cursor/agents/*.md`（YAMLフロントマター + プロンプト）

```markdown
---
name: identifier-name
description: Short description for Agent delegation hints
model: inherit|fast|specific-model-id
readonly: true|false
is_background: true|false
---

プロンプト指示
```

- 組み込みサブエージェント: **Explore**, **Bash**, **Browser**（設定不要）
- カスタムサブエージェントは `/name` で呼び出し or AIが`description`を見て自動委譲
- ネスト不可（1階層のみ）
- `readonly: true`でファイル編集を禁止
- `is_background: true`で非同期バックグラウンド実行

### 4. スキル定義

ファイル: `~/.cursor/skills/skill-name/SKILL.md`

```markdown
---
name: skill-name
description: スキルの説明
disable-model-invocation: false
---

スキルの内容
```

- `disable-model-invocation: true`で明示的な`/skill-name`呼び出しのみ
- オプションで `scripts/`, `references/`, `assets/` サブディレクトリ

### 5. Hooks

ファイル: `~/.cursor/hooks.json`

```json
{
  "version": 1,
  "hooks": {
    "hookName": [
      {
        "command": "./path/to/script",
        "type": "command|prompt",
        "timeout": 30,
        "loop_limit": 5,
        "failClosed": false,
        "matcher": "pattern"
      }
    ]
  }
}
```

**主要フックイベント**:
- `sessionStart` / `sessionEnd`: セッション開始/終了
- `preToolUse` / `postToolUse`: ツール使用前後
- `beforeShellExecution` / `afterShellExecution`: シェルコマンド前後
- `beforeReadFile` / `afterFileEdit`: ファイル操作前後
- `subagentStart` / `subagentStop`: サブエージェント前後
- `stop`: エージェント完了時

**環境変数**: `CURSOR_PROJECT_DIR`, `CURSOR_VERSION`, `CURSOR_USER_EMAIL`, `CURSOR_TRANSCRIPT_PATH`

### 6. パーミッション

ファイル: `~/.cursor/permissions.json`（JSONC対応）

```json
{
  "mcpAllowlist": ["server:tool", "server:*"],
  "terminalAllowlist": ["git", "npm:install*"]
}
```

---

## Claude Code との対応関係

| 概念 | Claude Code | Cursor |
|------|------------|--------|
| グローバルルール | `~/.claude/CLAUDE.md` + `~/.claude/rules/*.md` | `~/.cursor/rules/*.mdc` + User Rules (UI) |
| プロジェクトルール | `CLAUDE.md`（プロジェクトルート） | `.cursor/rules/*.mdc` |
| サブディレクトリルール | サブディレクトリの`CLAUDE.md` | サブディレクトリの`AGENTS.md` |
| Hooks | `~/.claude/settings.json` hooks | `~/.cursor/hooks.json` |
| サブエージェント | `~/.claude/agents/*.md` | `~/.cursor/agents/*.md` |
| スキル | `~/.claude/skills/` | `~/.cursor/skills/` |
| MCP | `~/.claude/mcp.json` | `~/.cursor/mcp.json` |
| パーミッション | settings.json permissions | `~/.cursor/permissions.json` |
| 条件付き適用 | なし（常に全ロード） | `globs`, `description`によるインテリジェント適用 |

**Cursorの利点**: `globs`とApply Intelligentlyによる条件付きルール適用で、コンテキストウィンドウの無駄を削減できる。

---

## Harness Engineering — 概念と設計パターン

### ハーネスエンジニアリングとは

**出典**: ai.acsim.app, claude-code-academy.dev, github.com/affaan-m/everything-claude-code

「ハーネス（馬具）」の比喩 — 強力な力を意図した方向に導く仕組み。AIエージェントの出力を意図した目標に導く環境設計を指す。

**2つの定義**:
- **Mitchell Hashimoto (HashiCorp)**: 「エージェントのミスを検出・防止するフィードバックループ」。失敗時に根本原因を分析し、再発防止のため環境を改善する。
- **OpenAI**: 「エージェントが最初から正しく動作できる総合的な環境設計」。矯正より予防。

**核心**: エンジニアの仕事は「コードを書くこと」から「正しいコードを生み出すエコシステムを構築すること」に移行する。

### 単一エージェントの構造的問題（claude-code-academy.dev）

1. **コンテキスト不安**: コンテキストウィンドウが埋まるにつれ、モデルが完了を急ぐ。指定機能の省略、雑なエラー処理、テスト省略、CSSインライン化等が発生。
2. **自己評価バイアス**: 自分のコードをレビューすると、明らかなバグがあっても「問題なし」と判定する。ビルダーと評価者が同一エージェントである限り、品質の天井を突破することは構造的に不可能。

### マルチエージェント・ハーネスパターン（GAN着想）

**生成と評価の分離** — GANs（敵対的生成ネットワーク）に着想を得た設計:

| エージェント | 役割 | 詳細 |
|------------|------|------|
| **Planner** | 仕様展開 | 1-4行のプロンプトから詳細なプロダクト仕様を生成。技術的実装の詳細は意図的に指定しない（誤った判断の伝播を防止） |
| **Generator** | スプリント実装 | 1機能ずつスプリントで実装。自己評価後にEvaluatorに引き渡し |
| **Evaluator** | 実テスト検証 | Playwright MCP経由でUI操作、API呼び出し、DB状態確認。基準未満で即FAIL |

**分離が機能する3つの理由**:
1. 評価者を懐疑的にチューニングしやすい（「些細な問題でもFAIL判定せよ」）
2. 評価結果が具体的な改善指示になる（「ここが壊れている、こう直せ」）
3. 反復ループが自動実行される（生成→評価→修正→再評価）

**Sprint Contract**: 各スプリント開始前にGeneratorとEvaluatorが「何を作るか」「どう検証するか」を合意。具体的テスト基準（例: レベルエディタで27項目）を事前定義。

### qa-reviewer エージェントパターン（claude-code-academy.dev）

```markdown
---
name: qa-reviewer
description: 実装コードの品質を厳格にレビューする
---

あなたは厳格なQAレビュアーです。以下の基準で実装を評価してください:

## 評価基準
1. 仕様通りに動作するか？（スタブやモックで誤魔化していないか）
2. エッジケースは処理されているか？
3. UIは直感的に操作可能か？
4. エラー時にユーザーフィードバックがあるか？

些細な問題でも「FAIL」判定し、具体的な修正を指摘すること。
「概ね問題なし」「小さい問題だが大丈夫」という判定は禁止。
```

### Stripeの「Blueprints」パターン（ai.acsim.app）

エージェントのステップと決定的ゲートを交互に配置:

```
Agent Step → Lint Gate → Agent Step → Git Commit Gate → Agent Step → CI Gate → Retry or Human
```

**原則**: 「モデルがシステムを動かすのではない。システムがモデルを動かす。」
忘れたステップが実行されないのではなく、省略が不可能になる設計。

### everything-claude-code のハーネス設計（115k+ stars）

**出典**: github.com/affaan-m/everything-claude-code

**Agent Harness Construction スキル**の4つの品質要因:

| 要因 | 内容 |
|------|------|
| **Action Space Quality** | 安定・明示的なツール名、スキーマファーストの狭い入力、決定的な出力形状 |
| **Observation Quality** | 全ツールレスポンスに`status`, `summary`, `next_actions`, `artifacts`を含める |
| **Recovery Quality** | 全エラーパスに根本原因ヒント、安全なリトライ指示、明示的な停止条件 |
| **Context Budget Quality** | 最小システムプロンプト、オンデマンドスキルロード、インラインよりファイル参照 |

**粒度ルール**:
- Micro-tools: 高リスク操作（デプロイ、マイグレーション、権限）
- Medium tools: 一般的なedit/read/searchループ
- Macro-tools: ラウンドトリップオーバーヘッドが支配的な場合のみ

**リポジトリ規模**: 30エージェント、135+スキル、60+コマンド、12言語対応ルール

**オーケストレーションワークフロー**:

| ワークフロー | エージェントチェーン |
|------------|-------------------|
| feature | planner → tdd-guide → code-reviewer → security-reviewer |
| bugfix | planner → tdd-guide → code-reviewer |
| refactor | architect → code-reviewer → tdd-guide |
| security | security-reviewer → code-reviewer → architect |

### 企業での実践パターン（ai.acsim.app）

| 組織 | アプローチ |
|------|----------|
| **Anthropic** | Claude Code lead が2ヶ月以上手動コーディングなし。ローカル5 + Web 5-10セッション並列。Plan mode → Auto-accept mode。`CLAUDE.md` ~2,500トークン |
| **OpenAI** | 3名で「手書きコード禁止」制約下にCodexのみで内部プロダクト構築。`AGENTS.md` ~100行をエントリポイントに、詳細は`docs/`階層 |
| **Stripe** | Slack経由で5タスクを「Minions」に投入、完了した5 PRを確認・承認・破棄。Blueprintsで決定的ゲートを強制 |

### ハーネス設計のベストプラクティス

1. **強制 > 依頼**: `AGENTS.md`に「〜してください」ではなく、リンター/CI/決定的ゲートで強制する
2. **リンターエラーに修正手順を埋め込む**: エージェントが自己修正できるように「何が問題で」「どう直すか」をエラーメッセージに含める
3. **80%完了でハンドオフ**: 100%を期待せず、大規模並列化を可能にする
4. **10-20%のセッション失敗を許容**: 並列実行で緩和
5. **環境の失敗をコード修正ではなく環境改善に転化**: 即座の修正ではなく、環境の改善として蓄積
6. **ハーネスは静的ではない**: モデルの進化に合わせて定期的に見直し、不要なルールを削除
7. **1つの巨大ファイルを書かない**: 「すべてが重要 = 何も重要ではない」
8. **CLAUDE.mdに評価基準を直接記述**: 評価基準自体がGeneratorの方向付けになる

### ハーネス設計のアンチパターン

- 巨大な単一コンテキストファイル
- エージェントに100%成功を期待し、1セッションに張り付く
- 「〜してください」形式のドキュメント（強制力がない）
- ジュニアエンジニアへの曖昧な指示（Findyの実験: ジュニアは20-30%生産性低下、シニアは30-50%向上）
- ハーネスを静的に放置（モデル進化に伴い陳腐化）

### コスト・品質トレードオフ実績（claude-code-academy.dev）

| アプローチ | 時間 | コスト | 結果 |
|----------|------|--------|------|
| Solo（単一エージェント） | 20分 | $9 | ゲームが動作しない（エンティティ配線が壊れている） |
| Full harness（3エージェント） | 6時間 | $200 | 物理演算付きのプレイ可能なゲーム |
| Opus 4.6改良ハーネス（DAW） | 3h 50m | $124.70 | フルブラウザベース音楽制作アプリ |

**重要な知見**: 「興味深いハーネスの組み合わせはモデルが改善しても縮小しない — *移動*する」（Anthropic）。各コンポーネントは「モデルが単独でできないこと」の前提をエンコードしており、モデル進化で不要になるものと新たに価値が出るものがある。

---

## Dependencies & Data Flow

### 現在のユーザー環境

- **Claude Code**: `~/.claude/` に詳細なルール体系が構築済み（coding-style, security, testing, workflow, agents等）
- **Cursor**: `~/.cursor/` にはCLI設定のみ。ルール・エージェント・スキルは未設置
- **現プロジェクト**: `/Users/y-asano/Environments/cursor/my-settings/` — Cursor個人設定の管理用ディレクトリ

### Claude Code設定からの移植候補

既存の`~/.claude/rules/`にある以下のルールをCursor用に変換可能:

| Claude Codeルール | Cursor変換 | 適用モード |
|------------------|-----------|-----------|
| `coding-style.md` | `coding-standards.mdc` | Always Apply |
| `security.md` | `security.mdc` | Always Apply |
| `testing.md` | `testing.mdc` | Apply Intelligently |
| `git-workflow.md` | `git-workflow.mdc` | Apply Intelligently |
| `quality-criteria.md` | `quality-criteria.mdc` | Apply Intelligently |
| `anti-patterns.md` | `anti-patterns.mdc` | Always Apply |
| `agents.md` | サブエージェント定義に分解 | — |
| `workflow.md` | スキルまたはルールに変換 | — |

---

## Constraints & Invariants

### 公式ベストプラクティス（厳守事項）

1. **ルールは500行以下** — 大きなルールは分割する
2. **コピーではなく`@filename`参照** — コンテンツの陳腐化を防ぐ
3. **リンター/フォーマッターのルールを複製しない** — ツールに任せる
4. **ドメイン知識とプロジェクト固有パターンをエンコードする** — これがルールの本来の目的
5. **具体的なDO/DON'Tコード例を含める** — 抽象的な指示より効果的
6. **`description`フィールドを具体的に書く** — Apply Intelligentlyの精度に直結

### 技術的制約

- サブエージェントはネスト不可（1階層のみ）
- User Rulesはインラインエディット（Cmd+K）には適用されない
- グローバル設定はプロジェクト設定より低優先度（上書きされる）
- `~/.cursor/agents/`の互換パスとして`~/.claude/agents/`も探索される

---

## Risks & Considerations

### 1. コンテキストウィンドウの圧迫

Always Applyルールが多すぎると、毎回コンテキストウィンドウを消費する。Apply Intelligentlyを活用して必要な時だけロードさせる。

### 2. Claude CodeとCursorの設定重複

両ツールが`~/.claude/agents/`を共有探索するため、Claude Code専用のエージェントがCursorでも読み込まれる可能性がある。明確な棲み分けが必要。

### 3. ルールの過剰設定

コミュニティの教訓: ルールを入れすぎると意図しない副作用（コメント全削除等）が発生する。「最低限の実装」方針を堅持する。

### 4. 設定の分散管理

`~/.cursor/`直下に設定が散らばるため、このプロジェクト（`my-settings`）でバージョン管理し、シンボリックリンクやsyncスクリプトで配置する戦略が望ましい。

---

## Recommendations for Planning Phase

### 全体アーキテクチャ（ハーネス設計）

```
ユーザー → Cursor Agent（司令塔 / Generator: composer-2-fast）
  ↓
  orchestrate ルール（ワークフロー自動判定）
  ↓
  ┌─── planner [Opus 4.6]（仕様展開・タスク分解）
  │       ↓ ハンドオフドキュメント
  ├─── [メインAgent が実装]（Generator: composer-2-fast）
  │       ↓ 実装完了
  ├─── qa-reviewer [GPT-5.4]（厳格評価）──→ FAIL時: 修正指示を返す（Evaluator）
  │       ↓ PASS
  ├─── security-reviewer [GPT-5.4]（セキュリティ検証）
  │       ↓ PASS
  └─── 完了報告

  [並列起動可能]
  ├─── researcher [Gemini 3.1 Pro]（調査・バックグラウンド）
  └─── architect [Opus 4.6]（設計判断）
```

**ハーネスの核心**:
- **Generator**（メインAgent: composer-2-fast）と **Evaluator**（qa-reviewer: GPT-5.4）でモデルを分離し、自己評価バイアスを物理的に排除
- **思考系**（planner, architect）は推論深度重視で Opus 4.6
- **コード系**（qa-reviewer, security-reviewer）はコーディング性能重視で GPT-5.4
- **調査系**（researcher）はコンテキスト長・コスト効率重視で Gemini 3.1 Pro

### モデル割り当てサマリー

| エージェント | モデル | 選定基準 |
|------------|--------|---------|
| メインAgent (Generator) | `composer-2-fast` | 速度・コスト・diff特化 |
| planner | `claude-opus-4-6` | 推論深度・仕様展開 |
| architect | `claude-opus-4-6` | トレードオフ分析・設計判断 |
| qa-reviewer (Evaluator) | `gpt-5.4-medium` | コードレビュー・境界値検出 |
| security-reviewer | `gpt-5.4-medium` | コード読解・脆弱性分析 |
| researcher | `gemini-3.1-pro` | 1Mコンテキスト・コスト効率 |

### サブエージェント設計（5体）

#### 1. `~/.cursor/agents/planner.md` — 仕様展開・タスク分解

| 項目 | 値 |
|------|-----|
| **役割** | Planner（仕様展開） |
| `readonly` | `true` |
| `model` | `claude-opus-4-6` |
| `is_background` | `false` |
| **自動委譲トリガー** | 機能実装・バグ修正・リファクタリング等、複数ファイル変更が見込まれるタスク |
| **モデル選定理由** | アーキテクチャ判断・トレードオフ分析の推論深度が最高。仕様展開には深い思考力が必要 |

**責務**:
- ユーザーの1-4行の要件を詳細な実装仕様に展開
- 技術的な実装詳細は指定しない（誤った判断の伝播を防止）
- 影響範囲の特定、依存関係の洗い出し
- Sprint Contract の定義（何を作り、どう検証するか）
- ハンドオフドキュメントの生成（findings, 変更対象ファイル, 未解決の質問, 推奨事項）

**出力形式**:
```markdown
## Sprint Contract
### 実装スコープ
### 検証基準（具体的テスト項目）
### 影響ファイル
### リスク・制約
### 除外事項（スコープ外）
```

#### 2. `~/.cursor/agents/qa-reviewer.md` — 厳格な品質評価（Evaluator）

| 項目 | 値 |
|------|-----|
| **役割** | Evaluator（品質ゲート） |
| `readonly` | `true` |
| `model` | `gpt-5.4-medium` |
| `is_background` | `false` |
| **自動委譲トリガー** | コード変更の完了後、品質レビューが必要な場合 |
| **モデル選定理由** | コードレビューにはコーディング性能が最も高いモデルが適切。エラーハンドリング・再帰・境界値の検出に強い |

**責務**:
- Sprint Contract の検証基準に基づく厳格な評価
- PASS / FAIL の二値判定（「概ね問題なし」は禁止）
- FAIL時は具体的な修正指示を返す（何が問題で、どう直すか）
- エッジケース（null, empty, boundaries, errors）の網羅性確認
- スタブ・モックで誤魔化していないかの検出

**評価基準**:
1. 仕様通りに動作するか（Correctness）
2. エッジケースは処理されているか（Completeness）
3. コード品質・保守性（Code Quality）
4. エラーハンドリング・ユーザーフィードバック（Safety）
5. テストの存在と妥当性（Testing）

**判定ルール**:
- 1つでも基準未達 → **FAIL** + 具体的修正指示
- 全基準達成 → **PASS** + 残存リスクの列挙（あれば）

#### 3. `~/.cursor/agents/security-reviewer.md` — セキュリティ検証

| 項目 | 値 |
|------|-----|
| **役割** | セキュリティゲート |
| `readonly` | `true` |
| `model` | `gpt-5.4-medium` |
| `is_background` | `false` |
| **自動委譲トリガー** | 認証・入力処理・API・機密データ関連のコード変更時 |
| **モデル選定理由** | セキュリティレビューもコード読解力が必要。GPT-5.4の多段階操作・環境駆動型分析に強い特性を活用 |

**責務**:
- OWASP Top 10 の観点でのレビュー
- ハードコードされた秘密情報の検出
- 入力バリデーションの妥当性確認
- プロンプトインジェクション防御（AI関連コード）
- 依存パッケージの既知脆弱性チェック

#### 4. `~/.cursor/agents/researcher.md` — 調査・情報収集

| 項目 | 値 |
|------|-----|
| **役割** | 調査員（コードベース・外部情報） |
| `readonly` | `true` |
| `model` | `gemini-3.1-pro` |
| `is_background` | `true` |
| **自動委譲トリガー** | 既存コードベースの理解、外部ドキュメント参照が必要な場合 |
| **モデル選定理由** | 1Mコンテキストで大規模コードベースを一度に把握。コスト効率最良($2/$12)でバックグラウンド調査に最適 |

**責務**:
- コードベースの構造・パターン・依存関係の調査
- 外部ドキュメント・APIリファレンスの参照
- 既存実装のアーキテクチャパターン分析
- 調査結果の構造化レポート

#### 5. `~/.cursor/agents/architect.md` — アーキテクチャ判断

| 項目 | 値 |
|------|-----|
| **役割** | アーキテクト |
| `readonly` | `true` |
| `model` | `claude-opus-4-6` |
| `is_background` | `false` |
| **自動委譲トリガー** | システム設計判断、大規模リファクタリング、新規アーキテクチャ導入時 |
| **モデル選定理由** | plannerと同様、トレードオフ分析・構造化思考の深度が最高。設計判断にはOpusの推論力が最適 |

**責務**:
- 既存アーキテクチャとの整合性評価
- 設計トレードオフの分析
- スケーラビリティ・保守性の観点での判断
- 技術的負債の特定と対処方針

### ワークフロー設計（オーケストレーション）

#### オーケストレーションルール: `~/.cursor/rules/orchestrate.mdc`

| 項目 | 値 |
|------|-----|
| `description` | 機能実装・バグ修正・リファクタリング・セキュリティ修正時のワークフロー定義 |
| `alwaysApply` | `false`（Apply Intelligently） |

**ワークフロー定義**:

| タスク種別 | エージェントチェーン | 決定的ゲート |
|-----------|-------------------|------------|
| **feature** | planner → 実装 → qa-reviewer → security-reviewer | lint/test 各ステップ後 |
| **bugfix** | researcher → planner → 実装 → qa-reviewer | lint/test 各ステップ後 |
| **refactor** | architect → planner → 実装 → qa-reviewer | lint/test 各ステップ後 |
| **security** | security-reviewer(分析) → planner → 実装 → security-reviewer(検証) → qa-reviewer | lint/test 各ステップ後 |

**各ワークフローの詳細フロー（feature例）**:

```
Step 1: /planner — 仕様展開・Sprint Contract生成
  ↓ ハンドオフドキュメント
  [Gate: ユーザー確認 — Contractに同意するか]
Step 2: メインAgent — Sprint Contract に従い実装
  ↓ 実装完了
  [Gate: lint/format/typecheck 実行]
Step 3: /qa-reviewer — Sprint Contract の検証基準で評価
  ↓ FAIL → Step 2に戻る（修正指示付き、最大3回リトライ）
  ↓ PASS
Step 4: /security-reviewer — セキュリティ検証
  ↓ FAIL → Step 2に戻る
  ↓ PASS
Step 5: 完了報告（変更ファイル、テスト結果、判定サマリー）
```

**リトライルール**: 同じステップで3回FAILした場合は停止し、ユーザーにブロッカーを報告する。

#### 自動オーケストレーション判定: `~/.cursor/rules/workflow.mdc`

| 項目 | 値 |
|------|-----|
| `description` | タスク種別の自動判定とオーケストレーション開始 |
| `alwaysApply` | `true` |

**内容**:
以下の条件に該当するタスクを受けた場合、orchestrateワークフローに従って自動的に実行する:

| タスク種別 | 判定条件 |
|-----------|---------|
| feature | 新機能追加、機能実装の要求 |
| bugfix | バグ修正、不具合対応の要求 |
| refactor | リファクタリング、構造改善の要求 |
| security | セキュリティ修正、脆弱性対応の要求 |

**除外条件（直接実行してよい）**:
- 1ファイル・数行の修正
- 設定ファイル編集（JSON, YAML, TOML）
- ドキュメント・README の編集
- git 操作（コミット、ブランチ、マージ）
- 質問への回答・説明・調査

### ルール設計（7本）

| # | ファイル | 適用モード | 用途 |
|---|---------|-----------|------|
| 1 | `coding-standards.mdc` | Always Apply | コーディングスタイル（immutability, ファイル構成） |
| 2 | `anti-patterns.mdc` | Always Apply | ハルシネーション防止、スコープ規律、ループ防止 |
| 3 | `quality-criteria.mdc` | Always Apply | 評価基準（Evaluator方向付け + Generator品質制御） |
| 4 | `workflow.mdc` | Always Apply | 自動オーケストレーション判定・除外条件 |
| 5 | `orchestrate.mdc` | Apply Intelligently | ワークフロー定義（feature/bugfix/refactor/security） |
| 6 | `security.mdc` | Apply Intelligently | セキュリティガイドライン |
| 7 | `git-workflow.mdc` | Apply Intelligently | コミットメッセージ規約、PR作成ルール |

**Always Apply（4本）**: 毎回ロード。コンテキスト予算に注意し各200行以下を目標。
**Apply Intelligently（3本）**: AIが`description`で判断。必要時のみロード。

### 設計一覧サマリー

```
~/.cursor/
  agents/
    planner.md          # 仕様展開・Sprint Contract
    qa-reviewer.md      # 厳格な品質評価（Evaluator）
    security-reviewer.md # セキュリティゲート
    researcher.md       # 調査・情報収集（background）
    architect.md        # アーキテクチャ判断
  rules/
    coding-standards.mdc  # Always Apply
    anti-patterns.mdc     # Always Apply
    quality-criteria.mdc  # Always Apply
    workflow.mdc          # Always Apply（オーケストレーション自動判定）
    orchestrate.mdc       # Apply Intelligently（ワークフロー定義）
    security.mdc          # Apply Intelligently
    git-workflow.mdc      # Apply Intelligently
```

合計: **サブエージェント5体 + ルール7本**

### 設計原則（ハーネス設計から導出）

1. **生成と評価を分離**: メインAgent = Generator、qa-reviewer = Evaluator。自己評価バイアスを構造的に排除
2. **強制 > 依頼**: ルールは具体的なDO/DON'Tパターン。オーケストレーションは自動判定で開始
3. **Sprint Contract で検証基準を先行定義**: plannerが検証基準を定義し、qa-reviewerがそれで評価。曖昧な実装・曖昧な承認を防止
4. **決定的ゲートの挿入**: 各ステップ間にlint/test/typecheck。エージェントが省略不可能な設計
5. **リトライ上限と明示的停止**: 同一ステップ3回FAILで停止・報告。無限ループ防止
6. **コンテキスト予算を管理**: Always Applyは4本・各200行以下。残りはApply Intelligently
7. **ハーネスは進化させる**: モデル更新時にルールの有効性を再評価し、不要なものを削除

### 管理戦略

- このプロジェクト（`my-settings`）でルール・エージェント定義を一元管理
- シンボリックリンクまたはsyncスクリプトで`~/.cursor/`に配置
- Claude Code設定との棲み分け: `~/.cursor/agents/`を使用（`~/.claude/agents/`は共有探索されるため避ける）

---

## 参考リソース

| リソース | URL/パス |
|---------|---------|
| **ハーネス設計** | |
| ハーネスエンジニアリング記事 | `https://ai.acsim.app/articles/harness-engineering-2026` |
| Claude Code ハーネス設計記事 | `https://claude-code-academy.dev/articles/claude-code-harness-design` |
| everything-claude-code (115k+ stars) | `https://github.com/affaan-m/everything-claude-code` |
| **Cursor公式** | |
| Cursor公式Rulesドキュメント | `https://cursor.com/docs/rules` |
| Cursor公式Agentドキュメント | `https://cursor.com/docs/agent` |
| Cursor公式Hooksドキュメント | `https://cursor.com/docs/agent/hooks` |
| **コミュニティ** | |
| awesome-cursorrules (10k+ stars) | `github.com/PatrickJS/awesome-cursorrules` |
| cursor.directory (コミュニティハブ) | `cursor.directory` |
| RIPER-5 プロトコル (2.5k stars) | `github.com/NeekChaw/RIPER-5` |
| awesome-cursor-rules-mdc (自動生成ツール) | `github.com/sanjeed5/awesome-cursor-rules-mdc` |
| **既存設定** | |
| Claude Codeグローバルルール | `~/.claude/rules/` |
