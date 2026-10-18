[English](guide-new-feature.md) · [Tiếng Việt](guide-new-feature.vi.md) · **日本語**

# ガイド：エージェントで新機能を開発する

このウォークスルーでは、例として **「ノートのピン留め/ピン留め解除」** をパイプライン全体に通します。以下に引用する出力はすべて、小さなテストプロジェクト（C++ エンジンを持つ Flutter のノートアプリ）での実際の実行結果です。参考として使ってください。あなたのプロジェクトの事実、エージェント、ルールは異なります。

## 始める前に

> **このキットは参照用の土台であり、完成品ではありません。** エージェント、ルール、レビュー
> プロセスの構成方法を示しています。パターンをコピーし、エージェント、ルールの語彙、ルーティングをプロジェクトに合わせてください。
> `flutter-native` のエージェントは、そのままではあなたのコードベースに合いません。

> **エージェントの実行には多くのトークンを消費します。** 1 つの機能で、コーダー、複数のレビュアー、指摘ごとに 1 回のフィルター
> 呼び出し、場合によっては修正ラウンドが起動します。**Claude Code Max プラン**を使い、トークン従量課金の API でキットを実行しないでください。

## 0. プロジェクトごとの初回セットアップ

```bash
claude plugin marketplace add nccong85/escanner-agent-kit
claude plugin install review-gate@escanner-agent-kit
claude plugin install dev-pipeline@escanner-agent-kit
claude plugin install flutter-native@escanner-agent-kit   # or your own stack plugin
```
プラグインを 1 つのプロジェクトに限定するには `--scope local` を付けます。実機でのテストには、さらに`device-e2e@escanner-agent-kit` をインストールし、プロジェクトで `/device-e2e:init` を実行します。

**後で更新するには：** `claude plugin marketplace update escanner-agent-kit` を実行し、続いて`claude plugin update <plugin>@escanner-agent-kit` を実行します（ローカルインストールの場合は `--scope local` を付けます）。そのプロジェクトで `claude plugin list` を確認し、バージョンがまだ古ければ、そこでプラグインをアンインストールして再インストールします。

プロジェクト内で `/review-gate:init` を実行します。`.claude/review-gate/` を作成し、コードからプロジェクトの事実の下書きを作ります。次に **すべての `<VERIFY>` を確定させます**。この手順が、以降のすべてのレビューの品質を決めます。

| ファイル | 確認すべきこと |
|---|---|
| `review_brief.md` Part A | レイアウト、実際に動くコマンド、単位付きの予算、実際に強制している譲れない条件 |
| `routing.md` | 各ディレクトリをどのエージェントがコーディングし、どれがレビューするか。どのゲートがどのパスで発動するか |
| `review_rules.md` | 予算の行（`R-BUD-*`）と、lint/テストですでに強制しているもの（MECHANIZED） |
| `common_pitfalls.md` | 例を、あなたの最初の実際の欠陥クラスに置き換えます |

`init` は実際のレイアウトを見つけ、推測せざるを得なかったものをすべて `<VERIFY>` としてマークします。

## 1. 仕様 (spec) を書く：`/dev-pipeline:spec-create "<feature>"`

```
/dev-pipeline:spec-create Add pin/unpin for notes: a pinned note always sorts above unpinned ones,
the pinned flag persists through NotesRepository, and pinning failures go through ErrorReporter.
```

plan モードで動作し、Part A と最も近い既存コードを読み、5〜7 個の質問（契約、つまり部品間のインターフェース。セキュリティ。パフォーマンス。スコープ。再利用）をして、`docs/features/<feature>/spec_<feature>.md` を書きます。

> **デモ実行について：** 非対話で実行したため、コマンドは自分の質問に最も
> 保守的な選択肢で答え、それを決定事項として記録しました。通常の利用では **あなた** が答えます。この手順の価値の大半は
> そこから生まれます。

良い仕様 の例：

- **7 つの目標、それぞれに証明**。例：*「G3 — ピン留めされたノートは常に、ピン留めされていないすべてのノートより上に並ぶ … テスト `pinnedFirst puts every pinned note before every unpinned note` と `… keeps relative order within each group` で証明」*。
- **Non-Goals (対象外) セクション**（UI、具体的なリポジトリ、ピン留め時刻による並び順、楽観的更新）。必須です。検証ステップはこれに照らしてスコープの膨張を確認します。
- **記録された決定事項**（このデモではモデルが 12 件を決定。例：*先に永続化し、成功後にのみリストを更新する*、*エラーコードは `pin_failed` の 1 つ、コンテキストは `notes.pin` / `notes.unpin` に固定*）。
- **予算の例外を明記する。** Part A の予算を超える回答は、§3 に 1 行で記載します。`Exception to <rule name>: <accepted limit>, scoped to <path or operation>, approved by the owner <YYYY-MM-DD>`。

**仕様 を確認してください。** これが人間によるゲートです。

## 2. 仕様 をゲートにかける：`/dev-pipeline:spec-validate <spec>`

6 つの条件：

| # | ゲート | 結果 |
|---|---|---|
| 1 | `validate_spec_refs.sh` が 0 で終了（14 パスを確認） | ✓ |
| 2 | Non-Goals (対象外) が存在し、空でない | ✓ |
| 3 | すべての目標に diff で確認できる受け入れ基準がある | ✓ |
| 4 | Open Questions が空 | ✓ |
| 5 | 契約、セキュリティ、パフォーマンス、ライセンスのチェックに合格 | ✓ |
| 6 | 危険信号なし | ✓ |

読む価値のある、ブロックしない不足点も 4 つ報告されました。ある決定事項に対するテストの欠落、既知の制約として文書化すべき未対処の`load()`/`setPinned` 競合、Flutter が `PATH` にないこと、Part A の誤った事実です。判定は仕様 の隣に保存されます（`validation_<feature>_<timestamp>.md`）。**Not Ready は失敗した条件を正確に示します**。それを直して再実行してください。

## 3. タスクに分解する：`/dev-pipeline:task-decompose <spec>`

`<feature>_tasks.md` と `execution_state.md`（`implement` が再開するチェックポイント）を書きます。確認事項：

- `routing.md` に従い **1 タスク、1 レイヤー、1 エージェント**。テスト実行では`flutter-native:flutter-coder` 向けのタスクが 1 つ作られ、その理由も説明されました。コードとテストは同じコーダーとレビュアーにルーティングされ、テストが 5 つの目標の証明になるためです。
- **レビュアーが採点できる完了の定義 (DoD)**：貼り付けた `flutter analyze` と`flutter test test/features/notes/notes_controller_test.dart` の出力、名前付きのテスト、diff で確認できるルール。
- ABI、ワイヤーフォーマット、API が変わる場合は **契約優先の順序**。
- 検証で見つかった不足点がタスクに組み込まれていること。
- ビルド、実機での実行、ベンチマークなど、あなただけが承認できる作業を必要とするタスクには **`**Gate:** owner approval — <what>`**。`implement` はあなたが承認するまで、そのタスクの前で停止します。
- **デバイスタスク**（`device-e2e:device-tester` にルーティング）は実機で実行されます。`.claude/device-e2e/project.md` がない、または未記入の場合、レポートが警告します。

## 4. 実装する：`/dev-pipeline:implement <spec> [--per-task]`

オーケストレーターは毎ターン `execution_state.md` を読むため、いつでも停止して再開できます。各タスクについて、コーダーを派遣し、続いて `routing.md` のレビュアーと、diff が発動させるゲートを派遣します。すべてのルール ID を検証し、変更のレビュー（差分レビュー）を伴う修正ラウンドを最大 2 回実行します。

`--per-task` を付けると各タスクの後で停止し、次のタスクは新しいセッションで実行されます。

テスト実行で起きたこと：

| ステップ | 結果 |
|---|---|
| コーダー（`flutter-coder`） | 仕様 が許可する 3 ファイルだけを変更し、テストを 11 件作成 |
| そのハンドオフ | `SELF-CHECK` ブロック、続いてファイル一覧付きの `ACTION: REVIEW_REQUIRED` |
| レビュアー（`flutter-reviewer`） | `QA_PASSED (blocking=0, deferred=1)`：ラウンド 1 なので修正ラウンドもフィルター呼び出しもなし |
| オーケストレーターによる証拠の再実行 | `flutter analyze` → *No issues found!* · `flutter test …` → *+11: All tests passed!* |
| `execution_state.md` のコスト台帳 | レビューラウンド 1 回 · 指摘 1 件（+ルール ID なし 2 件） · 修正ラウンド 0 回 |

自分の実行で注意すべきこと：

- **保留リストを読んでください。** Medium/Low の指摘は決してブロックしないので、あなたが決めない限り誰も修正しません。
- **ルール ID のない指摘は破棄されます。** 同じ種類が繰り返し出るなら、ルールか落とし穴のエントリを追加してください。

## 5. 機能を仕上げる

- **ステップ 5 は機能全体の監査です**（`--per-task` の場合は、最後のタスクの後にもう一度 `implement` を実行します）。レビュー対象はタスクをまたぐものだけ（2 つ以上のタスクが触れたファイル、契約、保留された指摘のあるファイル）で、保留された指摘をトリアージ用に一覧化し、修正ラウンドを 1 回許可します。
- **未修正の指摘をトリアージします。** Medium/Low の指摘は修正されません。最後にそれぞれについて決めます。今すぐ修正する、技術的負債として登録する、または破棄する。結果を記録します。指摘がノイズばかりのルールは`review_rules.md` から削除します。
- **繰り返す欠陥に対処します。**
  - 欠陥が繰り返し発生するなら、`common_pitfalls.md` に記録します。
  - `common_pitfalls.md` にすでにある欠陥がまだ発生するなら、テストを追加する（または lint を有効にする）ことで、`flutter test`/`analyze` が報告するようにします。
- **コミットは自分で行います。** パイプラインは決してコミットしません。

## 実行が止まったら

| 停止 | 意味 | 対処 |
|---|---|---|
| `Task n/N done … Continue in a fresh session` | `--per-task` の場合のみ。1 セッション 1 タスクにすることでコンテキスト、ひいてはトークンコストを小さく保ちます | `/clear` の後、`/dev-pipeline:implement <spec> --per-task` |
| `SPEC-DOUBT`（ルール C4） | ラウンド ≥ 2 で、修正が原因ではない新しいブロッキング指摘が出た | 仕様 が間違っているか不完全です。仕様 を直してから再開します |
| `FINAL_QA_PARTIAL` | 修正ラウンドを 2 回行ってもまだブロッキング | 未解決の指摘を読み、手で修正するか仕様 を変更します |
| レビュアー同士の矛盾 | 2 人のレビュアーが同じ行に正反対の変更を求めている | どの列が担当かを決めます（`routing.md`） |
| オーナーの承認待ち | 次のタスクに `**Gate:** owner approval` があり、承認が記録されていない | はい（またはいいえ）と答えます。承認はそのタスクについてのみ Pipeline State に記録されます |
| エージェントが `BLOCKED` を報告 | 意図的に停止した（承認なし、端末が使用中、プロジェクトファイルの欠落） | 示された理由を解消してから再開します |
| `FATAL`（バリデーターの終了コード 2） | レビューファイルがない、またはシンボリックリンクが壊れている | ファイルかリンクを直して（または `/review-gate:init` を再実行して）から再開します |
| デバイスまたは相互運用の実行が必要 | パイプラインでは実行できない | 自分で実行して出力を貼り付けるか、デバイス実行ならタスクを `device-e2e:device-tester` にルーティングします（`/device-e2e:init`） |
| セッション終了 / コンテキスト喪失 | — | `/dev-pipeline:implement <spec>` を再度実行します。`execution_state.md` を読み込みます |

## パイプラインを使わない場合

- **小さな修正や 1 ファイルの変更：** メインセッションで行い、アナライザーと対象を絞ったテストを実行してから、diff に対して `/review-gate:review` を実行します。仕様 やタスクなしで、同じバリデーターとフィルターが得られます。
- **調査やプロトタイプ：** このループは完成した変更を最適化するもので、探索のためのものではありません。
