import AppKit
import BetterWisprCore
import Carbon.HIToolbox
import IOKit.hidsystem
import Testing
@testable import BetterWispr

@Test @MainActor func standaloneOptionDeliversOnePressAndReleaseForTheRecordedSide() throws {
    let listener = GlobalShortcut()
    let shortcut = try #require(DictationShortcut(keyCode: UInt32(kVK_Option), modifiers: [], key: "Left Option"))
    var transitions: [Bool] = []
    listener.onPress = { transitions.append(true) }
    listener.onRelease = { transitions.append(false) }
    let left = NSEvent.ModifierFlags(rawValue: UInt(NX_DEVICELALTKEYMASK)).union(.option)
    let right = NSEvent.ModifierFlags(rawValue: UInt(NX_DEVICERALTKEYMASK)).union(.option)

    func send(_ keyCode: Int, _ flags: NSEvent.ModifierFlags) throws {
        let event = try #require(NSEvent.keyEvent(with: .flagsChanged, location: .zero, modifierFlags: flags,
                                                timestamp: 0, windowNumber: 0, context: nil, characters: "",
                                                charactersIgnoringModifiers: "", isARepeat: false, keyCode: UInt16(keyCode)))
        listener.handleModifierEvent(event, shortcut: shortcut)
    }

    try send(kVK_RightOption, right)
    try send(kVK_RightOption, [])
    try send(kVK_Option, left.union(.command))
    try send(kVK_Option, .command)
    #expect(transitions.isEmpty)

    try send(kVK_Option, left)
    try send(kVK_Option, left)
    try send(kVK_RightOption, left.union(right))
    try send(kVK_Option, right) // Releasing left must finish even while right is down.
    try send(kVK_RightOption, [])
    #expect(transitions == [true, false])

    try send(kVK_Option, left)
    try send(kVK_Option, .command) // Added modifiers must not swallow the release.
    #expect(transitions == [true, false, true, false])
    listener.unregister()
    try send(kVK_Option, [])
    #expect(transitions == [true, false, true, false])
}
