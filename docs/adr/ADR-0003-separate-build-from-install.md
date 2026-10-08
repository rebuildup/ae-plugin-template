# ADR-0003: build と install を分離する

- Status: Accepted
- Date: 2026-10-08

## Context

Adobe の SDK guide は、macOS 上の開発用 build output 先として
`~/Library/Application Support/Adobe/Common/Plug-ins/7.0/MediaCore/` を
推奨している。SDK 同梱の sample project は、この path を Xcode の
Build Location に直行で設定する構成になっている。

この構成には host application との関係で問題がある。

- After Effects は起動中に plug-in folder を scan する。build 中に bundle が
  書き換わると、AE 側は「plug-in が消えた」「壊れた」と解釈しうる
- build output と install 済み state が同じ path にあるため、「いま AE が見ている
  のはどの build か」を回答できない
- 作業 directory を消すと、install 済み plug-in が残る
- `sudo` 解决的 build は root 所有の artifact を残し、後続の rebuild を壊す
  （SDK guide 自身が caution している）

## Decision

build output は repository 配下の `build/<configuration>/` に閉じ込める。
host application の plug-in folder への deploy は、`scripts/build.sh` とは
別 script（`scripts/install.sh`）による明示的な操作とする。

`install.sh` は次を 1 回の操作として行う。

1. destination を remove する
2. bundle を copy する
3. copy 後に ad-hoc signature を発行する

## Consequences

### Positive

- build 中に host application が scan する directory を触らない
- 「いま AE に入っているのはどの build か」を repository 内の path から回答できる
- build と install が独立して retry できる

### Negative

- 開発ループに 1 step 増える。「build したら AE で確認する」に install が挟まる
- contributor が「build したのに AE で出てこない」と誤解する可能性がある。
  README と error message で明示する

### Neutral

- 追加した install script の MacOS の state への変更は、AI agent には明示的な
  authorization 境界となる。`scripts/install.sh` は host を起動しない

## Considered and rejected

### Xcode の Build Location を直接 MediaCore にする（SDK sample と同じ構成）

上の Context のとおり host state との競合がある。多数派だから採る理由にはならない。

### build script の hook で自動 install する

衝突更强的。build を「compile するだけの操作」に保つ。

### `~/Library/Application Support/...` を symlink して build/ に redirect する

AE は alias を辿る（recursive scan 対象）ため動作はするが、「今 build 中か
AE が読んでいるか」が分からない。install が暗黙化される本質的な問題は残る。

## Implementation notes

`scripts/uninstall.sh` はこの repository が build できる plug-in のみを削除する。
third-party plug-in を巻き込まない。