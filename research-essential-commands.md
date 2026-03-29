# Research: 個人用に設置すべき必須コマンド（Skills）の調査

## Date: 2026-03-30

## Scope

AI コーディングツール（Cursor, Claude Code, Windsurf 等）で一般的に個人用に設置されるコマンド/スキルを、コミュニティの合意と複数ソースの出現頻度に基づいて収集・整理する。

---

## 調査ソース

| ソース | 規模 | URL |
|--------|------|-----|
| everything-claude-code | 28 agents, 135+ skills, 60+ commands | github.com/affaan-m/everything-claude-code |
| obra/superpowers | 14 core skills | github.com/obra/superpowers |
| wshobson/commands | 57 commands (15 workflows + 42 tools) | github.com/wshobson/commands |
| qdhenry/Claude-Command-Suite | 216+ commands, 15 namespaces | github.com/qdhenry/Claude-Command-Suite |
| rohitg00/awesome-claude-code-toolkit | 135 agents, 42 commands, 35 skills | github.com/rohitg00/awesome-claude-code-toolkit |
| SkillsAuth Hub | 50+ verified skills, 114k+ DL | skillsauth.com |
| SkillHub.club | 36,000+ skills | skillhub.club |
| Claude Code 公式 | 40+ built-in commands | code.claude.com/docs |
| batsov.com (Essential Skills記事) | Must-have 分析 | batsov.com |
| Medium (10 Must-Have Skills) | 推奨リスト | medium.com/@unicodeveloper |

---

## Architecture & Patterns

### コミュニティ合意: 必須コマンドのカテゴリ分類

複数ソース（3箇所以上）で推奨されたコマンドを、開発ワークフローの順序に沿って整理する。

#### Tier 1: ほぼ全ソースで推奨（5箇所以上）

| # | カテゴリ | コマンド名 | 何をするか | 出現ソース数 |
|---|---------|-----------|-----------|------------|
| 1 | 計画 | **plan** | 実装前に要件整理・ステップ分解・リスク評価。コードに触らない | 6+ |
| 2 | テスト | **tdd** | RED→GREEN→REFACTOR のTDDサイクル強制。テストを先に書く | 6+ |
| 3 | レビュー | **review** | コード品質・セキュリティ・パフォーマンスの多角的レビュー | 6+ |
| 4 | Git | **commit** | diff分析→Conventional Commits形式のメッセージ自動生成 | 5+ |
| 5 | セキュリティ | **security-review** | OWASP Top 10、秘密情報漏洩、入力バリデーション検査 | 5+ |

#### Tier 2: 多くのソースで推奨（3-4箇所）

| # | カテゴリ | コマンド名 | 何をするか | 出現ソース数 |
|---|---------|-----------|-----------|------------|
| 6 | デバッグ | **debug** | 4フェーズ根本原因分析。ランダムなprint文禁止、体系的調査 | 4 |
| 7 | Git | **pr** | ブランチ全コミット分析→PR title/description 生成→`gh pr create` | 4 |
| 8 | 検証 | **verify** | 完了宣言前に検証コマンド実行を強制。「証拠→主張」の順序 | 4 |
| 9 | テスト | **e2e** | E2Eフレームワーク自動検出→テスト生成→実行→結果報告 | 4 |
| 10 | リファクタ | **refactor** | デッドコード検出・削除、重複排除、構造改善 | 4 |
| 11 | 学習 | **learn** | セッション中のパターンを抽出し、再利用可能なスキルとして保存 | 4 |
| 12 | 計画 | **brainstorm** | 実装前のソクラテス式探索。要件・代替案・設計の検証 | 3 |
| 13 | ビルド | **build-fix** | ビルド/コンパイルエラーの自動解決。最小diffで修正 | 3 |
| 14 | オーケストレーション | **orchestrate** | タスク種別自動判定→エージェントチェーン駆動 | 3 |

#### Tier 3: 有用だが特定ソースのみ（1-2箇所、ただし高評価）

| # | カテゴリ | コマンド名 | 何をするか | 備考 |
|---|---------|-----------|-----------|------|
| 15 | 説明 | **explain** | コード・アーキテクチャの説明。新規参画者向け | Claude-Command-Suite |
| 16 | ドキュメント | **update-docs** | プロジェクトドキュメントの自動更新 | everything-claude-code |
| 17 | カバレッジ | **test-coverage** | テストカバレッジのギャップ分析 | everything-claude-code |
| 18 | 引き継ぎ | **handover** | セッション間の構造化引き継ぎドキュメント生成 | everything-claude-code |
| 19 | 調査 | **research** | コードベース深層調査。変更前の理解構築 | everything-claude-code |
| 20 | 簡素化 | **simplify** | 変更済みコードの再利用・品質・効率レビュー | Claude Code built-in |
| 21 | パフォーマンス | **benchmark** | パフォーマンスベースライン測定、リグレッション検出 | SkillsAuth (114k DL) |
| 22 | 安全性 | **safety-guard** | 本番環境への破壊的操作を防止 | SkillsAuth (114k DL) |

---

## Dependencies & Data Flow

### コマンドの依存関係（典型的なワークフロー順序）

```
[企画・調査フェーズ]
  brainstorm → research → plan
    ↓
[実装フェーズ]
  tdd → build-fix（エラー時）
    ↓
[検証フェーズ]
  review → security-review → verify
    ↓
[完了フェーズ]
  commit → pr → handover（次セッションへ）
    ↓
[保守フェーズ]
  refactor → e2e → test-coverage → update-docs
    ↓
[学習フェーズ]
  learn（パターン抽出・蓄積）
```

### Skill 内完結 vs Subagent 委譲

| コマンド | 処理方式 | 理由 |
|---------|---------|------|
| plan | Subagent委譲（planner） | 深い推論が必要、独立コンテキスト有効 |
| tdd | Skill内完結 | ワークフロー指示のみ、実装は親が実行 |
| review | Subagent委譲（qa-reviewer） | 別モデルでの評価が有効 |
| commit | Skill内完結 | git操作のみ、単純 |
| security-review | Subagent委譲（security-reviewer） | 専門的分析、独立コンテキスト有効 |
| debug | Skill内完結 | フレームワーク提供のみ |
| pr | Skill内完結 | git/gh操作のみ |
| verify | Skill内完結 | チェックリスト実行のみ |
| e2e | Skill内完結 | フレームワーク検出+テスト生成指示 |
| refactor | Subagent委譲（architect） | 設計判断が必要 |
| learn | Skill内完結 | パターン抽出・保存のみ |
| brainstorm | Skill内完結 | 対話的探索、親コンテキスト共有が必要 |
| build-fix | Skill内完結 | エラー読み取り+最小修正 |
| orchestrate | Skill（Subagentチェーンを駆動） | 複数Subagentの調整役 |
| explain | Skill内完結 | readonly、単純な説明 |
| research | Subagent委譲（researcher） | 大規模調査、バックグラウンド実行 |
| handover | Skill内完結 | ドキュメント生成のみ |

---

## Constraints & Invariants

### 個人用グローバルSkillの設計制約

1. **プロジェクト非依存**: 特定の言語・フレームワークに依存しない汎用設計
2. **コンテキスト予算**: Skill本体は50-100行以内。重い処理はSubagentに委譲
3. **明示呼び出し**: 全Skillに `disable-model-invocation: true`（誤発動防止）
4. **既存Subagentとの整合**: plan → planner, review → qa-reviewer 等の委譲パスを維持
5. **Cursor 2.4+ 必須**: Skills機能はCursor 2.4以降

### 取捨選択の基準

- **採用**: 週1回以上使うもの、または使わないとリスクがあるもの（security-review等）
- **不採用**: フレームワーク固有（Next.js, Django等）、プロジェクト固有のもの
- **不採用**: Claude Code built-in で十分なもの（/compact, /clear, /rewind, /diff, /context, /cost）

---

## Risks & Considerations

### 1. Skill数の肥大化
コミュニティのリポジトリは60+コマンドを持つものもあるが、個人用では10-15が現実的。多すぎるとどのコマンドを使うべきか迷い、結局使わなくなる。

### 2. Subagentとの二重定義
plan Skill と planner Agent で同じ指示を書くと保守負荷が倍増する。Skillは「何をすべきか」の最小指示に留め、「どうやるか」はSubagentに委ねる。

### 3. Claude Code との互換性
`~/.cursor/skills/` のSkillは Claude Code でも `~/.claude/skills/` にシンボリックリンクすれば利用可能（Cursor 2.4のクロスツール互換）。ただし、Subagent呼び出し構文が異なるため、委譲型Skillは完全互換にならない可能性がある。

---

## Recommendations for Planning Phase

### 推奨: 最小限の個人用Skill セット（12本）

優先度とワークフロー順序に基づき、以下の12本を推奨する:

#### 必須（Tier 1: 毎日使う）— 5本

| # | Skill名 | カテゴリ | 方式 |
|---|---------|---------|------|
| 1 | `plan` | 計画 | Subagent委譲 |
| 2 | `review` | レビュー | Subagent委譲 |
| 3 | `commit` | Git | Skill内完結 |
| 4 | `tdd` | テスト | Skill内完結 |
| 5 | `debug` | デバッグ | Skill内完結 |

#### 重要（Tier 2: 週数回使う）— 4本

| # | Skill名 | カテゴリ | 方式 |
|---|---------|---------|------|
| 6 | `pr` | Git | Skill内完結 |
| 7 | `verify` | 検証 | Skill内完結 |
| 8 | `research` | 調査 | Subagent委譲 |
| 9 | `explain` | 説明 | Skill内完結 |

#### 推奨（Tier 3: 必要時に使う）— 3本

| # | Skill名 | カテゴリ | 方式 |
|---|---------|---------|------|
| 10 | `orchestrate` | ワークフロー | Subagentチェーン |
| 11 | `refactor` | リファクタ | Subagent委譲 |
| 12 | `build-fix` | ビルド修正 | Skill内完結 |

### 除外したもの（理由付き）

| コマンド | 除外理由 |
|---------|---------|
| security-review | 既存の security-reviewer Subagent で `/security-reviewer` として直接呼び出し可能 |
| e2e | プロジェクト固有のE2Eフレームワーク依存が強い。必要時にプロジェクトレベルで設置 |
| learn | continuous-learning スキルとして自動適用する方が効果的（明示呼び出しよりも） |
| simplify | Claude Code built-in で十分 |
| handover | 頻度が低い。必要時に手動で指示すれば十分 |
| benchmark | パフォーマンス計測はプロジェクト固有 |
| test-coverage | tdd Skillに統合可能 |
| update-docs | 頻度が低い。必要時に手動指示で十分 |
| brainstorm | plan Skillの冒頭フェーズとして統合可能 |
| safety-guard | ルール（rules/）で常時適用する方が効果的 |

### ディレクトリ構成

```
my-settings/
  skills/                    # 新規作成
    plan/SKILL.md            # 実装計画
    review/SKILL.md          # コードレビュー
    commit/SKILL.md          # Conventional Commits
    tdd/SKILL.md             # テスト駆動開発
    debug/SKILL.md           # 体系的デバッグ
    pr/SKILL.md              # PR作成
    verify/SKILL.md          # 完了前検証
    research/SKILL.md        # コードベース調査
    explain/SKILL.md         # コード説明
    orchestrate/SKILL.md     # ワークフロー駆動
    refactor/SKILL.md        # リファクタリング
    build-fix/SKILL.md       # ビルドエラー修正
  agents/                    # 既存維持（Subagent）
    planner.md
    qa-reviewer.md
    security-reviewer.md
    researcher.md
    architect.md
  rules/                     # 既存維持
    ...7本
  scripts/
    deploy.sh                # 更新必要: skills/ の配置を追加
```

---

## 参考リソース

| リソース | URL |
|---------|-----|
| Cursor Skills 公式 | https://cursor.com/docs/skills |
| everything-claude-code | https://github.com/affaan-m/everything-claude-code |
| obra/superpowers | https://github.com/obra/superpowers |
| wshobson/commands | https://github.com/wshobson/commands |
| Claude-Command-Suite | https://github.com/qdhenry/Claude-Command-Suite |
| awesome-claude-code | https://github.com/hesreallyhim/awesome-claude-code |
| awesome-claude-code-toolkit | https://github.com/rohitg00/awesome-claude-code-toolkit |
| SkillsAuth Hub | https://skillsauth.com/skills/hub/for-cursor |
| SkillHub.club | https://www.skillhub.club |
| Essential Skills 記事 | https://batsov.com/articles/2026/03/11/essential-claude-code-skills-and-commands/ |
| 10 Must-Have Skills | https://medium.com/@unicodeveloper/10-must-have-skills-for-claude-and-any-coding-agent-in-2026-b5451b013051 |
| chrisboden/cursor-skills | https://github.com/chrisboden/cursor-skills |
| gotalab/skillport | https://github.com/gotalab/skillport |
