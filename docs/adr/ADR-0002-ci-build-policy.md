# ADR-0002: CI は SDK を必要とする build を走らせない

- Status: Accepted
- Date: 2026-10-08
- Related: ADR-0001

## Context

`scripts/build.sh` は Adobe After Effects SDK を必要とする（[ADR-0001](ADR-0001-no-sdk-vendoring.md)）。
CI で `./scripts/build.sh` を走らせたい場合は、runner が SDK archive を入手できる
mechanism が必要になる。

一方、CI には SDK を入手できない、できたとしても Adobe の配布条件 interpretations が
repository の contributor には確定できない、という制約がある。

## Decision

GitHub Actions では、SDK を必要とする build を走らせない。

代わりに、SDK 不要で検証できる範囲のみを CI に入れる。

- `plugins/**/Sources/**` の存在と `project.yml` の妥当性
- `.xcodeproj` が commit されていないこと（[ADR-0004](ADR-0004-generated-xcodeproj.md)）
- shell script の構文（`bash -n`）
- PiPL / Info.plist / `project.yml` の整合性チェック（script として切り出す）

## Consequences

### Positive

- SDK の入手経路が未確定である状態で、CI が緑になる false assurance を出さない
- CI が Adobe の配布条件について判断しない

### Negative

- compile error を pull request 上で捕捉できない。build は contributor 手の macOS でのみ成立する
- SDK を更新した際、CI は何も知らせない

### Neutral

- この repository の primary feedback loop は contributor の手元にある。この前提を README に明記する

## Considered and rejected

### CI で SDK archive を download する

取得 URL とその利用条件の解釈が未確定。第三者による Adobe 配布物の再取得が
配布条件に照らして正当か、という判断は contributor の authority 外である
（Constitution: Authority Integrity）。

確定できた場合は本 ADR を revisit する。

### SDK を container image に封入する

配布物を含む image の公開が Adobe の条件に照らして正当かが同じ理由で未確定。

### build を一切 CI に入れない

validator だけを入れるだけでも、syntax error や「生成物を commit してしまった」
という mechanical な regression は防げる。CI に入れる価値がある。

## Implementation notes

CI workflow は [ADR-0004](ADR-0004-generated-xcodeproj.md) の policy と一緒に実装する。
SDK 入手が確定次第、本 ADR を supersede する。