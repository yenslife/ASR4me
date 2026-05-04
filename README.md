# ASR4me

`ASR4me` 是一個 macOS 原生（`Swift + SwiftUI + AppKit`）的語音轉文字工具，支援：

- 全域快捷鍵 toggle 錄音
- 開始/停止提示音
- 雲端 ASR（OpenAI Whisper）優先 + 本機 `whisper.cpp` fallback
- 結果浮動面板
- 手動複製剪貼簿
- LLM 文字修飾（拼字修正 / 正式口吻 / 精簡）

## 目前狀態

- 已有可編譯的 `SwiftPM` 骨架（開發驗證用）
- 已準備正式 app metadata 設定檔：
  - `Config/ASR4me-Info.plist`
  - `Config/ASR4me.entitlements`
  - `Config/ASR4me.xcconfig`

## 專案結構

- `Sources/ASR4me/`：主要 app 程式碼（App / Core / Services / UI）
- `Config/`：`Info.plist`、entitlements、xcconfig（Xcode target 需引用）
- `Scripts/`：打包與圖示產生腳本
- `Resources/`：App icon（`.icns`）、DMG 背景圖
- `Package.swift`：SwiftPM 開發驗證入口
- `ASR4me/ASR4me.xcodeproj`：正式 macOS app target（團隊開發用）

## 第一次在 Xcode 開發（協作者設定）

### 建議開啟方式

1. 用 Xcode 開啟 `ASR4me/ASR4me.xcodeproj`（正式 app target）
2. Scheme 選 `ASR4me`
3. Destination 選 `My Mac`

### 必要 Build Settings（請確認）

在 `TARGETS > ASR4me > Build Settings`：

- `Generate Info.plist File` = `No`
- `Info.plist File` = `../Config/ASR4me-Info.plist`
- `Code Signing Entitlements` = `../Config/ASR4me.entitlements`

說明：
- `ASR4me.xcodeproj` 位於 `ASR4me/` 子資料夾，因此 `Config` 路徑要用 `../Config/...`

### Base Configuration（可選但建議）

在 `Project/Target > Info > Configurations`：

- `Debug` -> `../Config/ASR4me.xcconfig`
- `Release` -> `../Config/ASR4me.xcconfig`

如果你用 `xcconfig`，仍請確認上面的 `Info.plist` / entitlements 路徑沒有被錯誤覆蓋。

### Build Phases 踩雷排除（很重要）

在 `TARGETS > ASR4me > Build Phases > Copy Bundle Resources`：

- `不要`包含 `ASR4me-Info.plist`

若看到以下警告，代表 `Info.plist` 被錯誤加入 resources：

- `The Copy Bundle Resources build phase contains this target's Info.plist file ...`

處理方式：在 `Copy Bundle Resources` 中刪除 `ASR4me-Info.plist`。

### 如果跑起來是 Hello World（模板畫面）

代表 Xcode 還在編譯模板入口，而不是 `Sources/ASR4me` 的程式碼。

請確認：

- 模板 `ASR4meApp.swift`（Xcode 新建專案產生的）取消 `Target Membership`
- 模板 `ContentView.swift` 取消 `Target Membership`
- `Sources/ASR4me/ASR4meApp.swift` 有勾 `Target Membership: ASR4me`

## 新增/修改檔案時（團隊協作注意）

因為目前 Xcode 專案使用 `groups` 參考檔案，新檔案不一定會自動出現在 `.xcodeproj` 中。

如果你或其他協作者新增了 `.swift` 檔案（例如 service / view）：

1. 把新檔案拖進對應 Xcode 群組
2. 選 `Reference files in place`
3. `Add to targets` 勾 `ASR4me`
4. 確認右側 `Target Membership` 已勾 `ASR4me`

若出現 `Cannot find 'SomeType' in scope`，常見原因就是新檔案尚未加入 Xcode target。

## 執行與權限（第一次）

### App 權限

- 麥克風（必須）
- 輔助使用 Accessibility（只有啟用「Auto paste to current cursor」才需要）

若啟用自動貼上模式，請到：

- `System Settings > Privacy & Security > Accessibility`

將 `ASR4me` 加入允許。

### App 內設定（第一次）

- 在設定頁填入 OpenAI API Key（存 Keychain）
- 指定 `whisper.cpp` binary path
  - Apple Silicon 建議：`/opt/homebrew/bin/whisper-cli`
  - Intel 常見：`/usr/local/bin/whisper-cli`
- 下載本機模型（`base` / `small`）
- 需要持久化時按 `Save Settings`

## 開發模式與驗證

### SwiftPM（快速驗證編譯）

```bash
swift build --disable-sandbox
```

### Xcode（實際 app 流程驗證）

- 用 `ASR4me` target 在 Xcode `Run`
- 成功後會是 menu bar app（右上角圖示），不是一般主視窗 app

## 目前功能（設定模式）

- `Quick copy mode (no result window)`：
  - 錄音後自動做拼字修正並輸出（剪貼簿 / 若開啟 auto paste 則貼到游標）
- `Auto paste to current cursor`：
  - 錄音後把文字貼到目前焦點游標（需 Accessibility）
- `Spelling Fix Customization`：
  - 個人化專有名詞/人名/用語偏好，會套用在 LLM 的拼字修正 prompt

## App Icon

### 更換圖示

1. 將你的 icon 圖片放在專案根目錄，命名為 `icon.png`（建議 1024×1024 以上）
2. 執行：

```bash
./Scripts/generate-icon.sh
```

此腳本會自動：
- 產生所有 macOS 需要的尺寸（16×16 ~ 1024×1024，含 @2x）
- 輸出 `Resources/AppIcon.icns`
- 將各尺寸 PNG 複製到 `ASR4me/ASR4me/Assets.xcassets/AppIcon.appiconset/`
- 更新 `Contents.json` 參照

Xcode build 時會自動從 Assets.xcassets 讀取 AppIcon 並打包進 `.app`。

### 檔案說明

| 檔案 | 用途 |
|------|------|
| `icon.png` | 原始圖示（手動放置） |
| `Resources/AppIcon.icns` | macOS 圖示格式（由腳本產生） |
| `Resources/AppIcon.iconset/` | 各尺寸 PNG 暫存（由腳本產生） |
| `Scripts/generate-icon.sh` | 圖示產生腳本 |

## 打包成 DMG

### 前置準備

1. 確認已在 Xcode 中設定好 `ASR4me` scheme（參考上方「第一次在 Xcode 開發」）
2. 確認 `icon.png` 已轉換（參考上方「App Icon」）
3. 產生 DMG 背景圖（可選，已有預設背景）：

```bash
python3 Scripts/generate-background.py
```

4. 若無 Apple Developer ID 簽署，修改 `Scripts/exportOptions.plist`：
   - `method` 改為 `development`

### 一鍵打包

```bash
./Scripts/create-dmg.sh
```

腳本會自動依序執行：

1. **Archive** - 以 Release configuration 封存
2. **Export** - 匯出 `.app`
3. **準備內容** - 複製 app + 建立 `/Applications` 替身
4. **掛載暫存 DMG** - 建立可讀寫暫存映像檔
5. **設定佈局** - 透過 AppleScript 設定 Finder 視窗大小、圖示位置、背景圖
6. **產出最終 DMG** - 壓縮輸出到 `build/ASR4me.dmg`

### 客製化 DMG 外觀

- **背景圖**：替換 `Resources/dmg-background.png`（建議 660×400），或修改 `Scripts/generate-background.py`
- **圖示位置**：修改 `Scripts/create-dmg.sh` 中的 `set position of item` 座標
- **視窗大小**：修改 `Scripts/create-dmg.sh` 中的 `set the bounds` 數值

### DMG 使用者體驗

使用者雙擊 `.dmg` 後會看到客製化視窗：
- 左側：`ASR4me.app` 圖示
- 右側：`Applications` 資料夾替身
- 底部：提示文字「將 ASR4me 拖曳到 Applications 資料夾」
- 直接拖曳 app 到 Applications 即可完成安裝
