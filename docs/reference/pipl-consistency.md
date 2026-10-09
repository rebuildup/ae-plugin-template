# PiPL と実装の整合検査

After Effects は host との互換性判断に PiPL の `AE_Effect_Global_OutFlags`、
`AE_Effect_Global_OutFlags_2`、`AE_Effect_Version` を使い、同時に
plug-in 自身に `PF_Cmd_GLOBAL_SETUP` で同じ値を尋ねます。両者が食い違うと
AE はビルドを失敗させずエラーダイアログを出すため、壊れた PiPL のまま
配布され続けることがあります。

実際に After Effects 2026 (26.5) で観測された例:

- `エフェクト「Stretch」のバージョンが一致しません。Codeバージョンは1.2、PiPLバージョンは0.2です。(90000)`
- `エフェクト「Border」のバージョンが一致しません。Codeバージョンは1.0、PiPLバージョンは0.0です。(80002)`
- `エフェクト「ReptAll」のグローバルアウトフラグが不一致です。コードフラグは2000000 で、PiPLフラグは6000000です。`

いずれも PiPL 側の値が独自 encoding で作られたことが原因でした
（`PF_VERSION()` のビット配置ではない `(MAJOR << 16) | (MINOR << 8)` 形式など）。

`scripts/pipl_check.py` はこの不一致を build 時に検出します。
`scripts/verify.sh` から呼ばれます。

## 検査内容

| 検査 | 内容 |
| --- | --- |
| effect version | PiPL の `AE_Effect_Version` と `PF_VERSION()` を `AE_Effect.h` の定義どおりに再計算して比較 |
| global outflags | PiPL の hex literal と、`AE_Effect.h` から読み取った各 `PF_OutFlag*` の bit 値から計算した値を比較 |
| parameter count | `out_data->num_params` と `PF_Cmd_PARAMS_SETUP` が登録する `PF_ADD_*` の個数を比較 |

parameter count は AE の適用失敗に直結します。`num_params` は index 0 の
source layer 分を含むので、登録数は `num_params - 1` でなければなりません。

## 終了コード

| コード | 意味 |
| --- | --- |
| 0 | すべて一致 |
| 1 | 不一致が 1 件以上ある |
| 2 | 判定できなかった検査がある（一致は**確認できていない**） |

判定できない検査 silently に成功扱いしないことが重要です。実際に、
コメント付きの PiPL を素朴な正規表現で読むと property の値を抽出できず、
検査が飛んだまま「一致」と報告していました。現在の実装は
「一致を確認できない」ことを `note` として明示し、終了コード 2 で返します。

AEGP（`AEgx`）には `AE_Effect_Global_OutFlags` も match name もないため、
該当検査は `note` になります。

## 単体実行

```sh
AE_SDK_ROOT=/path/to/AfterEffectsSDK \
  python3 scripts/pipl_check.py plugins/TemplateEffect \
    plugins/TemplateEffect/Sources/TemplateEffectPiPL.r
```

## 検査自体のテスト

検査が検出能力を持つことを確認するため、意図的に欠陥を注入した
temporary copy に対して失敗することを検証します。

```sh
AE_SDK_ROOT=/path/to/AfterEffectsSDK python3 scripts/pipl_check_test.py
```

| ケース | 期待 |
| --- | --- |
| PiPL の effect version を 1 変える | 検出する |
| PiPL の global outflags を変える | 検出する |
| `num_params` を登録数より大きくする | 検出する |
| 無変更の template | 通る |

「全部を拒否する検査 EFFICIENT ではない」ことを最後のケースで担保しています。

## 対応していないもの

- AEGP の `AE_General.r` 固有 property
- 実 host での読み込み確認。bundle が load 可能かどうかは AE に読ませて初めて
  確認できるもので、この検査は host に読ませる前の整合に過ぎない
- Universal binary の x86_64 slice 実機動作