#!/usr/bin/env python3
"""
產生 DMG 背景圖（660x400），淺灰漸層 + 箭頭提示拖曳到 Applications。
需要 macOS 內建的 Python 3（無額外依賴）。
"""

import subprocess
import os

W, H = 660, 400
output_path = os.path.join(os.path.dirname(__file__), "..", "Resources", "dmg-background.png")
os.makedirs(os.path.dirname(output_path), exist_ok=True)

# 使用 CoreGraphics 透過 Swift 產生圖片（macOS 內建）
swift_code = '''
import Cocoa

let w = 660
let h = 400
let image = NSImage(size: NSSize(width: w, height: h))

image.lockFocus()

// 背景漸層（淺灰）
let gradient = NSGradient(
    colors: [
        NSColor(white: 0.96, alpha: 1.0),
        NSColor(white: 0.90, alpha: 1.0)
    ],
    atLocations: [0.0, 1.0],
    colorSpace: .genericGray
)
gradient?.draw(in: NSRect(x: 0, y: 0, width: w, height: h), angle: -90)

// 提示文字
let paragraphStyle = NSMutableParagraphStyle()
paragraphStyle.alignment = .center

let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 14),
    .foregroundColor: NSColor(white: 0.5, alpha: 1.0),
    .paragraphStyle: paragraphStyle
]

let text = "將 ASR4me 拖曳到 Applications 資料夾"
text.draw(in: NSRect(x: 0, y: 60, width: w, height: 20), withAttributes: attrs)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    print("ERROR")
    exit(1)
}

let path = CommandLine.arguments[1]
try png.write(to: URL(fileURLWithPath: path))
print("OK")
'''

with open("/tmp/gen_bg.swift", "w") as f:
    f.write(swift_code)

result = subprocess.run(
    ["swift", "/tmp/gen_bg.swift", output_path],
    capture_output=True, text=True
)

os.remove("/tmp/gen_bg.swift")

if "OK" in result.stdout:
    print(f"✅ 背景圖已產生: {output_path}")
else:
    print(f"❌ 產生失敗: {result.stderr}")
    exit(1)
