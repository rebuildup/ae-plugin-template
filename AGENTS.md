# AGENTS.md

AI コーディングエージェント、およびこのリポジトリで作業する人間の開発者に向けた
作業原則。仕様の固定ではなくガードレールです。

## 1. この repository が何であるか

macOS 上で After Effects の C++ プラグインを開発するための template です。

- build setting の source of truth は `plugins/<Name>/project.yml`（XcodeGen spec）です。
  `.xcodeproj` は生成物で commit しません
- Adobe SDK は vendoring しません。`AE_SDK_ROOT` で外部参照します
- build と install は別の script です。build は host の scan directory を触りません

## 2. Constitution / operating profile

- 最上位 contract: [`constitution/CONSTITUTION.md`](constitution/CONSTITUTION.md)
- current Operating Model: [`organization/profiles/release-driven-solo.md`](organization/profiles/release-driven-solo.md)

決定できることは上位層から決めます。policy と project evidence が衝突する場合は
どちらを authority とするかを明示してから進みます。

## 3. 作業の入口

```sh
mise install          # 初回のみ
mise run build        # compile
mise run verify       # bundle の構造・PiPL・署名・symbol を検査
mise run install      # After Effects へ導入（host の state を変更する）
mise run sdk-path     # SDK 解決結果の確認
```

`mise exec -- <command>` / `mise run <task>` が project tool の標準入口です。
shell activation に依存しません。

## 4. 判断的地位の再確認

build setting は `project.yml` を編集します。生成済みの `.xcodeproj` を Xcode の
UI で変更しても `project.yml` には反映されません。

## 5. 検証の扱い

**「ビルド成功」と「After Effects で動作する」は別の evidence です。**

- `scripts/build.sh` が返すのは compilation evidence のみ
- `scripts/verify.sh` は bundle が load 可能か検査しますが、host での実動作
  は確認しません
- After Effects 起動・plug-in 導入・host state の変更は明示的な user action
  として扱い、agent が自動実行しません

報告時に host で確認していない場合は、その事実を明示してください。

## 6. SDK に関する判断

Adobe の配布物に関する利用条件の解釈は、contributor の authority 外です
（Constitution: Authority Integrity）。SDK の再配布・cache 化・container 封入を
行う decision が必要になった場合は、developer に確認します。

SDK の API に関する断定は SDK ヘッダまたは公式 guide を確認してから行います。
記憶や推測で API の挙動を述べない。

## 7. persistent な文書を書くとき

README / `docs/` / ADR / PR 本文 / commit message など、reader-facing な prose を
作成・更新する前に [`writing-discipline`](https://github.com/rebuildup/project-init)
の考え方を適用します。

- 会話中的な作業 context をそのまま serialize しない
- 恒久文書は「後の第三者が読んで意味があるか」で判断する
- 未検証の事実を確定情報として書かない。検証済み /
  未検証 / 要確認を区別する

## 8. 変更の粒度と scope

- 1 つの意味のある単位で commit します。WIP を commit しません
- commit message にはその変更の意図を書きます。実装詳細の羅列や作業ログは
  書きません
- 依頼された scope を超える変更を独断で加えません。特に host の state を変更する
  操作（install / AE 起動）は scope として明示的に示された場合にだけ行います

## 9. 自明な判断を user へ返さない

次の条件を満たすなら自分で判断して進めます。

- repository evidence から答えが一意に定まる
- reversible で局所的
- acceptance criteria を変えない
- public / external contract を新規に確定しない
- host state・security・cost・release scope を重大に変えない

逆に、以下は user へ確認します。

- plug-in の match name / bundle identifier など public identity の確定
- After Effects への plug-in 導入、After Effects の起動・終了
- Adobe SDK の扱いを変える decision
- release scope / version の変更

## 10. Recovery

session が中断しても、次の 2 つで状態を再構成できます。

- `docs/adr/` に記録した decision
- `git log` と open な Issue / PR

会話履歴を唯一の recovery source にしません。未完了の作業があれば、その時点で
到達可能な最良の状態（build 可能なら build 済み）に bring してから止めます。