//  TTSLogicTester.swift
//  Thai Vocab Trainer
//
//  A lightweight helper to verify the TTS triggering rules for each speaker volume level.
//  Volume mapping:
//  0 (🔇) – never speak
//  1 (🔈) – speak when count % 10 == 0
//  2 (🔉) – speak when count % 50 == 0
//  3 (🔊) – speak when count % 100 == 0
//
//  This file contains:
//  1. `shouldSpeak(volumeLevel:count:)` – pure logic that can be unit-tested.
//  2. Simple console test that prints results for a sample range when compiled/run in DEBUG.
//
import Foundation

/// Returns `true` if Thai TTS should be triggered for the given `count` and `volumeLevel`.
/// - Parameters:
///   - volumeLevel: Int (0 = mute, 1 = low, 2 = medium, 3 = high)
///   - count: current drill count for the vocab item
/// - Returns: Bool indicating whether TTS should play.
func shouldSpeak(volumeLevel: Int, count: Int) -> Bool {
    switch volumeLevel {
    case 0: // 🔇 mute
        return false
    case 1: // 🔈 every 10 hits
        return count % 10 == 0
    case 2: // 🔉 every 50 hits
        return count % 50 == 0
    case 3: // 🔊 every 100 hits
        return count % 100 == 0
    default:
        return false
    }
}

#if DEBUG
/// Quick manual test – prints the trigger counts when compiled standalone.
struct TTSLogicQuickTest {
    static func run() {
        let maxCount = 120
        for level in 0...3 {
            print("\nVolume level \(level):")
            let triggers = (1...maxCount).filter { shouldSpeak(volumeLevel: level, count: $0) }
            print("Triggers at counts:", triggers)
        }
    }
}

#endif
