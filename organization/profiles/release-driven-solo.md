# Release-driven solo development profile

- Status: Current default
- Constitutional authority: none; this profile must refine the Constitution
- Related: ADR-0001, ADR-0002, ADR-0003

## Purpose

このリポジトリの current development で使用する Operating Model を定義します。

この profile は project-init の唯一の正しい organization topology ではありません。別 profile または project-specific model が Constitution を満たす場合は置換できます。

## Project shape

単一 developer の native C++ plug-in 開発です。plug-in は 1 つだけには固定せず、複数の plug-in を `plugins/` 配下に并列させます。ただし初期 scope は TemplateEffect 1 つで、追加は明示的な scope 決定とします。

対象: After Effects の C++ プラグイン（Effect / AEGP / AEIO）。

- 1 つの repository が複数の plug-in を保持し得ます。
- host application は After Effects ですが、PiPL / entry point の構造により Premiere Pro 等の他 host への展開も可能です。
- Windows 版は SDK には `BuildAll.sln` が含まれますが、この repository の初期 scope は macOS のみです。

## Current topology

### Source and implementation state

- Git: source state の canonical authority
- GitHub Issues: durable implementation scope / acceptance criteria / dependency state
- GitHub Pull Requests: review / candidate integration / validation evidence
- `main`: released / integrated source state
- `release-x-y-z`: current release integration line

### Toolchain ownership

- Xcode: native compiler / linker / Rez / codesign の owner
- After Effects SDK: header / support utility / PiPL macro の owner。SDK は licensed material であり、この repository には vendoring しません
- `xcodegen`: `.xcodeproj` の生成器。生成物は build artifact であり commit しません
- mise: auxiliary tool bootstrap と task 入口のみ。native toolchain の owner ではありません

SDK の location は configuration として扱い、次の precedence で解決します。

1. `AE_SDK_ROOT` environment variable
2. `.env.local`（gitignored）
3. `AE_SDK_ROOT_FILE` が指す file の 1 行目
4. well-known location の走査

解決結果は常に検証されます。`Examples/Headers/AE_Effect.h` が無い path は SDK として扱いません。

### Delivery defaults

- normal sprint cadence: 1 week
- top-level durable work: GitHub Issue
- ticket branch: Issue number only
- independent ticket PR: target release branch
- hard dependency stack: immediate predecessor branch を base にできる
- first meaningful durable commit 後は canonical remote publication + Draft PR を行う
- release branch に meaningful difference が入ったら Draft release PR を維持する
- `main` への normal integration は current release branch からの release PR だけ
- PR landing method: merge commit only
- repository merge settings: `allow_merge_commit=true` / `allow_squash_merge=false` / `allow_rebase_merge=false`
- merge / landing は explicit user authorization を必要とする

### Build and deploy defaults

- build output は repository 配下の `build/<configuration>/` に閉じ込める
- host application の plug-in folder への deploy は build と分離した明示 step とする
- deploy は host application が停止している前提で、signature を copy 後に発行する

rationale は [ADR-0003](../docs/adr/ADR-0003-separate-build-from-install.md) に記録しています。

### Validation defaults

- `scripts/build.sh` は compilation evidence のみを生成します
- `scripts/verify.sh` が bundle structure / PiPL / exported symbol / signature を検査します
- host application への実ロードは host state を変更するため、agent が自動実行しません

## Constitutional mapping

### Identity Integrity

- build は resolved `AE_SDK_ROOT` を入力 identity として記録する
- `verify.sh` は直前に build された bundle のみを検証対象とする

### Authority Integrity

- compile 成功を host での動作 confirmation として扱わない
- plug-in の public identity（match name / bundle id）は human が確定する
- `main` への merge は ADR-0012 相当の explicit authorization boundary を維持する

### Evidence Integrity

- build result と host load result を別の evidence として扱う
- host で動かしていない場合は README / docs にその事実を残す

### Mutable Ownership Safety

- After Effects 起動中の plug-in overwrite を避けるため、install を明示 step に分離する
- build output を host の scan directory に直接書かない

### Organizational Continuity

- Issue / PR / Git ref / committed docs が durable recovery source
- build / install / verify の手順を README から到達可能にする
- agent session 内の知識に正となる手順を残さない

### Canonical Consistency

- SDK version の canonical source は Adobe SDK 側。third copy を作らない
- plug-in version は source header と PiPL の 2 箇所を同時更新する

### Progress

- host application 非起動を build / verify の blocker にしない
- SDK 未設定を build の blocker として、解決手順を明示したうえで停止する

## Deviation

この profile の具体的な tool / cadence / topology から外れる場合でも、該当する Constitutional guarantee を維持できれば許容します。

## Re-evaluate / remove

次の場合に見直します。

- Windows 対応を actual scope に加えた場合、build topology は再設計を要する（`BuildAll.sln` と PiPL の Windows 側 build step が別物のため）
- plug-in を実際に配布始めた場合、signature policy は Developer ID へ移行する
- plug-in 数が複数になり、per-plug-in build / deploy script の手動運用が破綻した場合
- host application 以外の target（Premiere Pro 等）を actual scope に加えた場合