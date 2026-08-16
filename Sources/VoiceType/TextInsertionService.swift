import AppKit
import ApplicationServices
import Foundation
import OSLog

private let insertionLogger = Logger(
    subsystem: "com.salazarprime.VoiceType",
    category: "TextInsertion"
)

@MainActor
enum TextInsertionService {
    private static let browserBundleIdentifiers: Set<String> = [
        "com.apple.Safari",
        "com.brave.Browser",
        "com.google.Chrome",
        "com.microsoft.edgemac",
        "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi",
        "company.thebrowser.Browser",
        "org.mozilla.firefox"
    ]

    enum Result: Equatable {
        case insertedDirectly
        case pasteCommandSent
        case accessibilityUnavailable
        case noActiveTarget
        case failed
    }

    static func captureTargetPID() -> pid_t? {
        guard let application = NSWorkspace.shared.frontmostApplication,
              application.bundleIdentifier != Bundle.main.bundleIdentifier
        else { return nil }
        return application.processIdentifier
    }

    static func insert(_ text: String) async -> Result {
        guard AXIsProcessTrusted() else { return .accessibilityUnavailable }
        guard let activePID = captureTargetPID() else { return .noActiveTarget }
        if !prefersPasteCommand(for: activePID),
           let element = focusedElement(in: activePID),
           replaceFocusedSelection(in: element, with: text) {
            insertionLogger.info("Inserted directly into process \(activePID, privacy: .public)")
            return .insertedDirectly
        }
        return await PasteboardBridge.shared.paste(text, targetPID: activePID)
            ? .pasteCommandSent
            : .failed
    }

    static func insertImage(at fileURL: URL, targetPID: pid_t) async -> Result {
        guard AXIsProcessTrusted() else { return .accessibilityUnavailable }
        guard let application = NSRunningApplication(processIdentifier: targetPID),
              !application.isTerminated
        else { return .noActiveTarget }

        if !application.isActive {
            _ = application.activate(options: [])
            try? await Task.sleep(for: .milliseconds(140))
        }
        guard captureTargetPID() == targetPID else { return .noActiveTarget }

        return await PasteboardBridge.shared.pasteImage(
            at: fileURL,
            targetPID: targetPID
        ) ? .pasteCommandSent : .failed
    }

    static func copyImage(at fileURL: URL) -> Bool {
        PasteboardBridge.shared.copyImage(at: fileURL)
    }

    private static func prefersPasteCommand(for processID: pid_t) -> Bool {
        guard let bundleIdentifier = NSRunningApplication(
            processIdentifier: processID
        )?.bundleIdentifier else { return false }
        return browserBundleIdentifiers.contains(bundleIdentifier)
    }

    static func performPasteMenuAction(in processID: pid_t) -> Bool {
        let application = AXUIElementCreateApplication(processID)
        guard let menuBar = elementAttribute(
            kAXMenuBarAttribute as String,
            from: application
        ), let pasteItem = findPasteMenuItem(in: menuBar, remainingDepth: 4)
        else { return false }

        return AXUIElementPerformAction(
            pasteItem,
            kAXPressAction as CFString
        ) == .success
    }

    private static func findPasteMenuItem(
        in element: AXUIElement,
        remainingDepth: Int
    ) -> AXUIElement? {
        if stringAttribute(kAXMenuItemCmdCharAttribute as String, from: element)?
            .caseInsensitiveCompare("V") == .orderedSame,
           integerAttribute(kAXMenuItemCmdModifiersAttribute as String, from: element) == 0,
           boolAttribute(kAXEnabledAttribute as String, from: element) == true {
            return element
        }

        guard remainingDepth > 0 else { return nil }
        for child in elementArrayAttribute(kAXChildrenAttribute as String, from: element) {
            if let match = findPasteMenuItem(
                in: child,
                remainingDepth: remainingDepth - 1
            ) {
                return match
            }
        }
        return nil
    }

    private static func elementAttribute(
        _ attribute: String,
        from element: AXUIElement
    ) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        ) == .success,
        let value,
        CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private static func elementArrayAttribute(
        _ attribute: String,
        from element: AXUIElement
    ) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        ) == .success,
        let elements = value as? [AXUIElement]
        else { return [] }
        return elements
    }

    private static func stringAttribute(
        _ attribute: String,
        from element: AXUIElement
    ) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        ) == .success else { return nil }
        return value as? String
    }

    private static func integerAttribute(
        _ attribute: String,
        from element: AXUIElement
    ) -> Int? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        ) == .success else { return nil }
        return (value as? NSNumber)?.intValue
    }

    private static func boolAttribute(
        _ attribute: String,
        from element: AXUIElement
    ) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        ) == .success else { return nil }
        return value as? Bool
    }

    private static func focusedElement(in processID: pid_t) -> AXUIElement? {
        let application = AXUIElementCreateApplication(processID)
        var focusedValue: CFTypeRef?
        let focusedStatus = AXUIElementCopyAttributeValue(
            application,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )
        guard focusedStatus == .success,
              let focusedValue,
              CFGetTypeID(focusedValue) == AXUIElementGetTypeID()
        else { return nil }

        return unsafeDowncast(focusedValue, to: AXUIElement.self)
    }

    private static func replaceFocusedSelection(
        in focused: AXUIElement,
        with text: String
    ) -> Bool {
        var settable = DarwinBoolean(false)
        let settableStatus = AXUIElementIsAttributeSettable(
            focused,
            kAXSelectedTextAttribute as CFString,
            &settable
        )
        if settableStatus == .success, settable.boolValue,
           AXUIElementSetAttributeValue(
               focused,
               kAXSelectedTextAttribute as CFString,
               text as CFTypeRef
           ) == .success {
            return true
        }

        return replaceValueAtSelectedRange(in: focused, with: text)
    }

    private static func replaceValueAtSelectedRange(
        in element: AXUIElement,
        with replacement: String
    ) -> Bool {
        var valueReference: CFTypeRef?
        var rangeReference: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXValueAttribute as CFString,
            &valueReference
        ) == .success,
        let value = valueReference as? String,
        AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeReference
        ) == .success,
        let rangeReference,
        CFGetTypeID(rangeReference) == AXValueGetTypeID()
        else { return false }

        let rangeValue = unsafeDowncast(rangeReference, to: AXValue.self)
        var selectedRange = CFRange()
        guard AXValueGetValue(rangeValue, .cfRange, &selectedRange),
              selectedRange.location >= 0,
              selectedRange.length >= 0,
              selectedRange.location + selectedRange.length <= value.utf16.count
        else { return false }

        var valueSettable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(
            element,
            kAXValueAttribute as CFString,
            &valueSettable
        ) == .success,
        valueSettable.boolValue
        else { return false }

        let updated = (value as NSString).replacingCharacters(
            in: NSRange(location: selectedRange.location, length: selectedRange.length),
            with: replacement
        )
        guard AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            updated as CFTypeRef
        ) == .success else { return false }

        var caretRange = CFRange(
            location: selectedRange.location + replacement.utf16.count,
            length: 0
        )
        if let caretValue = AXValueCreate(.cfRange, &caretRange) {
            _ = AXUIElementSetAttributeValue(
                element,
                kAXSelectedTextRangeAttribute as CFString,
                caretValue
            )
        }
        return true
    }
}

@MainActor
private final class PasteboardBridge {
    static let shared = PasteboardBridge()

    private static let transientType = NSPasteboard.PasteboardType(
        "org.nspasteboard.TransientType"
    )
    private static let autoGeneratedType = NSPasteboard.PasteboardType(
        "org.nspasteboard.AutoGeneratedType"
    )
    private static let sourceType = NSPasteboard.PasteboardType(
        "org.nspasteboard.source"
    )

    private var originalItems: [NSPasteboardItem]?
    private var bridgeChangeCount: Int?
    private var restoreTask: Task<Void, Never>?

    func paste(_ text: String, targetPID: pid_t) async -> Bool {
        let bridgeItem = NSPasteboardItem()
        bridgeItem.setString(text, forType: .string)
        markAsTransient(bridgeItem)
        return await paste(bridgeItem, targetPID: targetPID)
    }

    func pasteImage(at fileURL: URL, targetPID: pid_t) async -> Bool {
        guard let bridgeItem = Self.imageItem(for: fileURL) else { return false }
        markAsTransient(bridgeItem)
        return await paste(bridgeItem, targetPID: targetPID)
    }

    func copyImage(at fileURL: URL) -> Bool {
        guard let item = Self.imageItem(for: fileURL) else { return false }
        markAsTransient(item)
        restoreTask?.cancel()
        originalItems = nil
        bridgeChangeCount = nil
        let pasteboard = NSPasteboard.general
        pasteboard.prepareForNewContents(with: .currentHostOnly)
        return pasteboard.writeObjects([item])
    }

    private func paste(_ bridgeItem: NSPasteboardItem, targetPID: pid_t) async -> Bool {
        let pasteboard = NSPasteboard.general
        if let bridgeChangeCount, pasteboard.changeCount != bridgeChangeCount {
            originalItems = Self.copyItems(from: pasteboard)
        } else if originalItems == nil {
            originalItems = Self.copyItems(from: pasteboard)
        }
        restoreTask?.cancel()

        pasteboard.prepareForNewContents(with: .currentHostOnly)
        guard pasteboard.writeObjects([bridgeItem]) else {
            restorePasteboard(pasteboard)
            return false
        }
        let newBridgeChangeCount = pasteboard.changeCount
        bridgeChangeCount = newBridgeChangeCount

        try? await Task.sleep(for: .milliseconds(60))
        guard pasteboard.changeCount == newBridgeChangeCount,
              TextInsertionService.captureTargetPID() == targetPID else {
            restorePasteboard(pasteboard)
            return false
        }

        guard TextInsertionService.performPasteMenuAction(in: targetPID) else {
            insertionLogger.error("Paste menu action unavailable in process \(targetPID, privacy: .public)")
            restorePasteboard(pasteboard)
            return false
        }
        insertionLogger.info("Invoked Paste menu action in process \(targetPID, privacy: .public)")

        restoreTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1_500))
            guard !Task.isCancelled, let self else { return }
            if pasteboard.changeCount == newBridgeChangeCount {
                restorePasteboard(pasteboard)
            } else {
                originalItems = nil
                bridgeChangeCount = nil
                restoreTask = nil
            }
        }
        return true
    }

    private func markAsTransient(_ item: NSPasteboardItem) {
        item.setData(Data(), forType: Self.transientType)
        item.setData(Data(), forType: Self.autoGeneratedType)
        item.setString(
            Bundle.main.bundleIdentifier ?? "com.salazarprime.VoiceType",
            forType: Self.sourceType
        )
    }

    private func restorePasteboard(_ pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        if let originalItems, !originalItems.isEmpty {
            pasteboard.writeObjects(originalItems)
        }
        originalItems = nil
        bridgeChangeCount = nil
        restoreTask = nil
    }

    private static func copyItems(from pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        pasteboard.pasteboardItems?.map { source in
            let copy = NSPasteboardItem()
            for type in source.types {
                if let data = source.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        } ?? []
    }

    private static func imageItem(for fileURL: URL) -> NSPasteboardItem? {
        guard let pngData = try? Data(contentsOf: fileURL),
              let image = NSImage(data: pngData)
        else { return nil }

        let item = NSPasteboardItem()
        item.setData(pngData, forType: .png)
        if let tiffData = image.tiffRepresentation {
            item.setData(tiffData, forType: .tiff)
        }
        item.setString(fileURL.absoluteString, forType: .fileURL)
        item.setString(fileURL.path, forType: .string)
        return item
    }
}
