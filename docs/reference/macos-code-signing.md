# Code signing on macOS

macOS 15 以降は unsigned plug-in を load しない。After Effects も AE plug-in
として上位 host なので、codesign していない `.plugin` は「ビルドは成功するのに
After Effects に一切出てこない」という形で現れる。

## 開発時の署名

ad-hoc signature で十分。Apple Developer Program の account や certificate は
不要で、`--sign -` の後ろの `-` が ad-hoc を意味する。

```sh
codesign --force --sign - --timestamp=none ./TemplateEffect.plugin
```

`--timestamp=none` を付けるのは、ad-hoc signature には timestamp server を
参照する意味がなく、network access を伴わないため。

## 署名済みファイルを変更しない

署名後に bundle の中身を書き換えると署名が無効になる。順序が重要:

- 正しい: build → copy → sign
- 誤り: build → sign → copy

`scripts/install.sh` はこの順序を明示している。`cp` は destination に既に
同名の bundle があると attributes を引き継ぐ場合があるため、remove してから
copy している。

## 確認

```sh
codesign --verify --strict ./TemplateEffect.plugin   # 成功 = 有効
codesign -dv ./TemplateEffect.plugin                  # Signature=adhoc が出るはず
```

`codesign -dv` は結果を stderr に出す。shell script で使う場合は
`2>&1` を付ける。

## 配布する場合

Developer ID で署名し、notarize が必要。加えて署名後に一切ファイルを変更しては
ならない。ad-hoc signature は配布用ではない。

この repository は現状 local 開発用であり、配布 pipeline を持っていない
（[ADR-0002](../docs/adr/ADR-0002-ci-build-policy.md) の scope 外）。

## After Effects 本体への debugger attach

AE 26.5 以降、official non-Beta build には Xcode から attach できない
（`Could not attach to pid`）。attach する場合は host application の copy を
`com.apple.security.get-task-allow` entitlement を付けて再署名する必要がある。
plug-in 側の署名とは別の話で、plug-in の signing policy を変える必要はない。

出典: <https://ae-plugins.docsforadobe.dev/intro/debugging-plug-ins/>,
<https://ae-plugins.docsforadobe.dev/intro/debugging-ae-macos/>