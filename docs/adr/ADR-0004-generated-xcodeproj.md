# ADR-0004: .xcodeproj を生成物として扱い commit しない

- Status: Accepted
- Date: 2026-10-08
- Related: ADR-0001, ADR-0002

## Context

After Effects plug-in の Xcode project には、通常 2 つの情報源が含まれる。

- source / build setting（人手で確認する対象）
- **絶対 path**（`HEADER_SEARCH_PATHS` の SDK path、file reference の SDK 内 path）

この repository は SDK を vendoring しない（[ADR-0001](ADR-0001-no-sdk-vendoring.md)）ため、
SDK path は contributor ごとに異なる。`.xcodeproj` を commit すると、

- contributor ごとの SDK path が commit され、他の contributor の build を壊す
  （自分の path を commit した contributor が次の contributor の obstacle になる）
- `.xcodeproj` は binary に近い大きな diff になり、review が実質不可能になる
- `project.pbxproj` の merge conflict を人手 で解く必要が生じる

## Decision

`.xcodeproj` は XcodeGen の `project.yml` から生成し、commit しない。

- source of truth: `plugins/<Plugin>/project.yml`
- 生成: `scripts/generate.sh`（`mise run generate`）
- `build.sh` は `.xcodeproj` が無い場合に自動 generate する
- `.gitignore` で `*.xcodeproj` と `*.xcworkspace` を除外する

SDK path は build setting の `AE_SDK_ROOT` として渡す。`project.yml` 内では
`${AE_SDK_ROOT}`（XcodeGen の環境変数展開）として参照する。

## Consequences

### Positive

- contributor ごとに SDK path が違っても conflict しない
- build setting の変更が review 可能な YAML diff になる
- fresh clone は build 前に 1 個の自動 step で project が生成される

### Negative

- `project.yml` という別の build 設定言語が必要になり、Xcode の UI での build setting 編集は
  使えなくなる。変更は `project.yml` で行う
- Xcode で project を開いた後、GUI での変更は `project.yml` に反映されない。
  この点を README に明記する
- XcodeGen が build の前提依存になる。ただし `mise.toml` で exact pin しており、
  入手経路は 1 command

## Considered and rejected

### `.xcodeproj` を commit して、SDK path だけを xcconfig で外出しする

外出しできる範囲は `HEADER_SEARCH_PATHS` など build setting 側のみ。`project.pbxproj` 内の
SDK file reference（`AEGP_SuiteHandler.cpp` 等）は absolute path として残り、
per-contributor の差异を吸収できない。加えて `project.pbxproj` の review 可能性が解決しない。

### Makefile / CMake で build する

AE の PiPL resource は macOS では Rez で compile される。CMake で表現できるが、
Adobe 自身が Xcode project を配布しており、SDK 添付の sample からの差分が
大きくなる。XcodeGen は Xcode project の形式を保ちつつ path だけを外出すので、
差分が最小になる。

### SDK 内 relative path を使う（`../../../Headers`）

SDK 内に repository を置けば可能だが、[ADR-0001](ADR-0001-no-sdk-vendoring.md) と衝突し、
かつ SDK の folder 構成に repository の life が拘束される。

## Implementation notes

`project.yml` の `${AE_SDK_ROOT}` は XcodeGen の実行時 environment 変数として
`scripts/build.sh` / `scripts/generate.sh` が export する。XcodeGen は
spec validation で path の存在を確認する。