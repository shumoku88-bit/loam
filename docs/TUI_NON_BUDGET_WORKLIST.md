# 非予算 TUI：画面別 UI 改修の進捗

## この一覧で管理すること

**既存機能の UI を、今の方向に整えたかどうかだけを管理する。**
機能追加のロードマップ、試用開始の条件、予算設定なしでの動作監査、
バックアップ整備は、この UI 改修キューに混ぜない。

共通方針：控えめな色、細い丸角の枠、整列と余白、情報の優先順位、
見える範囲に合ったフォーカス・スクロール、安定した下部ナビと通知。
機能・記録・修正・確定の意味は変えない。
画面の現行契約は [TUI.md](TUI.md) を参照する。
品質方針・目指す操作体験と今後の改善課題は [TUI_REFINEMENT_ROADMAP.md](TUI_REFINEMENT_ROADMAP.md) を参照する。

- **完了**：明記した画面の UI 改修と関連テストが完了。
- **一部完了**：既存の UI 改善はあるが、今回の方針で揃える作業が残る。
- **未着手**：今回の UI 統一に未着手。機能が未実装という意味ではない。
- 作業時は **作業中 → 検証待ち → 完了** に更新する。
- 完了した画面と未完了の補助画面をまとめて「全体完了」にしない。

初版のコード基準：`4d9d261b`。各行の「改修の状態」は見た目も含む仕上げ状況であり、機能の実装有無やCIの合否そのものではない。既にCIを通過した画面でも、手動の表示確認が残る場合は「一部完了」／「検証待ち」とする。下表は画面群を含む初版であり、着手時に
子画面を確認して分割・追記する。項目数から機能の完成率を計算しない。

## 画面別の進捗

2026-10-13：UI-01 の盆栽 Home を **正式化・完了**。
#1958 の opt-in 試作はユーザーの実機確認・了承後、通常起動の Home へ昇格した。
固定 ASCII 盆栽＋小さな `loam`＋6入口を維持（生成・アニメーション・追加依存なし）。
80×24 では盆栽全体、32×9／48×14 では装飾を畳み、既存の画面・Publisher へ委譲する。
`g`／Enter で Calendar、Calendar の `g`／フォーカス済み `q`／Esc で Home、Home の `q` だけが終了。
実験用の環境変数・enable フラグを廃止。既存 `TuiHomeNavigation` と Viewport PTY の
通常呼出しが起動・Home／Calendar・各入口・拒否／取消／復帰を引き継ぎ、
別の `--launcher` テスト実行は不要。Calendar の根拠表示・記帳の意味は維持する。
ビルド・`lake test`、Viewport／Record／Scheduled 操作／Cycle Budget／Reports／
Balances／Daily Pace／Attention／Actual PTY、既存 resource／Home scroll check で確認済み。

追加の成長表示は **実機確認待ち**：6段階の固定樹形を、現在の Actual の既知の日付数
0／1／3／7／14／30日から再構成する（過去の記録も含む）。同日件数・金額・連続日数には
依存せず、休止だけでは枯れない。置換対象を数えず、日付訂正は反映する。
保存状態・入力日時・達成度は作らない。既存 `TuiHomeNavigation` で閾値・訂正・Unknown・
数量非依存・全段階の狭小レイアウト、既存 Record PTY で確定後の成長・同日重複・取消・
再起動・他 Household セクション不変を確認。ビルド、`lake test`、Home generation、
Viewport PTY、resource check も成功（新CIなし）。残りは小さい樹形の見た目の実機確認。

| ID | 画面・範囲 | UI 改修の状態 | 残作業 / 完了の証跡 |
| --- | --- | --- | --- |
| UI-01 | Home / Calendar / Detail | 完了 | 2026-10-13：利用画像で見えた上枠の欠け／下枠の空白、狭幅での意味混在を再改修。広幅は月間 Calendar＋Detail、狭幅は連続した週ナビ＋日の内容、短い端末は1行の日付ナビ。両方収まる高さでは月集計も表示。日の収支・Actual・Scheduled・非空／Unavailable Pending は Detail に集約。固定2行ナビ＋`?` の全文ヘルプが旧4系統の常設案内・本文凡例を引き継ぐ。PgUp/Dn は選択 identity を保って全文を閲覧、j/k で選択追従に復帰。既存 `TuiHomeNavigation` / `TuiHelpFooter` と Viewport / Record PTY で独立した根拠・リサイズ・モーダル拒否・復帰を検証（新CIなし）。Day 表示はユーザーの実機確認済み。続いて z の月／年表示を整列：`Months / YYYY` の月名＋件数2行セル、`Years` の Year / Records 列、集計との控えめな区切り、凡例は `?`。選択・現在期間の下線・正確な件数と期間集計を維持し、狭幅・選択月の名前／件数の同時表示・年の範囲端を既存 Lean／Viewport PTY で検証。月／年表示もユーザーの実機確認・了承済み。Selected Day は UI-04 |
| UI-02 | Commands パレット | 一部完了 | 階層ナビは既存。ラベル・選択・余白を今回の方針で点検 |
| UI-03 | Actual 一覧・詳細・検索・移動 | 完了 | `2b347e0e`〜`b753e6c1` |
| UI-04 | Selected Day | 完了 | 控えめな丸角枠と整列、全幅のコンパクト一覧、i/Tab の折返し・スクロール可能な詳細、可視行に合った移動、固定2段ナビと予約通知行。子画面・親への復帰時にサイズ再取得。`TuiSelectedDay` を代表 TUI テストへ追加し、Unknown / Unavailable、巨大数量・複数 Measure、48×14 の通知と親への復帰、Record キャンセルの再読込なし／確定後の再読込を Lean / Viewport・Record PTY で検証。Scheduled 作成・完了／取消／置換、Merchant の共有処理と resource check も確認。子の編集・確認画面は別項目 |
| UI-05 | Record 通常入力・Locus 候補 | 完了 | `4d9d261b` |
| UI-06 | Record 確認 | 完了 | `61eb1baa` |
| UI-07 | Record / Original amount 入力 | 完了 | 入力・説明の枠、共通ラベルと末尾・IME 表示、固定2段ナビ、折返し通知。`TuiRecord` / Record PTY で検証。macOS の Ctrl-O 吸収も修正 |
| UI-08 | Record / unresolved 有効化確認 | 完了 | 語彙追加と「Movement は記録しない」の枠、固定アクション・2段ナビ・折返し通知。`TuiRecord` / Record PTY で確認・戻る・リサイズ・Actual 不変を検証 |
| UI-09 | Actual Correction 入力・確認 | 完了 | Record 共通の入力・候補・IME、固定日付と対象、選択時／置換後の符号付き Effects、固定ナビと確認スクロール・リサイズ。`TuiCorrection` / Record PTY で履歴保持・再読込・他セクション不変を検証 |
| UI-10 | Actual 日付修正 入力・確認 | 検証待ち | 元の日付・新しい日付・対象の枠内階層、編集中の強調、確認とPublishの明示、固定ナビ・通知。TuiActualDateCorrectionと関連CIで検証 |
| UI-11 | Actual reversal 入力・確認 | 検証待ち | 元のActualを保持する逆仕訳の意味、符号付き逆Posting全文とスクロール、別日付、明示的な確定・固定ナビ。TuiActualReversalとActual detail PTYで検証 |
| UI-12 | Scheduled / Series Calendar | 完了 | 既存整列は `e91c62a3`、`61c21874`。2026-10-14：当月始まりへ変更し、予定日＋`✓` で完了を区別。未完了／完了の月内存在を共有 Review で再構成し、取消・置換元・未成立の完了参照を混同しない。Plan Detail の偽の不足行を除き、補充・操作対象は current-open のまま。ビルド・`lake test`・既存 Lean／Scheduled・Viewport PTY が成功、実機もユーザー確認・了承済み |
| UI-13 | Scheduled / Plan Detail | 完了 | `eb1cfa91`、`61c21874` |
| UI-14 | Scheduled / Months | 完了 | `8d0f0582` |
| UI-15 | Scheduled / List | 完了 | `33f8ef59` |
| UI-16 | Scheduled 作成 入力・確認 | 一部完了 | PR #1886・#1887で確認全文・スクロール・安定入力、PR #1924で通常新規作成を共通フローティング枠へ移行（Scheduled List／Selected Day、狭小端末フォールバック）。作成後のExpected pace選択と正データ再読込は従来の独立処理を維持。将来分のScheduledを自動作成しない。CI通過・マージ済み。残りは実機での見た目と操作感の仕上げ |
| UI-17 | Scheduled 完了 入力・確認 | 検証待ち | PR #1926マージ済み：Scheduled List／Selected Dayの完了Actual入力・確認を共通フローティング枠へ。元Plan ID・予定期日を保持し、Actual日付・説明・Postingは独立して編集。狭小端末のPublish拒否、ライブリサイズ、Esc時の正データ不変をLean／実PTYで確認しCI成功。完了後の次予定・Attention処理は別のまま。残りは実機での見た目・操作感の確認 |
| UI-18 | Scheduled 取消確認 | 検証待ち | PR #1914マージ済み：共通フローティング枠と狭小端末フォールバック、対象ID・日付／期待Posting、Keep／Cancel、確定拒否、ライブリサイズに対応。`TuiScheduledTerminal`と専用実PTYで取消／Esc不変を検証しCI成功。残りは実機での見た目・操作感の確認 |
| UI-19 | Scheduled 置換 入力・確認 | 一部完了 | PR #1920で置換入力・確認のLocus／端末サイズ対応を改修、PR #1922で共通フローティング枠へ移行（Scheduled List／Selected Day）。元予定・置換内容、Preview／Esc／リサイズを専用実PTY・Leanで確認しCI成功。置換発行の独立した意味を保持。残りは実機での見た目・細部の仕上げと受理済み書込の専用PTY確認（#1902） |
| UI-20 | Scheduled 一括金額編集・チェックリスト・確認 | 未着手 | 一覧の整列、選択追従、変更対象と結果、ナビ |
| UI-21 | Scheduled 生成 入力・確認 | 未着手 | 入力と生成対象、確認一覧、ナビ |
| UI-22 | Scheduled 継続の操作画面 | 未着手 | 対象・次の内容、確認、ナビ |
| UI-23 | Scheduled coverage 設定 | 検証待ち | 既存 Plan Monitoring の5段階ペース選択を、作成後 Expected pace と同じスクロール・丸角パネルに整列。選択追従、短い端末とライブリサイズ、予約通知欄、Esc／保存の既存意味を維持。`TuiScheduledCreate` で画面幅・高さ・選択の検証を追加。CI／実機の見た目は確認待ち |
| UI-24 | Balances / Current | 完了 | 控えめな丸角枠、Locus × Measure・符号付き quanta・根拠状態の整列、選択追従、折返し・スクロール可能な詳細、固定2段ナビと予約通知行。巨大数量は不完全な桁ではなく詳細へ誘導。Print は全選択の完全な値と既存の行／UTF-8 byte 制限・明示同意を保持。`TuiBalances` を代表 TUI テストへ、合成 Balances PTY を両 CI tier へ追加。build、代表 TUI、CurrentBalanceReview、ナビ・tall display、Balances／Viewport／Record／Cycle Budget PTY、resource check を検証。巨大数量・長い識別子・日本語通知・複数 Measure・空選択・各根拠状態と、親へのリサイズ復帰・Print 同意／取消／拒否・fixture 不変を確認。Reports / Balances と Print の補助画面 UI は別項目 |
| UI-25 | 非予算 Reports / メニュー・各表示・期間指定・比較 | 未着手 | 下の子画面一覧に沿って、枠・期間・列・詳細・ナビを統一 |
| UI-26 | Attention 一覧・詳細・Add / Resolve / Drop | 完了 | 控えめな丸角枠と due／文脈の整列、可視行に合った選択・ページと全文詳細、Add の入力末尾・due 選択・日付入力、対象 ID／日付を固定した Resolve／Drop 確認、固定2段ナビと折返し通知。Unavailable／empty と3つの due 意味、既存の発行キーと共有 Publisher／成功時の再読込を維持。代表 Lean と専用の合成 Attention PTY を両 CI tier へ追加。build（standalone Attention 含む）、代表 TUI／Attention persistence・Household adapter、Scheduled continuation、Home 世代、ナビ・tall display、Attention／Viewport／Record／Cycle Budget PTY、resource check を検証。全文・IME／paste・全モードのリサイズ、取消／日付拒否の不変、各 due・Resolve／Drop、共有再検証による stale 対象の拒否、他 family・設定・legacy の不変と正規 recovery backup を確認 |
| UI-27 | Settlements 一覧・詳細 | 未着手 | 数量と状態の整列、詳細の階層、スクロール・ナビ |
| UI-28 | Settlement 操作・確認 | 未着手 | 対象・実行内容、入力・確認、ナビ |
| UI-29 | Exchange 入力・確認 | 未着手 | Measure 別の数量、入力・確認の階層、ナビ |
| UI-30 | Manage Loci 一覧・追加 | 未着手 | トークンと説明の配置、入力・確認、ナビ |
| UI-31 | Observe quantities 入力・確認 | 未着手 | Locus / Measure / 数量の行、フォーカス追従、確認・ナビ |
| UI-32 | Print / 補助表示 | 未着手 | 現行の出力・補助画面を着手時に分割し、読みやすさを整える |
| UI-33 | Daily Pace / Trend 本画面 | 完了 | 控えめな丸角枠、既存 Braille グラフと選択追従する履歴、数量／変化・範囲・再構成の説明を読める詳細、固定2段ナビと予約フィードバック行。48×14 でも選択日・数量・変化・グラフを保持。全文・巨大数量・日本語原因は詳細でスクロールし、ReadState／Measure と既存の計算を保持。極端な値は描画のみ保留し、数量を欠落／ゼロにしない。`TuiDailyPaceTrend` と合成 Daily Pace PTY を両 CI tier へ追加。build、代表 TUI、TuiScheduled／CycleSpendingPaceReview、Home 世代、ナビ・tall display、Daily Pace／Balances／Viewport／Record PTY、resource check を検証。計算・訂正／完了を含む再構成、fixture 不変を確認。支援設定・補助画面は別範囲 |

### UI-25：Reports の子画面

機能の追加ではなく、既存の表示を整える項目。

- [ ] メニュー
- [ ] 期間指定・比較条件の入力
- [ ] Income & Expense：Summary / Monthly / Daily / 比較
- [ ] Transactions Flow
- [ ] Stock–Flow / 比較
- [ ] Multimeasure Spend
- [ ] Reports / Balances
- [ ] Locus Trend Compare
- [ ] Liquidity / 条件入力・表示

### 対象外・対象確認

- **今回対象外**：Budget / current cycle、Capacity、Cycle Grant、
  Actual / Scheduled の Purpose routing、Reports の Budget Window。
  既存機能やデータは削除しない。
- **Daily Pace**：既存の Trend 本画面だけを UI-33 として対象に追加。
  `daily-pace.tsv`・期間設定・支援設定／補助画面はこの完了範囲に含めず、
  計算・履歴再構成・設定内容は変更しない。

## 進める順序

基本の順序。ユーザーの希望や画面を触った結果に合わせて変更する。
一度に原則1項目を進め、機能追加や別の監査へ脱線しない。

1. **Record の残り**：UI-07、UI-08。
2. **Actual の操作画面**：UI-09〜UI-11。
3. **日常の閲覧画面**：UI-04、UI-24。
4. **Scheduled の操作画面**：UI-16〜UI-23。
5. **残りの非予算画面**：Home / Commands、Reports、Attention、
   Settlements、Exchange、設定・補助表示。

現在、**UI-26：Attention は完了。今回の UI 改修はここで一区切り**。Home・Selected Day・Balances・Daily Pace・Attention の日常利用画面を整えた。ユーザーの希望により、未完了の画面・支援設定・予算 UI へは続けて着手しない。

2026-10-11：ユーザーの再開希望により、未完了の非予算画面を一画面ずつ仕上げる作業を再開。UI-23 Plan Monitoring の可視範囲・リサイズ対応から再開した。

## 各改修で更新すること

1. 着手する ID と画面範囲を明記し、状態を更新する。
2. 枠・整列・余白・情報階層、フォーカス、可視範囲、下部ナビ・通知を整える。
3. 日本語・長文・巨大な数量・複数 Measure・空／不明／読込失敗を、
   その画面に必要な範囲で確認する。
4. 関連 Lean / 合成 PTY テストで、既存の操作・キャンセル・確定・再読込を守る。
5. `docs/TUI.md` とこの表を更新して commit し、完了行に証跡を残す。

追加で見つけた UI の不揃いは対象行の残作業へ追記する。
機能不足・運用手順・データの問題は、この表とは別の相談として扱う。
