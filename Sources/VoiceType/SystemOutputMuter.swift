import AudioToolbox
import CoreAudio
import Foundation
import MediaControlBridge
import OSLog

@MainActor
final class SystemOutputMuter {
    private enum SavedValue {
        case uint32(UInt32)
        case float32(Float32)
    }

    private struct SavedProperty {
        let deviceID: AudioDeviceID
        let address: AudioObjectPropertyAddress
        let value: SavedValue
    }

    private let logger = Logger(
        subsystem: "com.salazarprime.VoiceType",
        category: "AudioControl"
    )

    private var operationID: UUID?
    private var savedProperties: [SavedProperty] = []
    private var pausedMediaPlayback = false

    func mute() async {
        guard operationID == nil else { return }
        let operationID = UUID()
        self.operationID = operationID

        let playbackState = await Task.detached(priority: .userInitiated) {
            var known = false
            let isPlaying = VTMediaPlaybackIsPlaying(0.35, &known)
            return (known: known, isPlaying: isPlaying)
        }.value

        guard self.operationID == operationID else { return }
        if playbackState.known, playbackState.isPlaying,
           VTMediaPlaybackSendPause() {
            pausedMediaPlayback = true
            logger.info("Paused the active Now Playing session")
        }

        guard let defaultDeviceID = defaultOutputDevice() else {
            logger.error("No default output device was available")
            return
        }

        let deviceIDs = [defaultDeviceID] + activeSubdevices(of: defaultDeviceID)
        for deviceID in Array(Set(deviceIDs)) {
            savedProperties.append(contentsOf: silence(deviceID: deviceID))
        }

        if savedProperties.isEmpty {
            logger.warning("No writable output mute or volume controls were found")
        } else {
            logger.info(
                "Muted \(self.savedProperties.count, privacy: .public) output controls"
            )
        }
    }

    func restore() {
        operationID = nil

        for property in savedProperties.reversed() {
            switch property.value {
            case let .uint32(value):
                _ = writeUInt32(
                    value,
                    deviceID: property.deviceID,
                    address: property.address
                )
            case let .float32(value):
                _ = writeFloat32(
                    value,
                    deviceID: property.deviceID,
                    address: property.address
                )
            }
        }
        savedProperties = []

        if pausedMediaPlayback {
            pausedMediaPlayback = false
            if VTMediaPlaybackSendPlay() {
                logger.info("Resumed the Now Playing session paused by Voice Type")
            } else {
                logger.error("Could not resume the paused Now Playing session")
            }
        }
    }

    private func silence(deviceID: AudioDeviceID) -> [SavedProperty] {
        let muteAddresses = settableAddresses(
            selector: kAudioDevicePropertyMute,
            deviceID: deviceID,
            includeChannels: true
        )
        let savedMutes = muteAddresses.compactMap { address -> SavedProperty? in
            guard let value = readUInt32(deviceID: deviceID, address: address),
                  writeUInt32(1, deviceID: deviceID, address: address)
            else { return nil }
            return SavedProperty(
                deviceID: deviceID,
                address: address,
                value: .uint32(value)
            )
        }
        if !savedMutes.isEmpty {
            return savedMutes
        }

        let virtualVolumeAddress = propertyAddress(
            selector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume
        )
        if isSettable(deviceID: deviceID, address: virtualVolumeAddress),
           let value = readFloat32(deviceID: deviceID, address: virtualVolumeAddress),
           writeFloat32(0, deviceID: deviceID, address: virtualVolumeAddress) {
            return [SavedProperty(
                deviceID: deviceID,
                address: virtualVolumeAddress,
                value: .float32(value)
            )]
        }

        return settableAddresses(
            selector: kAudioDevicePropertyVolumeScalar,
            deviceID: deviceID,
            includeChannels: true
        ).compactMap { address -> SavedProperty? in
            guard let value = readFloat32(deviceID: deviceID, address: address),
                  writeFloat32(0, deviceID: deviceID, address: address)
            else { return nil }
            return SavedProperty(
                deviceID: deviceID,
                address: address,
                value: .float32(value)
            )
        }
    }

    private func settableAddresses(
        selector: AudioObjectPropertySelector,
        deviceID: AudioDeviceID,
        includeChannels: Bool
    ) -> [AudioObjectPropertyAddress] {
        let elements: ClosedRange<AudioObjectPropertyElement> = includeChannels
            ? 0...32
            : 0...0
        return elements.compactMap { element in
            let address = propertyAddress(selector: selector, element: element)
            return isSettable(deviceID: deviceID, address: address) ? address : nil
        }
    }

    private func defaultOutputDevice() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        return status == noErr && deviceID != kAudioObjectUnknown ? deviceID : nil
    }

    private func activeSubdevices(of deviceID: AudioDeviceID) -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioAggregateDevicePropertyActiveSubDeviceList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &address) else { return [] }

        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            deviceID,
            &address,
            0,
            nil,
            &size
        ) == noErr,
        size > 0
        else { return [] }

        var deviceIDs = [AudioDeviceID](
            repeating: kAudioObjectUnknown,
            count: Int(size) / MemoryLayout<AudioDeviceID>.size
        )
        guard AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &size,
            &deviceIDs
        ) == noErr else { return [] }
        return deviceIDs.filter { $0 != kAudioObjectUnknown }
    }

    private func propertyAddress(
        selector: AudioObjectPropertySelector,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
    }

    private func isSettable(
        deviceID: AudioDeviceID,
        address: AudioObjectPropertyAddress
    ) -> Bool {
        var address = address
        guard AudioObjectHasProperty(deviceID, &address) else { return false }
        var settable = DarwinBoolean(false)
        return AudioObjectIsPropertySettable(deviceID, &address, &settable) == noErr
            && settable.boolValue
    }

    private func readUInt32(
        deviceID: AudioDeviceID,
        address: AudioObjectPropertyAddress
    ) -> UInt32? {
        var address = address
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &size,
            &value
        )
        return status == noErr ? value : nil
    }

    private func writeUInt32(
        _ value: UInt32,
        deviceID: AudioDeviceID,
        address: AudioObjectPropertyAddress
    ) -> Bool {
        var address = address
        var value = value
        let size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            size,
            &value
        ) == noErr
    }

    private func readFloat32(
        deviceID: AudioDeviceID,
        address: AudioObjectPropertyAddress
    ) -> Float32? {
        var address = address
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &size,
            &value
        )
        return status == noErr ? value : nil
    }

    private func writeFloat32(
        _ value: Float32,
        deviceID: AudioDeviceID,
        address: AudioObjectPropertyAddress
    ) -> Bool {
        var address = address
        var value = value
        let size = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            size,
            &value
        ) == noErr
    }
}
