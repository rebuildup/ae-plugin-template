# ae-plugin-template Constitution

この文書は、このリポジトリの開発組織における最上位 contract です。

具体的な agent、provider、IDE、Git hosting、planning tool、branch 命名、sprint cadence、command は Constitution ではありません。それらは current operating model / practice が、この Constitution を実現するために選ぶ交換可能な手段です。

## Policy hierarchy

1. **Constitution** — 組織として常に維持する性質
2. **Operating Model** — 現在の役割・planning・delivery・release 構造
3. **Practice** — Operating Model を実現する現在の tool / workflow
4. **Skill** — 判断が必要な場面の progressive disclosure / playbook

下位層は上位層を refine します。下位層の都合で上位の意味を変更しません。

## Constitutional properties

### Identity Integrity

Task、execution attempt、artifact、evidence、decision、authority の identity を暗黙に置換しません。

ある artifact / attempt へ bind された result や evidence を、別 identity の current result / evidence として扱うには、明示的で妥当な導出関係が必要です。

この repository で具体的に意味すること:

- ビルド成果物と、その成果物を検証した evidence は同じ build identity に bind します。`scripts/verify.sh` が検査する bundle は `scripts/build.sh` が直前に生成したものに限定します。
- `AE_SDK_ROOT` の解決結果は、そのビルドの入力 identity の一部です。SDK  naturalist の異なる結果を同じビルドの evidence として使い回しません。

### Authority Integrity

重要な decision は、その decision について authority を持つ actor / process だけが確定できます。

技術的に実行可能、validation 済み、review 済み、Ready であることは、それ自体では authority を生成しません。

- Adobe After Effects SDK の EULA と its terms に関する ownership / redistribution の判断は、repository の contributor には prenegotiation できません。SDK を vendoring しないという design は、authority を持つ human が置き直せる decision として明示します。
- Plug-in の match name、bundle identifier、shipping 先は user-visible contract であり、agent 側の local reversible 判断を超える scope です。

### Evidence Integrity

組織が主張する内容は、その scope と強さに対応する evidence を持ちます。

stale / partial / unrelated / unverifiable evidence を current proof として扱いません。

- `** BUILD SUCCEEDED **` は compilation の evidence であり、After Effects がその plug-in を load できた evidence ではありません。この repository の README と `scripts/verify.sh` は両者を区別します。
- macOS 15 以降は unsigned plug-in を load しないため、「ビルド成功」と「AE で動く」は別 condition です。

### Mutable Ownership Safety

concurrent work は、同じ mutable state へ無調停で競合する ownership を作りません。

isolation、serialization、transaction、conflict-free semantics 等、同等以上の guarantee を持つ任意の mechanism で実現できます。

- After Effects は有効な plug-in を host process 内で load します。AE 起動中の plug-in overwrite は host の mutable state を破壊するため、`scripts/install.sh` は build を自動実行せず、AE 停止中の明示的な操作とします。

### Organizational Continuity

一つの ephemeral actor、conversation、process、runtime、provider の喪失だけで、重要な unfinished work を安全に理解・継続するための organizational state を失わないようにします。

- plug-in の正となる knowledge は `.aep` ファイル内の project state と `docs/` 内の decision record にあり、agent session には置きません。
- `scripts/` は README から到達できる名前を持ち、会話履歴なしでも実行系列が再構成できます。

### Canonical Consistency

同じ fact について、reconciliation rule のない複数の conflicting canonical authority を意図的に維持しません。

- After Effects SDK の version は、PiPL の `AE_Effect_Spec_Version`（SDK 側 constant）と `AE_SDK_ROOT` が指す実物という 2 箇所に現れます。どちらも Adobe が定義する canonical value であり、repository 内で copy して持つ third copy を作りません。
- Plug-in の version は `Sources/*.h` の `MAJOR_VERSION` 等と PiPL の `AE_Effect_Version` の 2 箇所に現れます。PiPL 側は `PF_VERSION(...)` 相当の encoding である必要があり、値が変わったときは両方を同時に更新します。

### Progress

safety のために通常 work を永久停止させません。

必要な input / authority が利用可能で valid blocker がない work は、明示的な terminal state または正当な waiting state へ進める必要があります。

- After Effects が起動していない、host application を操作する権限がない、といった事情は、build / verify 作業の blocker にはしません。該当範囲のみ waiting state として明示します。

## Optimization principle

このリポジトリの開発組織の目的は current procedure への服従ではありません。

概念上、actor は次を行います。

```text
maximize project utility
subject to:
  constitutional properties
  explicit product / organizational decisions
```

## Refinement

Operating Model / Practice は、上位 property に対して次を説明できるようにします。

- implements
- assumptions
- guarantees
- evidence
- known limits
- deviation conditions
- re-evaluate / remove conditions

current default と異なる方法でも、適用される上位 guarantee を同等以上に維持するなら採用できます。

## Deviation

default からの deviation は異常系ではありません。

少なくとも次を満たす場合、より良い alternative を選択できます。

1. 適用される上位 obligation が特定されている
2. alternative が同等以上の guarantee を維持する
3. explicit decision を無断で上書きしない
4. material な risk / unknown を隠さない
5. consequential boundary 変更なら durable evidence を残す

## Change discipline

Constitution への追加は、Operating Model / Practice / Skill では表現できない長寿命な organizational failure を防ぐ場合に限定します。

non-constitutional rule は、能力向上・代替 mechanism・eval evidence によって不要になった場合、意図的に降格・削除できます。

## Upstream source

`rebuildup/project-init` から reconcile した。 adapted for a single-repository, single-developer native plug-in project。