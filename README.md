# PlaceWatch

Placeのスナップショット間の差分を自動検出・可視化する **Roblox Studio プラグイン**です。

## 機能

- **Snapshot** - Placeのインスタンスツリーの現在の状態を保存
- **Compare** - 前回のスナップショットとの差分を検出（追加・削除・変更）
- **クリックで選択** - 変更項目をクリックするとExplorerでそのインスタンスを選択
- **フィルタ** - 変更タイプで絞り込み: All / +Added / -Removed / ~Modified
- **自動スキャン** - 定期スキャン（1分/2分/5分/10分）+ リアルタイム変更検出
- **Discord Webhook** - 変更を自動でDiscordチャンネルに通知
- **永続保存** - スナップショット・設定はセッション間で保持されます

## 追跡プロパティ

| クラス | プロパティ |
| ------ | ---------- |
| BasePart | Position, Size, Orientation, Color, Material, Anchored, Transparency, CanCollide, CastShadow, Reflectance, Shape |
| Model | PrimaryPart |
| GUI (TextLabel等) | Text, TextColor3, BackgroundColor3, TextSize, Font, Visible |
| Image (ImageLabel等) | Image, ImageColor3, BackgroundColor3, Visible |
| Light系 | Brightness, Color, Range, Angle, Face |
| Sound | SoundId, Volume, PlaybackSpeed, Looped |
| ParticleEmitter | Texture, Rate, Lifetime, Speed, Color |
| Decal / Texture | Texture, Face, Transparency |

## スキャン対象サービス

Workspace, ReplicatedStorage, ServerStorage, ServerScriptService, StarterGui, StarterPack, StarterPlayer, Lighting, SoundService

## インストール

### 簡単インストール（単一ファイル）

1. `PlaceWatch.lua` をダウンロード
2. Roblox Studioのプラグインフォルダに配置:
   - Windows: `%LOCALAPPDATA%\Roblox\Plugins\`
   - Mac: `~/Documents/Roblox/Plugins/`
3. Roblox Studioを再起動

### ソースからビルド（Rojo）

1. このリポジトリをクローン
2. Rojoでビルド: `rojo build -o PlaceWatch.rbxm`
3. 出力ファイルをプラグインフォルダに配置

## 使い方

1. ツールバーの **PlaceWatch** をクリックしてパネルを開く
2. **Snapshot** をクリックして現在の状態を保存
3. Placeに変更を加える
4. **Compare** をクリックして差分を確認
5. 変更項目をクリックするとExplorerで選択される

### 自動スキャン

- **Auto: ON** → 自動でスナップショットを取得・比較（インスタンスの追加/削除をリアルタイム検出）
- **間隔ボタン** → クリックで 1min / 2min / 5min / 10min を切り替え

### Discord Webhook 設定

1. **Webhook** ボタンをクリック
2. StudioのCommand Barに以下を入力して実行:

```lua
_G.PlaceWatchWebhook = "https://discord.com/api/webhooks/YOUR_WEBHOOK_URL"
```

3. 「Webhook connected!」と表示されたら完了
4. 変更が検出されると自動でDiscordに通知されます

## ファイル構成

```text
placewatch-plugin/
├── PlaceWatch.lua         -- 単一ファイル版（そのままインストール可能）
├── src/
│   ├── init.server.lua    -- エントリーポイント（モジュール版）
│   ├── Config.lua         -- 設定
│   ├── Snapshot.lua       -- インスタンスツリー取得
│   ├── DiffEngine.lua     -- 差分検出エンジン
│   └── UI.lua             -- プラグインUI
├── design.md              -- 技術設計書
└── README.md
```

## Contributors

- [@k153636](https://github.com/k153636)
- [Claude](https://claude.ai) (Anthropic)

## ライセンス

MIT
