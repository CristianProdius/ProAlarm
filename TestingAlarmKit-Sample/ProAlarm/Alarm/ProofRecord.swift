//
//  ProofRecord.swift
//  ProAlarm
//
//  Records proof completion for each alarm instance
//

import Foundation
import SwiftData

@Model
class ProofRecord: Identifiable {
    @Attribute(.unique) var id = UUID()

    // Reference to the WaterAlarm
    var alarmId: UUID

    // When the proof was completed
    var completedAt: Date

    // Relative path to photo in Documents/ProofPhotos (nil if no photo)
    var photoPath: String?

    // Whether QR code was scanned
    var qrCodeScanned: Bool

    // Difficulty level at time of completion
    var difficultyLevel: Int

    // True if completed without using snooze
    var wasOnTime: Bool

    // Awakeness validation results (Apple Intelligence)
    var awakenessScore: Float?  // 0.0-1.0, nil if validation disabled
    var validationBypassed: Bool  // True if user skipped validation after failures

    init(
        id: UUID = UUID(),
        alarmId: UUID,
        completedAt: Date = Date(),
        photoPath: String? = nil,
        qrCodeScanned: Bool = false,
        difficultyLevel: Int = 1,
        wasOnTime: Bool = true,
        awakenessScore: Float? = nil,
        validationBypassed: Bool = false
    ) {
        self.id = id
        self.alarmId = alarmId
        self.completedAt = completedAt
        self.photoPath = photoPath
        self.qrCodeScanned = qrCodeScanned
        self.difficultyLevel = difficultyLevel
        self.wasOnTime = wasOnTime
        self.awakenessScore = awakenessScore
        self.validationBypassed = validationBypassed
    }

    // Formatted date string
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: completedAt)
    }

    // Check if this record is from today
    var isFromToday: Bool {
        Calendar.current.isDateInToday(completedAt)
    }

    // Check if this record is from yesterday
    var isFromYesterday: Bool {
        Calendar.current.isDateInYesterday(completedAt)
    }
}
