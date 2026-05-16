#!/usr/bin/env swift
//
// Generates Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png.
//
// The icon is rendered programmatically (Core Graphics) so the project has
// no binary art files checked in — re-running this script regenerates the
// PNG identically. Run from anywhere, the script resolves paths relative
// to its own location.
//

import AppKit
import CoreGraphics
import Foundation

// MARK: - Output path

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0])
    .standardizedFileURL
let projectRoot = scriptURL
    .deletingLastPathComponent()  // scripts/
    .deletingLastPathComponent()  // apps/ios/
let outPath = projectRoot
    .appendingPathComponent("SearchAssistant/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")

// MARK: - Render

let size = 1024
let bitsPerComponent = 8
let bytesPerRow = size * 4

guard let ctx = CGContext(
    data: nil,
    width: size, height: size,
    bitsPerComponent: bitsPerComponent,
    bytesPerRow: bytesPerRow,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Failed to create CGContext")
}

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r/255, green: g/255, blue: b/255, alpha: a)
}

// Background: emerald gradient (matches AccentColor #10965C, lightened to
// a brighter shade at the top-left so the icon doesn't read flat).
let bgGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        rgb(34, 197, 94),    // emerald-500 top
        rgb(16, 150, 92),    // AccentColor
        rgb(6,  95,  70),    // emerald-900 bottom
    ] as CFArray,
    locations: [0, 0.55, 1]
)!
ctx.drawLinearGradient(
    bgGradient,
    start: CGPoint(x: 0, y: size),
    end: CGPoint(x: size, y: 0),
    options: [])

// Magnifying glass — single centered white glyph. Keeping the icon clean
// and recognizable at every size that iOS scales it down to (Settings,
// Spotlight, notifications). The cross-hair dot in the middle of the lens
// nods at "you are here" without competing with the search metaphor.
let lensCenter = CGPoint(x: 440, y: 560)
let lensRadius: CGFloat = 280
let lensThickness: CGFloat = 80

ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 30,
              color: rgb(0, 0, 0, 0.30))
ctx.setStrokeColor(rgb(255, 255, 255))
ctx.setFillColor(rgb(255, 255, 255))
ctx.setLineCap(.round)

// Lens ring
ctx.setLineWidth(lensThickness)
ctx.addArc(center: lensCenter, radius: lensRadius,
           startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.strokePath()

// Handle — extends down/right from 45° below horizontal.
let handleAngle: CGFloat = -.pi / 4
let handleStart = CGPoint(
    x: lensCenter.x + lensRadius * cos(handleAngle),
    y: lensCenter.y + lensRadius * sin(handleAngle))
let handleEnd = CGPoint(
    x: handleStart.x + 260 * cos(handleAngle),
    y: handleStart.y + 260 * sin(handleAngle))
ctx.move(to: handleStart)
ctx.addLine(to: handleEnd)
ctx.strokePath()

// Center dot inside the lens.
ctx.addArc(center: lensCenter, radius: 56,
           startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.fillPath()

ctx.setShadow(offset: .zero, blur: 0)

// MARK: - Write PNG

guard let cgImage = ctx.makeImage() else { fatalError("No image") }
let rep = NSBitmapImageRep(cgImage: cgImage)
guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("PNG encode failed")
}
try png.write(to: outPath)
print("Wrote \(outPath.path) (\(png.count / 1024) KB)")
