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

## 專案結構（協作重點）

- `Sources/ASR4me/`：主要 app 程式碼（App / Core / Services / UI）
- `Config/`：`Info.plist`、entitlements、xcconfig（Xcode target 需引用）
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
