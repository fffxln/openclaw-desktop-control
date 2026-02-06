import Foundation
import AppKit
import ScreenCaptureKit
import CoreGraphics
import UniformTypeIdentifiers

/// Desktop Control Helper - TCC-privileged wrapper for desktop automation
/// Uses ScreenCaptureKit directly for screen capture so TCC permissions are checked
/// against this .app bundle, not the parent terminal process.

func main() {
    let args = Array(CommandLine.arguments.dropFirst())

    guard !args.isEmpty else {
        printUsage()
        exit(1)
    }

    let command = args[0]
    let commandArgs = Array(args.dropFirst())

    switch command {
    case "screencapture":
        executeScreenCapture(args: commandArgs)
    case "cliclick":
        executeCliClick(args: commandArgs)
    case "check-permissions":
        checkPermissions()
    case "request-permission":
        requestPermissions()
    case "get-scale-factor":
        getScaleFactor(args: commandArgs)
    case "help", "--help", "-h":
        printUsage()
        exit(0)
    default:
        print("Error: Unknown command '\(command)'")
        printUsage()
        exit(1)
    }
}

// MARK: - Helpers

/// Wait on a semaphore while keeping the RunLoop alive, with a timeout.
/// Returns true if signaled, false if timed out.
func waitWithRunLoop(semaphore: DispatchSemaphore, timeoutSeconds: Double) -> Bool {
    let deadline = Date(timeIntervalSinceNow: timeoutSeconds)
    while semaphore.wait(timeout: .now()) == .timedOut {
        if Date() > deadline {
            return false
        }
        RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
    }
    return true
}

/// Get the backing scale factor for a given SCDisplay by matching to NSScreen.
func scaleFactor(for display: SCDisplay) -> Int {
    for screen in NSScreen.screens {
        if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? Int,
           UInt32(screenNumber) == display.displayID {
            return Int(screen.backingScaleFactor)
        }
    }
    return 2 // safe default for Retina
}

/// Resolve cliclick binary path. Checks: bundled → which → common brew paths.
func resolveCliClickPath() -> String? {
    let bundled = "\(NSHomeDirectory())/.openclaw/bin/cliclick"
    if FileManager.default.fileExists(atPath: bundled) {
        return bundled
    }

    // Try `which cliclick`
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    task.arguments = ["cliclick"]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = Pipe()
    do {
        try task.run()
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
                return path
            }
        }
    } catch {}

    // Fallback to common paths
    for path in ["/opt/homebrew/bin/cliclick", "/usr/local/bin/cliclick"] {
        if FileManager.default.fileExists(atPath: path) {
            return path
        }
    }
    return nil
}

// MARK: - Screen Capture (ScreenCaptureKit)

func executeScreenCapture(args: [String]) {
    // Parse arguments: support -x (silent), -D <display>, -R <x,y,w,h>, and output path
    var displayIndex: Int? = nil
    var region: CGRect? = nil
    var outputPath: String? = nil
    var i = 0

    while i < args.count {
        switch args[i] {
        case "-x":
            // Silent mode — no-op, we're always silent
            break
        case "-D":
            i += 1
            if i < args.count, let d = Int(args[i]) {
                displayIndex = d
            } else {
                print("Error: -D requires a display number")
                exit(1)
            }
        case "-R":
            i += 1
            if i < args.count {
                let parts = args[i].split(separator: ",").compactMap { Double($0) }
                if parts.count == 4 {
                    region = CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
                } else {
                    print("Error: -R requires x,y,w,h format")
                    exit(1)
                }
            } else {
                print("Error: -R requires coordinates")
                exit(1)
            }
        default:
            // Treat as output path (last non-flag argument)
            if !args[i].hasPrefix("-") {
                outputPath = args[i]
            }
        }
        i += 1
    }

    guard let path = outputPath else {
        print("Error: No output file path specified")
        print("Usage: screencapture [-x] [-D display] [-R x,y,w,h] <output.png>")
        exit(1)
    }

    // Validate output path — check parent directory exists
    let parentDir = (path as NSString).deletingLastPathComponent
    if !parentDir.isEmpty {
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: parentDir, isDirectory: &isDir) || !isDir.boolValue {
            print("Error: Directory does not exist: \(parentDir)")
            print("Create it first or choose a different output path.")
            exit(1)
        }
    }

    // Run the async capture on the main run loop
    let semaphore = DispatchSemaphore(value: 0)
    var captureError: Error? = nil

    Task {
        do {
            try await captureScreen(displayIndex: displayIndex, region: region, outputPath: path)
        } catch {
            captureError = error
        }
        semaphore.signal()
    }

    if !waitWithRunLoop(semaphore: semaphore, timeoutSeconds: 10.0) {
        print("Error: Screen capture timed out after 10 seconds.")
        print("This usually means Screen Recording permission is not granted.")
        print("Fix: Open System Settings > Privacy & Security > Screen Recording > Enable DesktopControlHelper")
        exit(1)
    }

    if let error = captureError {
        let desc = error.localizedDescription
        if desc.contains("permission") || desc.contains("not authorized") {
            print("Error: Screen Recording permission is not granted.")
            print("Fix: Open System Settings > Privacy & Security > Screen Recording > Enable DesktopControlHelper")
        } else {
            print("Error: \(desc)")
        }
        print("Or run: \(CommandLine.arguments[0]) request-permission")
        exit(1)
    }

    exit(0)
}

func captureScreen(displayIndex: Int?, region: CGRect?, outputPath: String) async throws {
    // Get shareable content (displays, windows, apps)
    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

    let displays = content.displays
    guard !displays.isEmpty else {
        throw NSError(domain: "DesktopControlHelper", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "No displays detected. If you are using a headless Mac, connect a display or use a virtual display adapter."])
    }

    // Select target display
    let targetDisplay: SCDisplay
    if let idx = displayIndex {
        let arrayIdx = idx - 1 // 1-based to 0-based
        guard arrayIdx >= 0 && arrayIdx < displays.count else {
            throw NSError(domain: "DesktopControlHelper", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Display \(idx) not found. You have \(displays.count) display(s). Use -D 1 through -D \(displays.count)."])
        }
        targetDisplay = displays[arrayIdx]
    } else {
        // Use the main display (first one)
        targetDisplay = displays[0]
    }

    // Configure capture with dynamic scale factor
    let scale = scaleFactor(for: targetDisplay)
    let filter = SCContentFilter(display: targetDisplay, excludingWindows: [])
    let config = SCStreamConfiguration()
    config.width = Int(targetDisplay.width) * scale
    config.height = Int(targetDisplay.height) * scale
    config.showsCursor = false
    config.capturesAudio = false

    // If region specified, adjust source rect
    if let region = region {
        config.sourceRect = region
        config.width = Int(region.width) * scale
        config.height = Int(region.height) * scale
    }

    // Capture a single screenshot
    let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

    // Save as PNG
    let url = URL(fileURLWithPath: outputPath)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "DesktopControlHelper", code: 3,
                      userInfo: [NSLocalizedDescriptionKey: "Could not create image file at \(outputPath). Check that the directory exists and you have write permission."])
    }
    CGImageDestinationAddImage(destination, image, nil)

    if !CGImageDestinationFinalize(destination) {
        throw NSError(domain: "DesktopControlHelper", code: 4,
                      userInfo: [NSLocalizedDescriptionKey: "Failed to write screenshot to \(outputPath). The disk may be full or the path may not be writable."])
    }
}

// MARK: - cliclick

func executeCliClick(args: [String]) {
    guard let cliclickPath = resolveCliClickPath() else {
        print("Error: cliclick not found.")
        print("cliclick is required for mouse and keyboard control.")
        print("Install with: brew install cliclick")
        exit(1)
    }

    let task = Process()
    task.executableURL = URL(fileURLWithPath: cliclickPath)
    task.arguments = args

    do {
        try task.run()
        task.waitUntilExit()
        exit(task.terminationStatus)
    } catch {
        print("Error running cliclick at \(cliclickPath): \(error.localizedDescription)")
        exit(1)
    }
}

// MARK: - Permission checks

func checkPermissions() {
    var allGranted = true

    // Check Screen Recording permission using ScreenCaptureKit
    let screenRecordingGranted = checkScreenRecording()
    if screenRecordingGranted {
        print("✅ Screen Recording permission granted")
    } else {
        print("❌ Screen Recording permission NOT granted")
        allGranted = false
    }

    // Check Accessibility permission
    let accessibilityGranted = checkAccessibility()
    if accessibilityGranted {
        print("✅ Accessibility permission granted")
    } else {
        print("❌ Accessibility permission NOT granted")
        allGranted = false
    }

    if !allGranted {
        print("\nTo grant permissions:")
        print("  System Settings → Privacy & Security → Screen Recording/Accessibility")
        print("  Enable: DesktopControlHelper")
        print("\nOr run: \(CommandLine.arguments[0]) request-permission")
    }

    exit(allGranted ? 0 : 1)
}

func checkScreenRecording() -> Bool {
    let semaphore = DispatchSemaphore(value: 0)
    var granted = false

    Task {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            granted = !content.displays.isEmpty
        } catch {
            granted = false
        }
        semaphore.signal()
    }

    if !waitWithRunLoop(semaphore: semaphore, timeoutSeconds: 5.0) {
        return false
    }

    return granted
}

func checkAccessibility() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
    return AXIsProcessTrustedWithOptions(options as CFDictionary)
}

// MARK: - Request permissions

func requestPermissions() {
    print("Opening System Settings to grant permissions...")
    print("\nPlease enable:")
    print("  1. Privacy & Security → Screen Recording → DesktopControlHelper")
    print("  2. Privacy & Security → Accessibility → DesktopControlHelper")
    print("\nAfter enabling, you may need to restart the OpenClaw gateway:")
    print("  openclaw gateway restart")

    if #available(macOS 13.0, *) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    } else {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security")!)
    }

    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    _ = AXIsProcessTrustedWithOptions(options as CFDictionary)

    exit(0)
}

// MARK: - Scale Factor

func getScaleFactor(args: [String]) {
    let semaphore = DispatchSemaphore(value: 0)
    var result: Int = 2
    var displayIndex: Int? = nil

    // Parse optional -D flag
    if args.count >= 2, args[0] == "-D", let d = Int(args[1]) {
        displayIndex = d
    }

    Task {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let displays = content.displays
            if !displays.isEmpty {
                let target: SCDisplay
                if let idx = displayIndex, idx >= 1, idx <= displays.count {
                    target = displays[idx - 1]
                } else {
                    target = displays[0]
                }
                result = scaleFactor(for: target)
            }
        } catch {}
        semaphore.signal()
    }

    if !waitWithRunLoop(semaphore: semaphore, timeoutSeconds: 5.0) {
        print("2") // safe default
        exit(0)
    }

    print("\(result)")
    exit(0)
}

// MARK: - Usage

func printUsage() {
    print("""
    Desktop Control Helper - TCC-privileged wrapper for desktop automation

    Usage:
      \(CommandLine.arguments[0]) <command> [args...]

    Commands:
      screencapture [args]    Capture screen using ScreenCaptureKit (native)
      cliclick [args]         Execute cliclick with given arguments
      check-permissions       Verify Screen Recording and Accessibility permissions
      request-permission      Open System Settings to grant permissions
      get-scale-factor [-D n] Print the display's backing scale factor (1, 2, or 3)
      help                    Show this help message

    Screencapture options:
      -x                      Silent mode (default, no-op)
      -D <display>            Capture specific display (1-based index)
      -R <x,y,w,h>            Capture specific region
      <output.png>            Output file path

    Examples:
      \(CommandLine.arguments[0]) screencapture -x /tmp/screen.png
      \(CommandLine.arguments[0]) screencapture -D 1 /tmp/screen.png
      \(CommandLine.arguments[0]) screencapture -R 0,0,800,600 /tmp/region.png
      \(CommandLine.arguments[0]) cliclick c:500,300
      \(CommandLine.arguments[0]) check-permissions
      \(CommandLine.arguments[0]) get-scale-factor
    """)
}

main()
