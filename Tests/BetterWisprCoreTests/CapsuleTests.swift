import Foundation
import Testing
@testable import BetterWispr

@Test @MainActor func capsuleHoverTracksEachControlAcrossExpansionAndExit() {
    let hover = CapsuleHover()
    hover.update(regions: [.surface: CGRect(x: 202, y: 218, width: 36, height: 6)])
    hover.move(to: CGPoint(x: 190, y: 210))
    #expect(hover.isHovering)

    let controls: [CapsuleHover.Target: CGRect] = [
        .surface: CGRect(x: 172, y: 196, width: 96, height: 28),
        .microphone: CGRect(x: 172, y: 196, width: 42, height: 28),
        .notetaker: CGRect(x: 218, y: 196, width: 28, height: 28),
        .meetingNotes: CGRect(x: 246, y: 196, width: 22, height: 28)
    ]
    hover.update(regions: controls)
    #expect(hover.target == .microphone)
    hover.move(to: CGPoint(x: 216, y: 210))
    #expect(hover.target == .microphone) // The gap should not flicker.
    hover.move(to: CGPoint(x: 230, y: 210))
    #expect(hover.target == .notetaker)
    hover.move(to: CGPoint(x: 257, y: 210))
    #expect(hover.target == .meetingNotes)

    hover.move(to: CGPoint(x: 10, y: 210))
    #expect(!hover.isHovering && hover.target == nil)
    hover.move(to: CGPoint(x: 230, y: 210))
    hover.move(to: nil)
    #expect(!hover.isHovering && hover.target == nil)

    hover.move(to: CGPoint(x: 220, y: 210))
    hover.update(regions: [
        .surface: CGRect(x: 183, y: 192, width: 74, height: 32),
        .dictation: CGRect(x: 183, y: 192, width: 74, height: 32)
    ])
    #expect(hover.target == .dictation)
    hover.update(regions: [
        .surface: CGRect(x: 183, y: 192, width: 74, height: 32),
        .notetaker: CGRect(x: 183, y: 192, width: 74, height: 32)
    ])
    #expect(hover.target == .notetaker) // The recording pill replaces all idle controls.
    hover.update(regions: [.surface: CGRect(x: 40, y: 104, width: 360, height: 120)])
    #expect(hover.isHovering && hover.target == nil) // No stale tooltip over an error.
}
