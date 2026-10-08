# 32bpc float (SmartFX) 対応にする

TemplateEffect は 16bpc（`PF_OutFlag_DEEP_COLOR_AWARE`）までの template です。
After Effects の pixel pipeline は 32bpc float を SmartFX と呼び、
`PF_Cmd_FRAME_SETUP` / `PF_Cmd_RENDER` / `PF_Cmd_FRAME_SETDOWN` とは別の
呼び出し列を要求します。

参考: <https://ae-plugins.docsforadobe.dev/smartfx/smartfx/>

## 必要な変更

### 1. out flags

`PF_Cmd_GLOBAL_SETUP` で 2 つ追加します。

```cpp
out_data->out_flags  = PF_OutFlag_DEEP_COLOR_AWARE;
out_data->out_flags2 = PF_OutFlag2_SUPPORTS_SMART_RENDER |
                       PF_OutFlag2_FLOAT_COLOR_AWARE;
```

`PF_OutFlag2_FLOAT_COLOR_AWARE` は `PF_OutFlag2_SUPPORTS_SMART_RENDER` が
立っていないと効きません。

PiPL 側も一致させる必要があります。

```cpp
AE_Effect_Global_OutFlags {
    0x02000000   // PF_OutFlag_DEEP_COLOR_AWARE
},
AE_Effect_Global_OutFlags_2 {
    // PF_OutFlag2_SUPPORTS_SMART_RENDER (1 << 10) |
    // PF_OutFlag2_FLOAT_COLOR_AWARE    (1 << 12)
    0x00001400
},
```

PiPL の `CodeMacARM64` / `CodeMacIntel64` の記載は、この 2 つの
entry point 自体は同じです。呼び出し側の `PF_PixelFloat` callback を
smart render path に追加します。

### 2. 呼び出しの分岐

```cpp
if (out_data->out_flags2 & PF_OutFlag2_SUPPORTS_SMART_RENDER)
{
    switch (cmd)
    {
        case PF_Cmd_SMART_PRE_RENDER:  /* frame 全体の準備 */ break;
        case PF_Cmd_SMART_RENDER:      /* PF_PixelFloat を処理 */ break;
        case PF_Cmd_SMART_FRAME_SETDOWN: break;
        default: break;
    }
}
else
{
    switch (cmd)
    {
        case PF_Cmd_FRAME_SETUP:  break;
        case PF_Cmd_RENDER:       break;
        case PF_Cmd_FRAME_SETDOWN: break;
        default: break;
    }
}
```

AE は smart render を要求する host では smart call を使い、それ以外では
classical を使います。分岐必須です。

### 3. pixel callback

```cpp
static PF_Err MyGainFuncFloat(void* refcon, A_long xL, A_long yL,
                              PF_PixelFloat* inP, PF_PixelFloat* outP)
{
    GainInfo* giP = static_cast<GainInfo*>(refcon);
    outP->alpha = inP->alpha;
    outP->red   = inP->red   + giP->gainF / 100.0f;
    outP->green = inP->green + giP->gainF / 100.0f;
    outP->blue  = inP->blue  + giP->gainF / 100.0f;
    return PF_Err_NONE;
}
```

float では clamp が不要です。`PF_Pixel8` / `PF_Pixel16` と倍精度浮動小数点の
扱いが違う点に注意してください（8bpc は `MIN(..., PF_MAX_CHAN8)` で
integer に丸め、float は丸めない）。

### 4. suite の version

SmartFX 用の iteration suite が必要です。`Iterate16Suite2` ではなく
`IterateSuite` の float 版を使います。suite が無い host（古い Premiere 等）
を相手にするなら、smart path ではなく classical path へ fallback する
分岐を明示してください。

### 5. version の報告

Multi-Frame Rendering を得るには SDK 13.25 以上を報告する必要があります。
`AE_Effect_Spec_Version` に `PF_PLUG_IN_VERSION` / `PF_PLUG_IN_SUBVERS` を
そのまま使う（SDK 26.5 では 13 / 29）ので、意識的な変更は不要です。

## 検証

- After Effects のプロジェクトを 32bpc float（`Linear color management` を
  enable）に切り替え、template の 8bpc / 16bpc path をそれぞれ regression 確認する
- `scripts/verify.sh` が PiPL outflags を 16bpc 前提で検査しているため、
  変更後は期待値を更新する