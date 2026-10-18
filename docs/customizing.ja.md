[English](customizing.md) · [Tiếng Việt](customizing.vi.md) · **日本語**

# カスタマイズ

以下の設定はどれも必須ではありません。`/review-gate:init` の後は、キットはデフォルト設定で動作します。

## 1. ファイルパスを設定する

**いつ:** ブリーフ、ルール、仕様 (spec) がデフォルトのフォルダーにない場合。

キットは自身のファイルを `.claude/review-gate/` から、仕様 を `docs/specs/` と `docs/features/` から探します。バリデータースクリプトの参照先を変更するには、`.claude/review-gate/config.env` (`init` がコピーします) で必要なキーだけを設定します。

```
BRIEF_FILE=$ROOT/docs/agents/review_brief.md
RULES_FILE=$ROOT/docs/agents/review_rules.md
SPECS_DIR=$ROOT/documentation/specs
```

| キー | パス | デフォルト |
|---|---|---|
| `BRIEF_FILE` | プロジェクトの事実とレビュープロトコル | `.claude/review-gate/review_brief.md` |
| `RULES_FILE` | ルール ID の一覧 | `.claude/review-gate/review_rules.md` |
| `ROUTING_FILE` | どのエージェントがどのフォルダーを担当するか | `.claude/review-gate/routing.md` |
| `PITFALLS_FILE` | プロジェクトの落とし穴リスト | `.claude/review-gate/common_pitfalls.md` |
| `SPECS_DIR` | 仕様 | `docs/specs` |
| `FEATURES_DIR` | 機能フォルダー (タスク、状態) | `docs/features` |

値に使えるのは `$ROOT` (プロジェクトルート) と `$CONTEXT_DIR` (`.claude/review-gate`) だけです。`config.env` を読むのはバリデータースクリプトだけで、エージェントとコマンドのプロンプトは常に `.claude/review-gate/<file>` を読みます。ファイルを別の場所に置く場合は、そこへのシンボリックリンクも作成します。例: `ln -s ../../docs/agents/review_brief.md .claude/review-gate/review_brief.md`

プロジェクトルートは次の順で決まります: 設定されていれば `REVIEW_GATE_PROJECT_DIR`、次に `CLAUDE_PROJECT_DIR`、git ルート、カレントディレクトリ。

## 2. 自分のスタック用のルールを追加する

**いつ:** レビュアーに自分のスタック (web、バックエンド、ゲームなど) のルールを引用させたい場合。

ルール ID は `R-<NAMESPACE>-<number>` の形式です。名前空間を追加するには、`review_rules.md` のセクション 2b の表に、1 行につき 1 ルールで行を追加します。

```
| `R-WEB-1` | Never render user input as raw HTML | High |
| `R-WEB-2` | Every API call has a timeout | Medium |
```

設定すると、レビュアーは `R-WEB-1` を引用でき、`validate_rule_ids.sh` もそれを受け入れます。行のない ID は破棄されるため、レビュアーが ID をでっち上げることはできません。

## 3. 独自のエージェントを追加する

**いつ:** キットがカバーしていないコードベースの部分に、コーダーやレビュアーが必要な場合。

1. `<scope>-<role>` の形式で命名します。例: `web-reviewer`、`backend-coder`。役割とその権限は [agent-guideline.ja.md](agent-guideline.ja.md) にあります。
2. ファイルを `.claude/agents/<name>.md` (プロジェクトエージェント) か、自分のプラグイン (セクション 4 を参照) に置きます。
3. エージェントには、まず `.claude/review-gate/review_brief.md` を読み、そのブリーフの §B7 にあるハンドオフブロックで返信を締めくくるよう指示します。レビュアーはレポートファイルを書くために `tools:` 行に `Write` も必要で (§B7)、`Edit` は持たせません。
4. `routing.md` で、エージェントを担当フォルダーの横に追加します。プラグインエージェントは `<plugin>:<agent>` と書きます。例: `my-stack:web-reviewer`。

## 4. 自分のスタック用のプラグインを作る

**いつ:** `flutter-native` が Flutter 向けに行っているように、一連のエージェントを複数のプロジェクトで再利用したい場合。

1. `plugins/flutter-native` をコピーして名前を変えます。その `.claude-plugin/plugin.json` で `name`、`displayName`、`description` を変更します。変更しないとコピーが元のプラグインと衝突します。
2. エージェントを自分のものに置き換えます。
3. その `plugin.json` には `"dependencies": ["review-gate"]` を残し、git 安全フックとバリデーターが一緒にインストールされるようにします。
4. プラグインを自分の marketplace ファイルに記載します。

Claude Code はプラグインエージェントの frontmatter にある `hooks`、`mcpServers`、`permissionMode` を無視します。これらは不要です。安全フックは `review-gate` から提供されます。

## 5. エージェントの名前を変更する

**いつ:** すでに使われたことのあるエージェントの名前を変更する場合。

`routing.md` の "Legacy names" セクションに、旧名と新名を追加します。例: `review-web → web-reviewer`。古い `execution_state.md` ファイルはまだ旧名を使っており、パイプラインはこの対応表を使って正しいエージェントを見つけます。
