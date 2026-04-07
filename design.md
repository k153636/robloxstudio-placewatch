# PlaceWatch Studio Plugin - 設計書

## 概要

Roblox Studio内で動作するプラグイン。Publish時に自動でPlaceのスナップショットを取得し、前回との差分を視覚的に表示する。

## ユーザー体験

1. プラグインをインストール
2. Studio上で普通に開発
3. Publishすると自動で前回との差分がパネルに表示される
4. 追加・削除・変更されたインスタンスが一目でわかる

## 技術構成

- **言語**: Luau (Roblox Lua)
- **種類**: DockWidgetPluginGui
- **データ保存**: plugin:GetSetting() / plugin:SetSetting()

## コア機能

### 1. スナップショット取得

```text
game全体のインスタンスツリーを走査:
- Instance.Name
- Instance.ClassName
- 主要プロパティ（Position, Size, Color, etc.）
- 親子関係（フルパス）
```

### 2. 差分検出

```text
前回スナップショット vs 現在の状態:
- Added: 新しいインスタンス
- Removed: 削除されたインスタンス
- Modified: プロパティが変わったインスタンス
- Moved: 親が変わったインスタンス
```

### 3. UI表示

```text
DockWidgetPluginGui:
├── ヘッダー（最終スナップショット日時）
├── サマリー（+5 added, -2 removed, ~3 modified）
├── 変更リスト（ツリービュー）
│   ├── [+] Workspace.NewPart (Part)
│   ├── [-] Workspace.OldModel (Model)
│   └── [~] Workspace.Door.Size: (4,8,1) → (4,10,1)
└── ボタン
    ├── [スナップショット取得]
    └── [差分表示]
```

## 対象サービス（走査範囲）

- Workspace
- ReplicatedStorage
- ServerStorage
- ServerScriptService
- StarterGui
- StarterPack
- StarterPlayer
- Lighting
- SoundService

※ スクリプトの中身（Source）は除外（テキスト差分は別ツール向き）

## プロパティ取得対象

### 共通

- Name, ClassName, Parent

### Part系

- Position, Size, Orientation, Color, Material, Anchored, Transparency

### Model系

- PrimaryPart

### GUI系

- Position, Size, Text, TextColor3, BackgroundColor3, Visible

### Light系

- Brightness, Color, Range

## ファイル構成

```text
placewatch-plugin/
├── src/
│   ├── init.server.lua      -- エントリーポイント
│   ├── Snapshot.lua          -- スナップショット取得
│   ├── DiffEngine.lua        -- 差分検出
│   ├── UI.lua                -- プラグインUI
│   └── Config.lua            -- 設定
└── design.md                 -- この設計書
```

## 制限事項

- plugin:GetSetting()の容量制限あり（大規模Place対応が必要）
- Terrainは個別対応が必要
- スクリプトのSourceは対象外
