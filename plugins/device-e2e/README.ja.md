[English](README.md) · [Tiếng Việt](README.vi.md) · **日本語**

# device-e2e

Mac から実機でモバイルアプリをエンドツーエンドテストします: iPhone は WebDriverAgent 経由、Androidスマートフォンは adb + uiautomator 経由です。iPhone 13 と Redmi 15C で e-Scanner をテストする中で作られ、そこで実機の時間を浪費した落とし穴を記録しています。

| 構成要素 | 役割 |
|---|---|
| `agents/device-tester.md` | ケースを計画し、スマートフォンを操作し、すべての FAIL をトリアージし (ハーネスのバグかアプリのバグか)、後片付けをし、証拠付きで PASS/FAIL/BLOCKED を報告します。brief で指示された場合のみアプリのコードを変更します。 |
| `skills/playbook/` | 手順: ワークフロー、トリアージ、実機ルール、後片付け、レポート。加えて `references/test-design.md` (漏れも重複もなく仕様 (spec) からケースを導く方法、失敗し得るオラクル、実機時間の予算)、`references/glossary.md` (用語ごとに 1 つの意味、PASS/FAIL/BLOCKED/NOT RUN)、`references/ios.md`、`references/android.md`、`references/traps.md`。 |
| `skills/playbook/e2e_test_plan.template.md` | 計画: リスク付きのテストベース、因子、状態 × イベント表、実行ステップ (`READY`、`DRY`、`DIAG`)、実機時間 (分) と実行順序付きのケース、*Covered below e2e*、*Not covered*。そして結果のレイアウト: ヘッダー、表、`BUG-n` の欠陥エントリ、`E2E:` 行。 |
| `bin/validate_e2e_plan.py` | モデルを使わずに計画をチェックします: すべての仕様 の目標とベース項目に、ケース、名前付きの下位レベルのテスト、または *Not covered* の理由のいずれかがあること。冗長なケースがないこと。空の状態 × イベントのセルがないこと。失敗し得ない Expected がないこと。実機時間の合計が予算に収まること。`--results` 付きの場合: ヘッダーがビルドとこの計画を示していること、計画したすべてのケースと実行ステップにプラットフォームごとの PASS/FAIL/BLOCKED/NOT RUN の行があること、すべての FAIL に完全な `BUG-n` があること、`E2E:` の件数が一致すること。 |
| `skills/playbook/harness/` | `IosDriver` (WebDriverAgent HTTP) と `AndroidDriver` (adb + uiautomator) は同じメソッド名を持ち、環境変数を読みます: iPhone には `WDA=http://<ip>:8100`、その他には `E2E_*`。Python 3 標準ライブラリのみを使います。 |
| `commands/init.md` | `/device-e2e:init`: テンプレートから `.claude/device-e2e/project.md` を作成し、未記入のスロットを一覧表示します。 |
| `skills/playbook/project.template.md` | エージェントが必要とするプロジェクトの事実情報: デバイス、アプリ ID、ビルドコマンド、ハーネスのパス、後片付け。 |

## セットアップ

1. `claude plugin install device-e2e@escanner-agent-kit` (`review-gate` に依存します。そのフックがエージェントによる破壊的な git コマンドの実行を止めます)。
2. プロジェクトで `/device-e2e:init` を実行します。`project.template.md` から `.claude/device-e2e/project.md` を作成し(既存のものは上書きしません)、記入が残っているスロットを一覧表示します。
3. iPhone 用に WebDriverAgent を一度ビルドし、iPhone で Developer Mode と UI Automation を有効にし、ロックを解除したままMac と同じ Wi-Fi に接続しておき、adb から Android スマートフォンが見えるようにします (`adb devices`)。手順: [`ios.md`](skills/playbook/references/ios.md)、[`android.md`](skills/playbook/references/android.md)。
4. 2 つのドライバーの上に、アプリのフローモジュールとスイートを書きます。形はスキルが説明しています。

エージェントの brief には固定の行 (`SPEC`、`PLAN`、`PLATFORMS`、`BUDGET` など) があり、`agents/device-tester.md` に記載されています。あとは普通の言葉で頼むだけです。例: 「両方のスマートフォンで import のケースを実行して」。または `device-tester` をディスパッチします。

## やらないこと

- brief にオーナーの承認が書かれていない限り、アプリをビルドまたは再インストールしません。アンインストールするとアプリのデータが消えます。
- データが重要なスマートフォンで `xcodebuild test` や `flutter drive` を使いません。
- 実機から読み取った証拠なしに、または前提条件が証明されていないケースについて、PASS を報告しません。
- オーナーがテスト計画を承認する前に実機を動かしたり、計画したケースを結果から削除したりしません。
