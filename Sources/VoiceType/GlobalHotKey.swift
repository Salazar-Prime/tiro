import Carbon

@MainActor
final class GlobalHotKey {
    private static let signature: OSType = 0x56545950 // VTYP

    private let identifier: UInt32
    private let keyCode: UInt32
    private let modifiers: UInt32
    private let action: () -> Void
    private let releaseAction: (() -> Void)?
    private var hotKeyReference: EventHotKeyRef?
    private var eventHandlerReference: EventHandlerRef?

    init(
        identifier: UInt32,
        keyCode: UInt32,
        modifiers: UInt32,
        action: @escaping () -> Void,
        releaseAction: (() -> Void)? = nil
    ) {
        self.identifier = identifier
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.action = action
        self.releaseAction = releaseAction
    }

    @discardableResult
    func register() -> Bool {
        guard hotKeyReference == nil, eventHandlerReference == nil else { return true }

        var eventTypes = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
        ]
        if releaseAction != nil {
            eventTypes.append(
                EventTypeSpec(
                    eventClass: OSType(kEventClassKeyboard),
                    eventKind: UInt32(kEventHotKeyReleased)
                )
            )
        }
        let context = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = eventTypes.withUnsafeBufferPointer { eventTypes in
            InstallEventHandler(
                GetApplicationEventTarget(),
                { _, event, userData in
                    guard let event, let userData else {
                        return OSStatus(eventNotHandledErr)
                    }

                    var hotKeyID = EventHotKeyID()
                    let parameterStatus = GetEventParameter(
                        event,
                        EventParamName(kEventParamDirectObject),
                        EventParamType(typeEventHotKeyID),
                        nil,
                        MemoryLayout<EventHotKeyID>.size,
                        nil,
                        &hotKeyID
                    )
                    guard parameterStatus == noErr,
                          hotKeyID.signature == GlobalHotKey.signature
                    else {
                        return OSStatus(eventNotHandledErr)
                    }

                    let hotKey = Unmanaged<GlobalHotKey>
                        .fromOpaque(userData)
                        .takeUnretainedValue()
                    guard hotKeyID.id == hotKey.identifier else {
                        return OSStatus(eventNotHandledErr)
                    }

                    MainActor.assumeIsolated {
                        if GetEventKind(event) == UInt32(kEventHotKeyReleased) {
                            hotKey.releaseAction?()
                        } else {
                            hotKey.action()
                        }
                    }
                    return noErr
                },
                eventTypes.count,
                eventTypes.baseAddress,
                context,
                &eventHandlerReference
            )
        }
        guard handlerStatus == noErr else {
            eventHandlerReference = nil
            return false
        }

        let hotKeyID = EventHotKeyID(
            signature: Self.signature,
            id: identifier
        )
        let registrationStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyReference
        )
        guard registrationStatus == noErr else {
            if let eventHandlerReference {
                RemoveEventHandler(eventHandlerReference)
            }
            eventHandlerReference = nil
            hotKeyReference = nil
            return false
        }
        return true
    }

    func unregister() {
        if let hotKeyReference {
            UnregisterEventHotKey(hotKeyReference)
        }
        if let eventHandlerReference {
            RemoveEventHandler(eventHandlerReference)
        }
        hotKeyReference = nil
        eventHandlerReference = nil
    }
}
