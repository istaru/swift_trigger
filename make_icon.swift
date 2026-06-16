#!/usr/bin/swift
import AppKit
import Foundation

func makeIconPNG(size: Int) -> Data? {
    let s = CGFloat(size)

    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let cgCtx = CGContext(
            data: nil, width: size, height: size,
            bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ) else { return nil }

    let nsCtx = NSGraphicsContext(cgContext: cgCtx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx

    cgCtx.clear(CGRect(x: 0, y: 0, width: s, height: s))

    // 圆角裁切
    let radius = s * 0.22
    let clipPath = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: s, height: s),
                                xRadius: radius, yRadius: radius)
    clipPath.setClip()

    // 蓝紫渐变背景
    if let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.18, green: 0.42, blue: 0.95, alpha: 1.0),
        NSColor(srgbRed: 0.55, green: 0.25, blue: 0.92, alpha: 1.0)
    ]) {
        gradient.draw(in: NSRect(x: 0, y: 0, width: s, height: s), angle: 315)
    }

    // SF Symbol (square.on.square)
    let ptSize = s * 0.44
    let config = NSImage.SymbolConfiguration(pointSize: ptSize, weight: .semibold)
    if let sym = NSImage(systemSymbolName: "square.on.square", accessibilityDescription: nil)?
                     .withSymbolConfiguration(config) {
        let symW = sym.size.width
        let symH = sym.size.height
        let symX = (s - symW) / 2
        let symY = (s - symH) / 2
        sym.draw(in: NSRect(x: symX, y: symY, width: symW, height: symH),
                 from: .zero, operation: .sourceOver, fraction: 1.0)
        // 染白
        cgCtx.setBlendMode(.sourceAtop)
        cgCtx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        cgCtx.fill(CGRect(x: symX, y: symY, width: symW, height: symH))
        cgCtx.setBlendMode(.normal)
    }

    NSGraphicsContext.restoreGraphicsState()

    guard let cgImage = cgCtx.makeImage() else { return nil }
    return NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
}

let iconsetDir = "/tmp/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let files: [(String, Int)] = [
    ("icon_16x16.png",      16),
    ("icon_16x16@2x.png",   32),
    ("icon_32x32.png",      32),
    ("icon_32x32@2x.png",   64),
    ("icon_128x128.png",   128),
    ("icon_128x128@2x.png",256),
    ("icon_256x256.png",   256),
    ("icon_256x256@2x.png",512),
    ("icon_512x512.png",   512),
    ("icon_512x512@2x.png",1024),
]

for (filename, px) in files {
    if let data = makeIconPNG(size: px) {
        try? data.write(to: URL(fileURLWithPath: "\(iconsetDir)/\(filename)"))
        print("✓ \(filename) (\(px)px)")
    } else {
        print("✗ 失败: \(filename)")
    }
}
print("图标生成完毕")
