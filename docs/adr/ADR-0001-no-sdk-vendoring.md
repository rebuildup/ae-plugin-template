# ADR-0001: Adobe After Effects SDK を repository に vendoring しない

- Status: Accepted
- Date: 2026-10-08
- Related: ADR-0002, ADR-0003

## Context

After Effects C++ プラグインを compile するには Adobe After Effects SDK が必要で、SDK は
`Examples/Headers`（約 40 ファイル）と `Examples/Util`（support utility）と
`Examples/Resources/AE_General.r`（PiPL macro 定義）を含む。

JDK / npm package なら SDK も vendoring するのが自然だが、SDK は Adobe の配布物であり、
再配布の条件がある。加えて SDK は AE の version と強く結びついており、upgrade のたびに
差分が retrieving し直される。

## Decision

SDK は repository に含めず、build 時に外部から解決する。

解決 precedence:

1. `AE_SDK_ROOT` environment variable
2. `.env.local`（gitignored）
3. `AE_SDK_ROOT_FILE` が指す file の 1 行目
4. well-known location の走査

候補は `Examples/Headers/AE_Effect.h` の存在で必ず検証する。`scripts/lib/sdk.sh` が
実装し、誤った path を黙って受け入れることはしない。

SDK は build artifact の入力ではなく build configuration として扱う。

## Consequences

### Positive

- SDK upgrade が repository の diff 产生影响ない
- Adobe の配布条件遵守に関する ambiguous な状態を repository が抱えない
- 複数の SDK version を side-by-side で試せる（`AE_SDK_ROOT` を切り替えるだけ）
- repository size が SDK 分だけ小さくなる

### Negative

- build には SDK の入手手順が前提になる。README に明記する
- CI で build するには、SDK を入手する mechanism が必要。 後述
- `AE_SDK_ROOT` 未設定の contributor は，第一次的に明示的なエラーを見る

### Neutral

- SDK の header を直接 `#include` するため、SDK の API 変更は compile error として現れる。
  これは正しい feedback で、vendoring しても同じである

## Considered and rejected

### SDK を submodule として入れる

submodule は vendoring を避けつつ「入手済み」状態を作る。ただし submodule は
repository への参照であり、SDK を pinned する。SDK は version ではなく「その時点の
配布物」であり、upstream の tag を追跡できる保証がない。加えて submodule 内の
licensing の扱いは submodule 単体では明確にならない。

### SDK の header を必要な分だけ copy する

Macの minimal subset でも `AE_Effect.h` 1 file が suite を间接的に広く含む。実際には
実質的に SDK 全体が依存グラフに入る。加えてこの copy は Adobe の改変であり、
原典との対応追跡が恒久的な burden になる。

### Docker で SDK を封入した image を作る

image の配布が redistribution -fiber にならないか Adobe の条件を確認する必要がある。
この判断の authority は contributor にはない（Constitution: Authority Integrity）。

## Implementation notes

CI は `macos-latest` で Adobe の SDK archive を取得する必要がある。この取得経路と
利用条件の解釈は未確定であり、[ADR-0002](ADR-0002-ci-build-policy.md) で未確定として
扱う。現状 CI は build を走らせない。