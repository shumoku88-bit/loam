# 非予算 TUI：画面別 UI 改修の進捗

## この一覧で管理すること

**既存機能の UI を、今の方向に整えたかどうかだけを管理する。**
機能追加のロードマップ、試用開始の条件、予算設定なしでの動作監査、
バックアップ整備は、この UI 改修キューに混ぜない。

共通方針：控えめな色、細い丸角の枠、整列と余白、情報の優先順位、
見える範囲に合ったフォーカス・スクロール、安定した下部ナビと通知。
機能・記録・修正・確定の意味は変えない。
画面の現行契約は [TUI.md](TUI.md) を参照する。

- **完了**：明記した画面の UI 改修と関連テストが完了。
- **一部完了**：既存の UI 改善はあるが、今回の方針で揃える作業が残る。
- **未着手**：今回の UI 統一に未着手。機能が未実装という意味ではない。
- 作業時は **作業中 → 検証待ち → 完了** に更新する。
- 完了した画面と未完了の補助画面をまとめて「全体完了」にしない。

初版のコード基準：`4d9d261b`。下表は画面群を含む初版であり、着手時に
子画面を確認して分割・追記する。項目数から機能の完成率を計算しない。

## 画面別の進捗

| ID | 画面・範囲 | UI 改修の状態 | 残作業 / 完了の証跡 |
| --- | --- | --- | --- |
| UI-01 | Home / Calendar / Detail | 完了 | 控えめな丸角枠、2行の文脈、符号付き quanta の整列・折返し、フォーカス追従／手動スクロール、枠内の可視範囲、予約通知行と固定ナビ。`TuiHomeNavigation` / `TuiHelpFooter`、代表 TUI テスト、Home 世代・DateJump、Viewport / Record PTY、合成データでの resource check を検証。Selected Day は UI-04 として別作業 |
| UI-02 | Commands パレット | 一部完了 | 階層ナビは既存。ラベル・選択・余白を今回の方針で点検 |
| UI-03 | Actual 一覧・詳細・検索・移動 | 完了 | `2b347e0e`〜`b753e6c1` |
| UI-04 | Selected Day | 完了 | 控えめな丸角枠と整列、全幅のコンパクト一覧、i/Tab の折返し・スクロール可能な詳細、可視行に合った移動、固定2段ナビと予約通知行。子画面・親への復帰時にサイズ再取得。`TuiSelectedDay` を代表 TUI テストへ追加し、Unknown / Unavailable、巨大数量・複数 Measure、48×14 の通知と親への復帰、Record キャンセルの再読込なし／確定後の再読込を Lean / Viewport・Record PTY で検証。Scheduled 作成・完了／取消／置換、Merchant の共有処理と resource check も確認。子の編集・確認画面は別項目 |
| UI-05 | Record 通常入力・Locus 候補 | 完了 | `4d9d261b` |
| UI-06 | Record 確認 | 完了 | `61eb1baa` |
| UI-07 | Record / Original amount 入力 | 完了 | 入力・説明の枠、共通ラベルと末尾・IME 表示、固定2段ナビ、折返し通知。`TuiRecord` / Record PTY で検証。macOS の Ctrl-O 吸収も修正 |
| UI-08 | Record / unresolved 有効化確認 | 完了 | 語彙追加と「Movement は記録しない」の枠、固定アクション・2段ナビ・折返し通知。`TuiRecord` / Record PTY で確認・戻る・リサイズ・Actual 不変を検証 |
| UI-09 | Actual Correction 入力・確認 | 完了 | Record 共通の入力・候補・IME、固定日付と対象、選択時／置換後の符号付き Effects、固定ナビと確認スクロール・リサイズ。`TuiCorrection` / Record PTY で履歴保持・再読込・他セクション不変を検証 |
| UI-10 | Actual 日付修正 入力・確認 | 未着手 | 元の日付・新しい日付、対象、確定アクションの階層 |
| UI-11 | Actual reversal 入力・確認 | 未着手 | 対象・結果の表示、確認アクション、ナビ |
| UI-12 | Scheduled / Series Calendar | 完了 | `e91c62a3`、`61c21874` |
| UI-13 | Scheduled / Plan Detail | 完了 | `eb1cfa91`、`61c21874` |
| UI-14 | Scheduled / Months | 完了 | `8d0f0582` |
| UI-15 | Scheduled / List | 完了 | `33f8ef59` |
| UI-16 | Scheduled 作成 入力・確認 | 未着手 | フィールド、候補、符号付き数量、確認・ナビ |
| UI-17 | Scheduled 完了 入力・確認 | 未着手 | 予定の対象と記録する Actual を読み分けられる配置 |
| UI-18 | Scheduled 取消確認 | 未着手 | 対象・結果・確認アクションの階層 |
| UI-19 | Scheduled 置換 入力・確認 | 未着手 | 元の予定と置換内容、数量、確認・ナビ |
| UI-20 | Scheduled 一括金額編集・チェックリスト・確認 | 未着手 | 一覧の整列、選択追従、変更対象と結果、ナビ |
| UI-21 | Scheduled 生成 入力・確認 | 未着手 | 入力と生成対象、確認一覧、ナビ |
| UI-22 | Scheduled 継続の操作画面 | 未着手 | 対象・次の内容、確認、ナビ |
| UI-23 | Scheduled coverage 設定 | 未着手 | 設定欄、ラベル、監視と実予定の違いが分かる説明 |
| UI-24 | Balances / Current | 完了 | 控えめな丸角枠、Locus × Measure・符号付き quanta・根拠状態の整列、選択追従、折返し・スクロール可能な詳細、固定2段ナビと予約通知行。巨大数量は不完全な桁ではなく詳細へ誘導。Print は全選択の完全な値と既存の行／UTF-8 byte 制限・明示同意を保持。`TuiBalances` を代表 TUI テストへ、合成 Balances PTY を両 CI tier へ追加。build、代表 TUI、CurrentBalanceReview、ナビ・tall display、Balances／Viewport／Record／Cycle Budget PTY、resource check を検証。巨大数量・長い識別子・日本語通知・複数 Measure・空選択・各根拠状態と、親へのリサイズ復帰・Print 同意／取消／拒否・fixture 不変を確認。Reports / Balances と Print の補助画面 UI は別項目 |
| UI-25 | 非予算 Reports / メニュー・各表示・期間指定・比較 | 未着手 | 下の子画面一覧に沿って、枠・期間・列・詳細・ナビを統一 |
| UI-26 | Attention 一覧・詳細・Add / Resolve / Drop | 未着手 | 一覧と期日の整列、入力・確認、フォーカス・ナビ |
| UI-27 | Settlements 一覧・詳細 | 未着手 | 数量と状態の整列、詳細の階層、スクロール・ナビ |
| UI-28 | Settlement 操作・確認 | 未着手 | 対象・実行内容、入力・確認、ナビ |
| UI-29 | Exchange 入力・確認 | 未着手 | Measure 別の数量、入力・確認の階層、ナビ |
| UI-30 | Manage Loci 一覧・追加 | 未着手 | トークンと説明の配置、入力・確認、ナビ |
| UI-31 | Observe quantities 入力・確認 | 未着手 | Locus / Measure / 数量の行、フォーカス追従、確認・ナビ |
| UI-32 | Print / 補助表示 | 未着手 | 現行の出力・補助画面を着手時に分割し、読みやすさを整える |

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
- **対象確認**：Daily Pace とその支援設定・補助画面。
  非予算の UI 改修に含める範囲を確認してから一覧に追加する。

## 進める順序

基本の順序。ユーザーの希望や画面を触った結果に合わせて変更する。
一度に原則1項目を進め、機能追加や別の監査へ脱線しない。

1. **Record の残り**：UI-07、UI-08。
2. **Actual の操作画面**：UI-09〜UI-11。
3. **日常の閲覧画面**：UI-04、UI-24。
4. **Scheduled の操作画面**：UI-16〜UI-23。
5. **残りの非予算画面**：Home / Commands、Reports、Attention、
   Settlements、Exchange、設定・補助表示。

現在、**UI-01・UI-04・UI-24 の日常閲覧 UI は完了**。UI-01・UI-04 と同じ方針で日常の使用頻度を優先して進める。次の候補は Daily Pace の既存画面（範囲確認後に追加）、続いてよく使う Scheduled の操作画面。予算 UI は引き続き対象外。

## 各改修で更新すること

1. 着手する ID と画面範囲を明記し、状態を更新する。
2. 枠・整列・余白・情報階層、フォーカス、可視範囲、下部ナビ・通知を整える。
3. 日本語・長文・巨大な数量・複数 Measure・空／不明／読込失敗を、
   その画面に必要な範囲で確認する。
4. 関連 Lean / 合成 PTY テストで、既存の操作・キャンセル・確定・再読込を守る。
5. `docs/TUI.md` とこの表を更新して commit し、完了行に証跡を残す。

追加で見つけた UI の不揃いは対象行の残作業へ追記する。
機能不足・運用手順・データの問題は、この表とは別の相談として扱う。
