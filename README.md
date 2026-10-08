# macOS After Effects プラグイン開発環境

macOS 上で After Effects の C++ プラグイン（`.plugin` bundle）を開発するための
template リポジトリです。

Adobe の公式 sample（`Examples/Template/Skeleton`）を土台に、以下を行います。

- SDK を repository に含めず外部から解決する（[ADR-0001](docs/adr/ADR-0001-no-sdk-vendoring.md)）
- `.xcodeproj` を生成物として扱い、`project.yml` を source of truth にする
  （[ADR-0004](docs/adr/ADR-0004-generated-xcodeproj.md)）
- build と install を分離する（[ADR-0003](docs/adr/ADR-0003-separate-build-from-install.md)）
- compile 成功と host での動作確認を別の evidence として扱う

対象は macOS + After Effects 2026（26.5）/ SDK 26.5 です。

## 前提

| 必要なもの | 確認済み version |
| --- | --- |
| macOS | 26.x / Apple Silicon |
| Xcode | 27.0（command line tools ではなく full Xcode） |
| After Effects | 2026 (26.5.0) |
| After Effects SDK | 26.5（`Examples/Headers` を含む展開済み directory） |
| mise | 2026.10.x |

Xcode ではなく command line tools しかない場合、`rez` バイナリが
`/usr/bin/rez` に無く、PiPL resource を compile できません。

## セットアップ

### 1. SDK の場所を指定する

SDK は Adobe の配布物なので、この repository には含めません。場所を指定します。

```sh
# 方法 A: 環境変数
export AE_SDK_ROOT=/path/to/AdobeAfterEffectsSDK_26.5_MacOS

# 方法 B: リポジトリ直下の .env.local（gitignore 済み）
echo /path/to/AdobeAfterEffectsSDK_26.5_MacOS > .env.local
```

指定した directory に `Examples/Headers/AE_Effect.h` が無い場合、build は
`AE_SDK_ROOT` を解決した時点で失敗します。どの指定値がおかしいかを
message で示します。

確認:

```sh
mise run sdk-path
```

### 2. ツールを取得する

```sh
mise install
```

xcodegen のみを mise が管理します。compiler / linker / Rez / codesign は
Xcode が所有します。

### 3. build する

```sh
mise run build
```

`build/Debug/TemplateEffect.plugin` が出ます。初回は `.xcodeproj` を
自動生成します。

### 4. bundle を検証する

```sh
mise run verify
```

bundle structure、PiPL、exported symbol、signature、link dependency を検査します。
「`BUILD SUCCEEDED` なのに After Effects に出てこない」という状態を
build 時点で検出するためのものです。

### 5. After Effects に導入する

```sh
mise run install
```

`~/Library/Application Support/Adobe/Common/Plug-ins/7.0/MediaCore/TemplateEffect.plugin`
へ copy し、copy 後に ad-hoc signature を発行します。

**After Effects を再起動してください。** 新しく導入した plug-in は
起動時に読まれます。

## よく使う操作

| 操作 | command |
| --- | --- |
| Debug build | `mise run build` |
| Release build（universal binary） | `mise run build-release` |
| Xcode project を再生成 | `mise run generate` |
| bundle 検証 | `mise run verify` |
| AE へ導入 | `mise run install` |
| 導入を取り除く | `mise run uninstall` |
| plug-in folder を Finder で開く | `mise run ae-reveal` |
| build artifact を削除 | `mise run clean` |

## 自分の plug-in を作る

`plugins/TemplateEffect/` を複製して名前を変更します。

```sh
cp -R plugins/TemplateEffect plugins/MyEffect
```

`MyEffect/` 内で以下を変更します。SDK 同梱の Skeleton sample も同様に、
plug-in 名は `.plugin` bundle 名、`Info.plist` の `CFBundleExecutable`、
PiPL の `Name` / `AE_Effect_Match_Name`、`Sources/` のファイル名、
`project.yml` の target 名が一致している必要があります。

| 変更箇所 | 内容 |
| --- | --- |
| `project.yml` | `name`、`productName`、target 名、`PRODUCT_BUNDLE_IDENTIFIER` |
| `Resources/<Name>.plugin-Info.plist` | `CFBundleExecutable`、`CFBundleName` |
| `Sources/<Name>.cpp` / `.h` | ファイル名と include guard、entry point 名 |
| `Sources/<Name>PiPL.r` | `Name`、`AE_Effect_Match_Name`、`CodeMac*64` の entry point 名 |
| `Sources/<Name>_Strings.h/.cpp` | `StrID` と文字列 |

`AE_Effect_Match_Name` は唯一の識別子です。出荷したら変更しません。
project ファイルに焼き込まれるためです。

実際の pixel 処理は `Sources/<Name>.cpp` の `Render` と
`MySimpleGainFunc8` / `MySimpleGainFunc16` を置き換えます。

32bpc float（SmartFX）に対応する場合は
[docs/reference/upgrading-to-smartfx.md](docs/reference/upgrading-to-smartfx.md)
を参照してください。

## リポジトリ構成

```text
.
├─ mise.toml                      task と auxiliary tool の定義
├─ constitution/CONSTITUTION.md   最上位 contract
├─ organization/                  current operating profile
├─ docs/
│  ├─ adr/                        long-lived decision
│  └─ reference/                  macOS 固有の実装メモ
├─ plugins/
│  └─ TemplateEffect/
│     ├─ project.yml              XcodeGen spec（build setting の source of truth）
│     ├─ Sources/
│     └─ Resources/
├─ scripts/
│  ├─ lib/sdk.sh                  SDK 解決
│  ├─ build.sh                    compile
│  ├─ verify.sh                   bundle 検証
│  ├─ install.sh                  AE へ導入
│  └─ uninstall.sh                導入を取り除く
└─ .github/workflows/ci.yml       SDK 不要な validation のみ
```

## ビルドTips

### `.xcodeproj` を Xcode で編集しない

`.xcodeproj` は `project.yml` から生成されるため、Xcode の UI で build setting を
変更しても `project.yml` には反映しません。`project.yml` を編集して
`mise run generate` を実行します。

### Xcode で debug する

`mise run generate` の後に `plugins/TemplateEffect/TemplateEffect.xcodeproj`
を Xcode で開けます。Compile 実行は可能です。Run で After Effects を起動する
機構は XcodeGen の target にはありません（plug-in は host に load される
dylib bundle であり、standalone な executable ではありません）。

After Effects 本体への debugger attach は AE 26.5 以降、official build には
追加の re-sign が必要です。
[docs/reference/macos-code-signing.md](docs/reference/macos-code-signing.md) を参照。

### 「build したのに After Effects に出てこない」場合

この symptom の主要な原因と確認方法は以下です。

1. **署名が無い / 無効** — macOS 15 以降は unsigned plug-in を load しない。
   `codesign --verify --strict build/Debug/TemplateEffect.plugin` を確認
2. **After Effects を再起動していない** — plug-in は起動時に読まれる
3. **PiPL と binary の entry point 名が不一致** — PiPL は `CodeMacARM64` に
   `EffectMain` を書いているが、binary がその symbol を export していない
4. **`.plugin` bundle が途中で壊れている** — `Contents/` 以下の構造を確認

`mise run verify` は 1〜4 のうち 2・3・4 と、署名有効性を検査します。

## 制約

- **macOS のみ**。Windows は SDK の `BuildAll.sln` と PiPL の Windows 側
  build step が必要になるため、この repository の scope 外です
- **CI は build を走らせません**。Adobe SDK の入手経路が未確定です
  （[ADR-0002](docs/adr/ADR-0002-ci-build-policy.md)）
- **署名 policy は local 開発用の ad-hoc**。配布には Developer ID +
  notarization が必要で、その pipeline は未構築です

## 参照

- After Effects C++ SDK Guide: <https://ae-plugins.docsforadobe.dev/>
- Adobe developer portal: <https://www.adobe.io/after-effects/>
- Adobe After Effects SDK Forum:
  <https://community.adobe.com/t5/after-effects/bd-p/after-effects>

## License

この repository の script / documentation / template source には MIT を適用します。

`Sources/` の template は Adobe After Effects SDK の `Skeleton` sample を
派生していますが、compile に必要な Adobe SDK の header / support utility /
PiPL macro は本 repository に含まれず、利用者の SDK から参照されます。
Adobe の配布物に関する rights は Adobe Systems Incorporated に帰属します。