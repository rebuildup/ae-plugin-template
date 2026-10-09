# Decision Records

この directory は"Why こう決めたか"の長期記録です。運用手順は
[README](../../README.md)、host 固有の実装メモは
[../reference/](../reference/) にあります。

決定改变 推翻された record は消さずに、superseded として残します。

## Records

| ADR | 状態 | 要点 |
| --- | --- | --- |
| [ADR-0001](ADR-0001-no-sdk-vendoring.md) | Accepted | Adobe SDK を repository に vendoring せず `AE_SDK_ROOT` で外部解決する |
| [ADR-0002](ADR-0002-ci-build-policy.md) | Accepted | SDK 入手経路が未確定のため、CI は build を走らせない |
| [ADR-0003](ADR-0003-separate-build-from-install.md) | Accepted | build output は repository 配下、AE への導入は別 script |
| [ADR-0004](ADR-0004-generated-xcodeproj.md) | Accepted | `.xcodeproj` を生成物として扱い、`project.yml` を source of truth にする |
| [ADR-0005](ADR-0005-pipl-source-consistency.md) | Accepted | PiPL の version / outflags / parameter count と実装の整合を build 時に検査する |

## まだ決まっていないこと

以下は明示的に未確定です。推測で固定しません。

- **Windows build** — SDK の `BuildAll.sln` と Windows 側 PiPL build step の
  組み込み方。macOS の観測からは判断できない
- **配布用署名** — Developer ID / notarization の pipeline。開発時の ad-hoc 署名で
  開発は成立するが、配布経路は未構築
- **CI での SDK 入手** — Adobe の配布条件の解釈を含む。contributor の authority 外
- **plug-in の reference host** — Premiere Pro 等を actual scope に含めるか
- **AEGP 固有の PiPL 検査** — 現状 AEGP は整合検査の対象外。effect と
  PiPL property が異なるため