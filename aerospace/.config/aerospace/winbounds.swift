import AppKit
import CoreGraphics
import Foundation

struct Options {
    var useVisibleFrame = true
    var epsilon: CGFloat = 1
    var verbose = false
    var dump = false
}

func usage() {
    let msg = """
    usage: aerospace list-windows ... | winbounds [--visible|--frame] [--epsilon N] [--verbose] [--dump]

    Reads window IDs from stdin (whitespace-delimited; newline-delimited works).

    Flags:
      --visible   Compare against visibleFrame (default)
      --frame     Compare against full screen frame
      --epsilon N Tolerance in points (default: 1)
      --verbose   Print parse/lookup warnings to stderr
      --dump      Print per-window geometry and edge checks to stdout (JSONL)

    Exit codes:
      0 = ALL windows are non-touching
      1 = at least one window touches an edge OR any error occurred (parse/not found/etc.)
      2 = usage / no valid window IDs on stdin
    """
    fputs(msg + "\n", stderr)
}

func parseArgs(_ args: [String]) -> Options? {
    var o = Options()
    var i = 1
    while i < args.count {
        switch args[i] {
        case "--visible": o.useVisibleFrame = true; i += 1
        case "--frame":   o.useVisibleFrame = false; i += 1
        case "--verbose": o.verbose = true; i += 1
        case "--dump":    o.dump = true; i += 1
        case "--epsilon":
            guard i + 1 < args.count, let v = Double(args[i + 1]) else { return nil }
            o.epsilon = CGFloat(v)
            i += 2
        case "-h", "--help":
            return nil
        default:
            return nil
        }
    }
    return o
}

func rectDict(_ r: CGRect) -> [String: Double] {
    ["x": Double(r.origin.x), "y": Double(r.origin.y), "w": Double(r.size.width), "h": Double(r.size.height)]
}

// MARK: - Quartz/AppKit helpers

func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
    (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)
        .map { CGDirectDisplayID($0.uint32Value) }
}

func quartzDisplayBounds(for screen: NSScreen) -> CGRect? {
    guard let did = displayID(for: screen) else { return nil }
    return CGDisplayBounds(did) // Quartz global coordinates
}

/// Convert an AppKit global rect (for `screen.frame` / `screen.visibleFrame`) into Quartz global coordinates.
func appKitRectToQuartz(_ r: CGRect, on screen: NSScreen) -> CGRect? {
    guard let did = displayID(for: screen) else { return nil }
    let db = CGDisplayBounds(did) // Quartz/global bounds for that display
    let sf = screen.frame         // AppKit/global frame for that screen

    // Local offset inside the screen in AppKit coords
    let localX = r.minX - sf.minX
    let localY = r.minY - sf.minY

    // Flip Y within the display: AppKit y-up -> Quartz y-down
    let qx = db.minX + localX
    let qy = db.minY + (sf.height - localY - r.height)

    return CGRect(x: qx, y: qy, width: r.width, height: r.height)
}

/// Choose the NSScreen whose Quartz display bounds contains the window center (window bounds are Quartz coords).
func screenForQuartzWindowRect(_ w: CGRect) -> (screen: NSScreen, index: Int, displayBoundsQ: CGRect)? {
    let center = CGPoint(x: w.midX, y: w.midY)

    for (idx, s) in NSScreen.screens.enumerated() {
        if let db = quartzDisplayBounds(for: s), db.contains(center) {
            return (s, idx, db)
        }
    }

    // Fallback: main screen if we can't match (still better than failing hard)
    if let main = NSScreen.main, let db = quartzDisplayBounds(for: main) {
        let idx = NSScreen.screens.firstIndex(of: main) ?? 0
        return (main, idx, db)
    }
    return nil
}

// MARK: - Window bounds (Quartz)

func windowBoundsQuartz(_ windowID: CGWindowID) -> CGRect? {
    let opts: CGWindowListOption = [.optionIncludingWindow, .excludeDesktopElements]
    guard
        let list = CGWindowListCopyWindowInfo(opts, windowID) as? [[String: Any]],
        let info = list.first,
        let b = info[kCGWindowBounds as String] as? [String: Any],
        let rect = CGRect(dictionaryRepresentation: b as CFDictionary)
    else { return nil }
    return rect
}

func touchesEdgesQuartz(window w: CGRect, screen s: CGRect, eps: CGFloat) -> (left: Bool, right: Bool, top: Bool, bottom: Bool, any: Bool) {
    // In Quartz (y-down): "top edge" is minY, "bottom edge" is maxY.
    let left = w.minX <= s.minX + eps
    let right = w.maxX >= s.maxX - eps
    let top = w.minY <= s.minY + eps
    let bottom = w.maxY >= s.maxY - eps
    let any = left || right || top || bottom
    return (left, right, top, bottom, any)
}

// MARK: - stdin parsing

func readWindowIDsFromStdin(verbose: Bool) -> [CGWindowID] {
    let data = FileHandle.standardInput.readDataToEndOfFile()
    if data.isEmpty { return [] }

    var text = String(decoding: data, as: UTF8.self)
    if text.first == "\u{FEFF}" { text.removeFirst() } // strip UTF-8 BOM

    let tokens = text.split(whereSeparator: { $0.isWhitespace })
    var ids: [CGWindowID] = []
    ids.reserveCapacity(tokens.count)

    for tSub in tokens {
        let t = String(tSub)
        if let v = UInt32(t) {
            ids.append(CGWindowID(v))
        } else if verbose {
            fputs("winbounds: skipping non-numeric token from stdin: \(t.debugDescription)\n", stderr)
        }
    }
    return ids
}

// MARK: - main

guard let options = parseArgs(CommandLine.arguments) else {
    usage()
    exit(2)
}

// Helps ensure NSScreen is initialized in a CLI context
_ = NSApplication.shared

let ids = readWindowIDsFromStdin(verbose: options.verbose)
guard !ids.isEmpty else {
    usage()
    exit(2)
}

var anyProblem = false

for id in ids {
    guard let wQ = windowBoundsQuartz(id) else {
        anyProblem = true
        if options.verbose { fputs("winbounds: could not find bounds for window \(id)\n", stderr) }
        if options.dump {
            let out: [String: Any] = ["windowId": Int(id), "error": "bounds_not_found"]
            let data = try JSONSerialization.data(withJSONObject: out, options: [.sortedKeys])
            print(String(data: data, encoding: .utf8)!)
        }
        continue
    }

    guard let pick = screenForQuartzWindowRect(wQ) else {
        anyProblem = true
        if options.verbose { fputs("winbounds: could not determine screen for window \(id)\n", stderr) }
        if options.dump {
            let out: [String: Any] = ["windowId": Int(id), "boundsQuartz": rectDict(wQ), "error": "screen_not_found"]
            let data = try JSONSerialization.data(withJSONObject: out, options: [.sortedKeys])
            print(String(data: data, encoding: .utf8)!)
        }
        continue
    }

    let screen = pick.screen
    let screenFrameA = screen.frame
    let screenVisibleA = screen.visibleFrame

    let usedA = options.useVisibleFrame ? screenVisibleA : screenFrameA
    guard let usedQ = appKitRectToQuartz(usedA, on: screen) else {
        anyProblem = true
        if options.verbose { fputs("winbounds: could not convert screen rect to quartz for window \(id)\n", stderr) }
        if options.dump {
            let out: [String: Any] = [
                "windowId": Int(id),
                "boundsQuartz": rectDict(wQ),
                "error": "screen_rect_convert_failed"
            ]
            let data = try JSONSerialization.data(withJSONObject: out, options: [.sortedKeys])
            print(String(data: data, encoding: .utf8)!)
        }
        continue
    }

    let t = touchesEdgesQuartz(window: wQ, screen: usedQ, eps: options.epsilon)
    if t.any { anyProblem = true }

    if options.dump {
        let out: [String: Any] = [
            "windowId": Int(id),

            // Window bounds (Quartz)
            "boundsQuartz": rectDict(wQ),

            // Screen selection
            "screenIndex": pick.index,

            // Raw AppKit screen rects (for sanity)
            "screenFrameAppKit": rectDict(screenFrameA),
            "screenVisibleFrameAppKit": rectDict(screenVisibleA),

            // Quartz display bounds (physical monitor rect in Quartz coords)
            "displayBoundsQuartz": rectDict(pick.displayBoundsQ),

            // What we actually used for edge checks, converted to Quartz
            "using": options.useVisibleFrame ? "visibleFrame" : "frame",
            "screenUsedQuartz": rectDict(usedQ),

            "epsilon": Double(options.epsilon),
            "touches": [
                "left": t.left,
                "right": t.right,
                "top": t.top,
                "bottom": t.bottom,
                "any": t.any
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: out, options: [.sortedKeys])
        print(String(data: data, encoding: .utf8)!) // JSONL
    }
}

exit(anyProblem ? 1 : 0)
