# LOAM プロダクトコード重複・共有化 精密調査レポート
**〜 探索的足場の蒸留とインクリメンタルなスリム化に向けた技術監査 〜**

- **初期調査ベースライン**: `#1454`（プロダクト/ランタイムコード中心）
- **repository-wide census ベースライン**: `599fe036eeafff6362bf3d8dfb0adb994a9b53e2`（`research: close history distillation Phase 1 (#1539)`）
- **計画対象**: production code に加え、tests / CI / tools / docs / executable research / formal models / visual audit assets / build configuration を owner 別に棚卸し
- **調査日**: 2026-09-28

---

## 1. エグゼクティブサマリー

初期監査の `#1454` 時点では、LOAM の主要ドメインとして「確定事実（Actual）」「予定（Scheduled）」「予算（Capacity）」「決済・消滅（Settlement）」が揃い、第二次蒸留の候補を探すための有用なスナップショットが得られました。これは最終完成や現在の規模を主張するものではなく、以後の変更を踏まえて再検証する探索用ベースラインです。

一方で、1,450 回に及ぶ暗闇の探索プロセスを経てきたため、コードベースには **「新概念を発見するたびに個別に建て増しされた足場」** や **「同一パターンの並列実装」** が大量に残存しています。

### 初期監査メトリクス（#1454、現況値ではない）
* **#1454 時点のプロダクトコード規模**: **275 ファイル / 49,343 行**（実コード: 約 41,600 行）
* **当時の重複・冗長コード推定**: **約 18,000〜21,000 行（全体の約 40〜43%）**
* **当時の共有化後到達規模の仮説**: **約 120〜140 ファイル / 28,000〜30,000 行**

これらは削減目標ではなく、最新 `main` で correspondence ごとに再検証する仮説である。
Phase 2 の実地再検証（#1543 / #1545 / #1546）により、#1454 の削減量予測は
**定量予測としては失効**した。以後は当時の数値を削減期待値として使用せず、
候補発見のための historical baseline としてのみ扱う。

```
【プロダクトコードの削減・共有化ポテンシャル】
現在: 49,343 行 (275 ファイル)
  ├── 削減可能（重複・ボイラープレート）: 19,500 行 (約 40%)
  └── 蒸留後に残る本質的コード:          29,800 行 (約 60%)
```

---

## 2. クラスタ別：現状規模と削減ポテンシャル

| レイヤー / クラスタ | 現在ファイル数 | 現在行数 | 共有化後予測行数 | 削減見込み行数 | 主な重複の性格 |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **A. TUI 層 (画面・セッション)** | 80 | 17,679 | 9,500 | **-8,100 行 (-46%)** | 画面ごとのステートマシン、入力フォーム、ループ処理の並列実装 |
| **B. Reviews 層 (分析・レポート)** | 30 | 6,613 | 3,400 | **-3,200 行 (-48%)** | 残高・トレンド・フローにおける集計ループと Snapshot 定義の重複 |
| **C. Publishers 層 (データ出版)** | 20 | 3,111 | 1,300 | **-1,800 行 (-58%)** | アトミック書き込み・ステージング・バリデーションのボイラープレート |
| **D. Application 層 (Frontiers)** | 23 | 5,463 | 3,600 | **-1,800 行 (-33%)** | 類似した DAG グラフ探索、中間アダプター構造体の多段リレー |
| **E. Persistence 層 (永続化)** | 19 | 3,141 | 2,200 | **-900 行 (-29%)** | バージョン付き行パース・フォーマットの反復 |
| **F. Core ドメイン (代数核)** | 38 | 4,743 | 4,200 | **-500 行 (-10%)** | 数学核のため大幅な圧縮は行わず、健全性維持を最優先 |
| **G. その他 (CLI・モデル・補助)** | 65 | 8,593 | 5,000 | **-3,500 行 (-41%)** | 未使用コマンド、古い互換ラッパーの整理 |
| **合計** | **275** | **49,343** | **29,200** | **約 -20,100 行 (-41%)** | |

---

## 3. 領域別の精密重複分析と共有化プラン

### 領域 A：TUI 層（最大級の重複の宝庫：約 8,100 行削減可能）

TUI は全体の約 35% を占める最大コンポーネントですが、中身を精査すると **「4つの主要画面群で、同一のUI遷移コードが丸ごとコピペに近い形で反復されている」** ことが判明しました。

#### 1. セッションループの重複（24 ファイル / 2,694 行）
* **現状**:
  * 直近で [`Loam/Tui/EditorSession.lean`](file:///Users/user/Projects/moko/loam/Loam/Tui/EditorSession.lean)（51行）という共通ループ（`runUntilPublished`）が導入され、[`SettlementActionSession.lean`](file:///Users/user/Projects/moko/loam/Loam/Tui/SettlementActionSession.lean) など一部で採用されました。
  * しかし、依然として [`RecordSession.lean`](file:///Users/user/Projects/moko/loam/Loam/Tui/RecordSession.lean) (72行)、[`CapacitySession.lean`](file:///Users/user/Projects/moko/loam/Loam/Tui/CapacitySession.lean) (108行)、[`ScheduledWorkspaceSession.lean`](file:///Users/user/Projects/moko/loam/Loam/Tui/ScheduledWorkspaceSession.lean) (238行)、[`SelectedDaySession.lean`](file:///Users/user/Projects/moko/loam/Loam/Tui/SelectedDaySession.lean) (423行) など、**15以上のセッションが自前で `readKey` → `update` → `emitDirtyDiff` の再帰ループを手書き** しています。
* **共有化プラン**:
  * 全セッションを `EditorSession`（または汎用 `TuiSession.run`）に統一。
  * **削減効果**: セッション層だけで **約 1,200 行削減**。

#### 2. 画面内ステートマシン（選択・入力・プレビュー）の反復（約 6,900 行削減）
* **現状**:
  * [`SettlementAction.lean`](file:///Users/user/Projects/moko/loam/Loam/Tui/SettlementAction.lean) (820行)
  * [`CapacityRebalance.lean`](file:///Users/user/Projects/moko/loam/Loam/Tui/CapacityRebalance.lean) (343行)
  * [`CapacityTransfer.lean`](file:///Users/user/Projects/moko/loam/Loam/Tui/CapacityTransfer.lean) (335行)
  * [`ScheduledCreation.lean`](file:///Users/user/Projects/moko/loam/Loam/Tui/ScheduledCreation.lean) (308行)
  * [`ScheduledReplacement.lean`](file:///Users/user/Projects/moko/loam/Loam/Tui/ScheduledReplacement.lean) (264行)
  これらはすべて以下の同一パターンを持っています：
  1. `choice : Nat` によるメニューの上下選択
  2. `input : String` による金額/日付の 1 文字ずつのタイピングとバックスペース処理
  3. `preview : Mode` による確認画面の表示と Enter での確定（`confirm`）
* **共有化プラン**:
  * **`Loam.Tui.Form`**: 数値・日付・テキストの 1 行入力コンポーネント（カーソル・BS・バリデーション内蔵）。
  * **`Loam.Tui.Selector`**: リストのカーソル上下選択・スクロール・ページング部品。
  * 各画面は「入力したいフィールドの定義（Label, Type, Validator）」を渡すだけの宣言的 UI に移行。
  * **削減効果**: 各ファイルが 300〜800 行から 80〜150 行に激減し、**約 6,900 行削減**。

---

### 領域 B：Reviews 層（30 ファイル / 6,613 行 → 約 3,200 行削減可能）

Review（集計・照会・レポート）層には、明確な **「3大ファミリー重複」** が存在します。

#### 1. 残高レビューの 5 重重複（計 1,672 行 → 約 500 行へ統合）
* [`BalanceReview.lean`](file:///Users/user/Projects/moko/loam/Loam/BalanceReview.lean) (189行)
* [`CurrentBalanceReview.lean`](file:///Users/user/Projects/moko/loam/Loam/CurrentBalanceReview.lean) (337行)
* [`HistoricalBalanceReview.lean`](file:///Users/user/Projects/moko/loam/Loam/HistoricalBalanceReview.lean) (367行)
* [`RoleBalanceReview.lean`](file:///Users/user/Projects/moko/loam/Loam/RoleBalanceReview.lean) (580行)
* [`ConditionalBalancePathReview.lean`](file:///Users/user/Projects/moko/loam/Loam/ConditionalBalancePathReview.lean) (229行)
* **分析**:
  本質的な計算は「フロンティアから確定した Event 列を取り出し、`EffectCoordinate` ごとに Quanta を合算する」という同一の畳み込み（fold）です。
  違いは「ゼロオリジン検証（Coverage）を要求するか」「アンカー証拠を当てるか」「ロール階層でグループ化するか」というフィルタ条件の差だけです。
* **共有化プラン**:
  * 共通の集計エンジン `Loam.Review.BalanceEngine` を 1 つ作り、各ビューはフィルタ述語（Predicate）とグルーピング関数を渡す形に統合。
  * **削減効果**: **約 1,150 行削減**。

#### 2. トレンド・期間比較の 3 重重複（計 873 行 → 約 300 行へ統合）
* [`LocusTrendReview.lean`](file:///Users/user/Projects/moko/loam/Loam/LocusTrendReview.lean) (318行)
* [`LocusTrendCompareReview.lean`](file:///Users/user/Projects/moko/loam/Loam/LocusTrendCompareReview.lean) (445行)
* [`PeriodComparisonReview.lean`](file:///Users/user/Projects/moko/loam/Loam/PeriodComparisonReview.lean) (110行)
* **共有化プラン**:
  * 「期間区間（当日、直近7日、前月同期間など）」でバケット分けして比較するロジックを汎用化。
  * **削減効果**: **約 570 行削減**。

#### 3. フロー集計の 3 重重複（計 742 行 → 約 300 行へ統合）
* [`StockFlowReview.lean`](file:///Users/user/Projects/moko/loam/Loam/StockFlowReview.lean) (273行)
* [`RoleFlowReview.lean`](file:///Users/user/Projects/moko/loam/Loam/RoleFlowReview.lean) (146行)
* [`TransactionsFlowReview.lean`](file:///Users/user/Projects/moko/loam/Loam/TransactionsFlowReview.lean) (323行)
* **共有化プラン**:
  * 資産（Stock）と移動（Flow）のマトリクス計算パイプラインを一元化。
  * **削減効果**: **約 440 行削減**。

---

### 領域 C：Publishers 層（20 ファイル / 3,111 行 → 約 1,300 行へ統合）

20 個ある `*Publisher.lean` は、驚くほど構造が一致しています。

* **反復されているボイラープレート**:
  1. ドラフトを受け取る。
  2. 権限ルート（`LOAM_DATA_DIR`）からファイルを読み込み、`admit` 関数でバリデーション。
  3. 新しいレコードを行フォーマットに変換。
  4. Sibling 一時ファイルにステージング書き込み。
  5. アトミックにファイルを置換（`IO.FS.rename`）。
  6. 成功メッセージまたは EventId を返す。
* **共有化プラン**:
  * **`Loam.Persistence.AtomicPublisher`**（共通出版エンジン、約 150 行）を新設。
  * 各 Publisher は「対象ファイルパス」「バリデータ（Admission）」「行エンコーダ」を提供するだけの 30〜50 行の薄い宣言に圧縮。
  * **削減効果**: 20 ファイル中、共通化により **約 1,800 行（約 58%）削減**。

---

### 領域 D：Application 層（Frontiers / Inspections: 23 ファイル / 5,463 行）

* **現状の足場コード**:
  * [`ReplacementFrontier.lean`](file:///Users/user/Projects/moko/loam/Loam/Application/ReplacementFrontier.lean) (494行) が汎用的な有向置換グラフの解決を提供しているにもかかわらず、
  * [`CorrectionFrontierIndexed.lean`](file:///Users/user/Projects/moko/loam/Loam/Application/CorrectionFrontierIndexed.lean) (1,075行) や [`SettlementFrontier.lean`](file:///Users/user/Projects/moko/loam/Loam/Application/SettlementFrontier.lean) (696行) が、それぞれ独自にインデックス付き探索や検証ループを肥大化させています。
* **共有化プラン**:
  * `ReplacementFrontier` への委譲比率を高め、ドメイン固有の判定条件だけをインジェクションする。
  * 探索期に安全確認のために挟まれていた多段アダプター構造体をバイパス。
  * **削減効果**: **約 1,800 行削減**。

---

## 4. 第二次蒸留の実行原則

この文書の数値は **#1454 時点の重複監査から得た探索用のベースライン** であり、削減ノルマではない。
repository-wide census は `599fe036eeafff6362bf3d8dfb0adb994a9b53e2`
（`research: close history distillation Phase 1 (#1539)`）を基準に実施し、Phase 1 は閉じた。
以後の実装判断では、その時点の最新 `main` で reachability・ownership・equivalence を再確認する。

したがって第二次蒸留では、「30,000 行にする」「40% 削る」といった量的目標を置かない。
成功条件は次の不変条件を保ったまま、同じ意味をより少ない機構で表現できることである。

```text
同じ意味論
同じ canonical data
同じ利用者向け操作
同じ観測結果
同じ安全性・回復可能性
        +
より少ない重複・足場・偶発的複雑性
```

削除行数は結果として計測する。削減のために意味境界を壊さない。

### 回帰防止の防壁

各段階は、単体テストだけでなく、次の複数の観測面で旧経路と新経路を照合する。

1. **実データ回帰**: 日常運用の canonical data（特に `actual.loam`）に対する主要レポート・残高・フロー結果が不変であること。
2. **決定論的シナリオ**: Actual mutation、Settlement lifecycle、Scheduled recovery など、固定された複数ステップ履歴の最終状態と中間観測が不変であること。
3. **既存の Lean / Alloy / TLA+ 資産**: その変更が守るべき意味論に対応する既存の証明・モデル・qualification を維持すること。
4. **TUI 回帰**: PTY / snapshot / interaction tests により、キー操作・キャンセル・再描画・publication error からの復帰を維持すること。

決定論的シナリオは fuzzing の代用品ではない。ここでの役割は、**既知の重要な履歴を固定し、リファクタリング前後の意味差分を検出する受け入れテスト**である。

---

## 5. フェーズ 1：研究室の卒業と本体境界の明確化

research/history distillation は #1539 で完了した。以下は Phase 1 で用いた卒業判定を、今後の targeted cleanup を再評価する際の reopening rule として残す。

### 原則

研究資産を `archive/` に移して main の中に保存し続けることは原則としない。
Git の履歴そのものを長期 archive とみなし、研究から production に昇格した意味が次のいずれかに残っている場合、
役目を終えた実験・観測・作業文書は main から削除できる。

- production code
- regression test / deterministic scenario
- theorem / proof
- Alloy / TLA+ など、現在も独立に価値を持つ検証モデル
- 短い設計文書や provenance が、将来の判断に実際に必要な場合

### 卒業判定

各研究資産について次を確認する。

```text
研究上の問い
   ↓
production に意味が入ったか？
   ↓
回帰防止の witness が残ったか？
   ↓
元の探索資料なしで設計判断を説明できるか？
   ↓
yes → main から卒業可能
no  → 必要な知識だけ先に蒸留
```

### Phase 1 の完了条件

- `experiments/`、`observations/`、`Loam/Observations/` などが「過去を保存するためだけ」の倉庫になっていない。
- production / validation / research の境界が明示できる。
- 残す研究資産には「なぜ現在も executable / explanatory value があるか」を説明できる。
- Phase 2 以降の重複監査は、蒸留後の最新 `main` で再計測する。

---

## 6. フェーズ 1.5：repository-wide surface census

Phase 1 の research/history distillation は PR #1539 で閉じた。
次の production consolidation を始める前に、最新 main
`599fe036eeafff6362bf3d8dfb0adb994a9b53e2` の recursive Git tree を基準に、
リポジトリ全体を owner ごとに棚卸しした。

### 現在の物理 surface

```text
repository total     1,318 files / 9,149,737 bytes

Loam/                  545 files
  production-facing*   306 files
  Tests                145 files
  Observations          86 files
  Examples                8 files

docs/                  196 files
  research             150 files
  drakon                16 files
  d2                    12 files
  direct                14 files
  other                  4 files

experiments/           279 files
model/                  32 files
observations/           50 files
tla/                   101 files
verification/           29 files
tools/                  20 files
tests/                   4 files
.github/                51 YAML files
```

`production-facing*` は `Loam/` 直下、Application、Cli、Core、Persistence、
Presentation、Tui の合計で、`Loam/Tests`、`Loam/Observations`、
`Loam/Examples` を除く。root の `Loam.lean` は別の umbrella entrance である。

`.github/` の 51 YAML は、現行 `CI_OBLIGATION_MAP.md` が説明する
**47 workflow + 4 composite action** と一致する。

### owner 別の初期分類

| Surface | Census verdict | 第二次蒸留での扱い |
| --- | --- | --- |
| production-facing Lean | **RE-AUDIT / #1515 PRIMARY** | 最新 main で重複と reachability を再計測し、1 correspondence ずつ圧縮 |
| tests (`Loam/Tests`, `tests/`) | **LIVE WITNESS** | 対応 owner が退役した時だけ削除。テスト数そのものを目標にしない |
| `docs/research/` | **KEEP-DOMINANT / PHASE 1 CLOSED** | broad deletion mining を再開しない。後続 owner が意味を完全に吸収した時だけ再検討 |
| `Loam/Observations`, `experiments`, `model`, `tla` | **MIXED WITNESS / HISTORY** | CI manifest、selected umbrella、独立 counterexample、future semantics を照合して個別判断 |
| `verification/` | **LIVE QUALIFICATION INFRASTRUCTURE** | solver / Lean case manifest と runner の owner。対応 witness の卒業時だけ縮小 |
| `.github/` | **LIVE CONTROL SURFACE** | 既に 97 workflows から統合済み。owner/equivalence が証明された workflow だけ統合・退役 |
| `tools/` | **CURRENT / REACHABLE** | 20本すべてが CI、AI workbench、audit/research から参照。現時点で孤立ツールなし |
| `docs/drakon`, `docs/d2` | **CURRENT VISUAL AUDIT INSTRUMENTS** | family 一括削除なし。完了済み audit 専用 builder/golden artifact は owner 終了後に個別監査 |
| root/direct docs | **TARGETED DOC CENSUS** | current entrance / durable provenance / superseded audit を区別し、historical residue のみ卒業 |
| build config | **CURRENT** | Lake/toolchain/repository operation に必要。通常の削減対象にしない |

### Phase 1.5 で見つかった具体的な documentation pressure

root は `docs/research/README.md` により、原則として次の入口へ小さく保つ方針である。

```text
README.md
AGENTS.md
DESIGN_PHILOSOPHY.md
OBSERVATION_MAP.md
```

targeted documentation cleanup は owner ごとに進める。

- `SEMANTIC_GAP_AUDIT.md` は、自身が historical audit evidence と明記し、
  current reference を持たず、surviving meaning が production code・regression・
  後続 audit に吸収されたため、ownership retirement PR #1540 を切った。
- `RAW_ADMITTED_AUDIT.md` も current reference を持たず、旧 type inventory は
  後続 hardening / read-image promotion より前のものだった。surviving responsibilities は
  proof-carrying production types、current theorems、falsification assets、および
  `docs/research/ADMITTED_TYPE_INTEGRITY_AUDIT_2026-09-19.md` に移ったため、
  ownership retirement の対象とした。

`docs/movement_manifest_menu_cutover.md` は旧 no-argument shell-menu / manifest authority
cutover の historical note であり、旧 manifest 識別子には current code owner が残っていなかった。
current entrance semantics は `README.md` / `docs/TUI.md` が所有し、cutover provenance は
Git history で十分なため、README の durable provenance を短く蒸留した上で ownership retirement
の対象とした。

### CI / tools / visual assets の census 結論

現時点では broad deletion を開始しない。

- 20本の `tools/` はすべて current workflow / workbench / audit / research から参照される。
- DRAKON は `docs/AI_WORKBENCH.md` の current execution/refusal instrument であり、
  module-granularity CI も一部 builder / golden artifact を直接使用する。
- D2 は current ownership/topology instrument であり、一部 projection は Alloy manifest や
  module-granularity CI から参照される。
- CI は `docs/CI_OBLIGATION_MAP.md` により意図的 control surface として分類され、
  solver-family workflow はすでに manifests へ大幅統合されている。

したがって、この領域は **owner retirement / exact equivalence / unreachable evidence**
のいずれかが示された時だけ縮小する。

### Phase 1.5 の停止条件

repository-wide census は、全ファイルを一度に KEEP/DELETE 判定する作業ではない。
次を達成した時点で完了とする。

```text
全 top-level surface に owner class がある
+
#1515 が production 以外の削減トラックを見落とさない
+
broad-delete してはいけない witness/control surface が明示される
+
具体的な targeted cleanup 候補だけが残る
```

この条件は census baseline で満たされた。
以後は repository-wide scope を維持しつつ、PR は引き続き **1 semantic correspondence**
または **1 ownership retirement** を単位とする。

---

## 7. フェーズ 2：TUI の機械的パターンを小さな部品へ畳む

TUI は最大の重複候補だが、**画面の意味を一つの巨大な汎用ステートマシンへ押し込まない**。

すでに `Loam/Tui/EditorSession.lean` の `runUntilPublished` が、
「read key → update → redraw → publish → publication refusal なら同じ editor state に戻る」
という共通 shell を production で実証しており、`SettlementActionSession` が利用している。

一方、`RecordSession` には似た terminal loop が手書きで残っている。
これは共有化候補である。

ただし `CapacitySession` や `ScheduledWorkspaceSession` のように、
子 editor を起動し、canonical evidence を再読込し、親 snapshot を更新して戻る session は
単純 editor とは異なる **orchestrator** である。
これらまで無理に `EditorSession` へ統合しない。

### 抽出候補

共有化は次のような小さく直交した部品を優先する。

- terminal editor loop
- one-line input / backspace / cursor
- selector / cyclic index
- scrolling / viewport
- confirmation / preview
- publish-error return path
- reload-after-success の小さな補助関数

### 非目標

- すべての TUI を一つの DSL にすること。
- domain state を generic form state へ変換すること。
- orchestrator の navigation semantics を callback 群へ隠すこと。
- 「行数が減る」だけを理由に局所的に分かりやすいコードを抽象化すること。

### Phase 2 の完了条件

各抽出ごとに、

```text
旧 UI behavior == 新 UI behavior
```

を既存 TUI テストで確認し、共通部品の利用側が元より説明しやすくなっていることを確認する。
共通化によって引数・callback・型パラメータが増えすぎる場合は、その抽象は採用しない。

### Phase 2 closure — 2026-09-29

最新 `main` で TUI mechanical duplication を再監査し、Phase 2 は停止条件に到達した。

採用した correspondence:

- #1543: presentation-local Backspace 編集を既存 `Terminal` owner に集約（net -16 lines）
- #1545: directional cyclic movement とその範囲証明を `CyclicIndex` に集約（net -19 lines）
- #1546: trailing list-window arithmetic を既存 `Layout.trailingWindowStart` に戻す（net -7 lines）

合計は **net -42 lines**。削減量自体より、三件とも domain state / authority /
publication semantics を増やさず exact mechanical correspondence だけを移したことを成功条件とする。

一方、`EditorSession` 周辺を広げる実験では、publisher refusal 後に同じ editor へ戻る
session と canonical reload のため caller へ戻る session が分かれ、共通 helper を追加して
5 session を移した時点でも **net +18 lines** だったため棄却した。
`Record` / `Correction` / `ScheduledCompletion` には unresolved activation による
world/catalog/editor の同時更新もあり、現行 generic contract へ押し込まない。

最終横断監査では one-line input、selection clamp、centered viewport、preview/confirmation、
reload-after-success を再確認したが、残候補は次のどちらかだった。

```text
既存 owner と exact correspondence がない
OR
新 helper / callback / state abstraction の追加が削減を上回る
```

したがって Phase 2 を閉じ、以後は mechanical TUI 抽象を増やすのではなく
Phase 3 の adapter / scaffold retirement を correspondence 単位で調べる。

---


## 8. フェーズ 3：中間アダプターと探索用足場のバイパス

Phase 3 では Application / Publisher / Review / Persistence を横断し、
探索時に導入された中間構造体・薄い変換・独自 traversal のうち、
production 上の意味をすでに失ったものを一つずつ取り除く。

### 削除候補の判定基準

単に「薄い wrapper」であることは削除理由にならない。
例えば `CapacityMovement` の wrapper は、
physical Event holdings と capacity authority を混同しないための **意味論的境界** を持つ。

バイパス候補は少なくとも次を満たすものとする。

```text
単なる表現変換である
AND 独自 authority を持たない
AND 独自 admission / validation を持たない
AND 独自 provenance を持たない
AND 独自 failure semantics を持たない
AND 前後の観測結果が同一
```

### old/new correspondence

安全な候補では、可能な限り一時的に

```text
old(input) == new(input)
```

という correspondence をテストまたは Lean の補題として置き、
同値が確認できてから旧経路を削除する。

この段階では #1515 が挙げた以下の領域を最新 `main` で再監査する。

- Publishers の atomic publication boilerplate
- Reviews の fold / aggregation
- Replacement / Correction / Settlement frontier traversal
- parser / formatter helpers
- diagnostic wrappers

#1454 時点の推定削減量は優先順位付けの参考には使うが、実装の正当化には使わない。

---

## 9. フェーズ 4：ドメイン概念ではなく「共通法則」を代数的に統合する

Scheduled、Capacity、Settlement には「将来に関係する量」という共通した直観があるが、
現行 Core では意図的に異なる意味論を持つ。

- `ScheduledOccurrence`: 時点に結び付いた expected balanced movement
- `CapacityMovement`: capacity authority 上の balanced movement
- `SettlementCommitment`: provenance、debtor / creditor、独立 measure / quantity を持つ obligation

したがって、三者をただちに一つの `Commitment` data type に畳み込むことはしない。

特に Settlement は revision、extinguishment、correspondence、netting という独自 lifecycle を持ち、
Scheduled や Capacity と同一視できない。

一方で production には既に `ScheduledCommitmentInspection` があり、
Scheduled から commitment-like な観測を projection として導出している。
これは「保存型を統一せず、観測上の共通法則を抽出する」方向を支持する。

### 探すもの

型の統一より先に、次のような共通 operation / law を探す。

- stable keyed identity
- quantity projection
- additive fold
- replacement / revision frontier
- open / closed frontier semantics
- provenance-preserving projection
- selection / grouping over a frontier
- correction under append-only history

候補が見つかったら、

1. 各ドメインで同じ法則が本当に成立するか確認する。
2. Lean で domain-specific theorem を共通 theorem から導けるか試す。
3. 共通核を導入した方が proof / code / explanation の総量が減る場合だけ昇格する。
4. domain distinction が必要なら wrapper / specialization として残す。

### Phase 4 の成功像

```text
domain-specific evidence
     ├─ Scheduled
     ├─ Capacity
     └─ Settlement
           ↓
   shared laws / operations
           ↓
 identity · quantity · fold · frontier · revision
```

目標は「名詞を一つにする」ことではなく、**同じ数学を一度だけ書くこと**である。

---

## 10. 実行単位：1 PR = 1 correspondence

第二次蒸留は大規模 rewrite として実施しない。
原則として各 PR は次の形にする。

```text
1. 重複または足場を一つ特定
2. 現在の意味・authority boundary を記述
3. old/new correspondence を固定
4. 最小の共有化またはバイパスを実装
5. 実データ + deterministic scenario + relevant CI で回帰確認
6. 旧実装を削除
7. 差分が本当に小さくなったか計測
```

PR の価値は deletion count ではなく、
**concept count / authority boundary / observable behavior が増えずに実装だけ簡潔になったか**
で判断する。

一つの共通化で新しい抽象概念を二つ以上増やす場合は、削除量が大きくても再検討する。

---

## 11. 第二次蒸留の開始条件

research/history distillation は #1539 で閉じ、Phase 1.5 の repository-wide census も
`599fe036eeafff6362bf3d8dfb0adb994a9b53e2` で完了した。
第二次蒸留の実装を始める際は、その時点の最新 `main` に対して #1454 の監査仮説を再計測する。

開始時には次だけを測る。

- production file / LOC / reachability
- TUI session / state-machine duplication
- Review fold duplication
- Publisher write-pipeline duplication
- Application frontier / adapter duplication
- root/direct documentation の current owner と supersession
- CI workflow / tool / visual-audit asset の current owner
- 現在の executable research / formal witness assets
- deterministic scenario が覆う主要 lifecycle

その結果から最初の 1 PR を選ぶ。
現時点では TUI の既存 `EditorSession` 周辺が有力だが、最新 main の重複量と
回帰防壁を確認してから確定する。

---

## 12. 結論

LOAM の次の軽量化は、単なる「コード削減」ではない。

探索で得た知識を production・proof・test へ蒸留し、
UI の機械的反復を小さな部品へ畳み、
意味を持たなくなった足場だけを撤去し、
最後に複数ドメインへ繰り返し現れる **法則そのもの** を共通化する。

```text
research distillation
        ↓
mechanical deduplication
        ↓
scaffold retirement
        ↓
algebraic law extraction
```

この順序なら、日常運用の LOAM を受け入れテストとして使いながら、
「機能を減らさず、意味を薄めず、説明可能性を上げながらコードを減らす」
という第二次蒸留を、小さな可逆的 PR の列として進められる。
