# ADR-0005: PiPL と PF_Cmd_GLOBAL_SETUP の整合を build 時に検査する

- Status: Accepted
- Date: 2026-10-09
- Related: ADR-0003

## Context

macOS へ移行した 8 個の After Effects プラグインを After Effects 2026 (26.5) で
読み込んだところ、AE が PiPL 由来の不整合を 3 件報告しました。

- `エフェクト「Stretch」のバージョンが一致しません。Codeバージョンは1.2、PiPLバージョンは0.2です。(90000)`
- `エフェクト「Border」のバージョンが一致しません。Codeバージョンは1.0、PiPLバージョンは0.0です。(80002)`
- `エフェクト「ReptAll」のグローバルアウトフラグが不一致です。コードフラグは2000000 で、PiPLフラグは6000000です。`

いずれも build は成功しており、bundle structure / signature / export symbol の
検査も通っていました。原因是 PiPL 側で値が独自 encoding で書かれていたことでした。
`Stretch` は `(MAJOR << 16) | (MINOR << 8)` 形式を、`Border` は vers ビットが
立っていない hex literal を、`ReptAll` は `AE_Effect.h` に存在しない
bit を含んでいました。

`PF_VERSION()` のビット配置は `AE_Effect.h` しかないため、PiPL の作者が
推測で書くこと自体は避けられません。また `Rez` はマクロを展開できないので、
正しい値を TriPL とソースの二重定義に書かなければなりません。

AE はこの不一致をダイアログで知らせるだけで、build や load の失敗にはしません。
そのため「検証が通った」と「AE が警告を出さない」は別の主張です。

## Decision

PiPL の `AE_Effect_Version`、`AE_Effect_Global_OutFlags`、
`AE_Effect_Global_OutFlags_2`、および `out_data->num_params` と
`PF_Cmd_PARAMS_SETUP` の登録数を、SDK header から再計算した値と突き合わせる
検査を `scripts/pipl_check.py` として導入し、`scripts/verify.sh` から呼びます。

検査が判定できなかった場合は「一致」と報告しません。終了コードで区別します。

| コード | 意味 |
| --- | --- |
| 0 | すべて一致 |
| 1 | 不一致がある |
| 2 | 判定できなかった検査がある（一致は確認できていない） |

検査自体の検出能力は `scripts/pipl_check_test.py` で担保します。意図的に
欠陥を注入した copy に対して失敗することと、無変更の template が通ることを
両方検証します。「全部を拒否する検査は使えない」ことを検出するため後者は必須です。

## Consequences

### Positive

- AE が報告する PiPL 不整合が build 時に検出される
- 判断できない検査が success に転化しない
- 検査自体の妥当性をテストで示せる

### Negative

- SDK header の bit 定義を読み取るので、SDK を更新すると検査の前提が変わる
- C++ の式を部分的に評価するため、計算できない形（C++ 関数を呼ぶ、
  配列添字で値を組み立てる等）は `undecided` になる。これは意図的に
  「一致ではない」扱いにする

### Neutral

- AEGP には `AE_Effect_Global_OutFlags` も match name も無いので、該当検査は
  `undecided` になる。AEGP 固有の検査を追加するまでは這個検査では
  AEGP の整合は担保できない

## Re-evaluate

- PiPL の version encoding を SDK が定義し始めたら
- 複数 PiPL を 1 ファイルに置く構成が推奨されるようになったら
- AEGP 固有の PiPL property 検査を追加する場合