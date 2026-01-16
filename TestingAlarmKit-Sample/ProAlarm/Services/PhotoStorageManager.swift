//
//  PhotoStorageManager.swift
//  ProAlarm
//
//  Manages proof photo storage in app's documents folder
//

import UIKit
import Foundation

class PhotoStorageManager {
    static let shared = PhotoStorageManager()

    private let fileManager = FileManager.default
    private let proofPhotosFolderName = "ProofPhotos"

    private init() {
        createProofPhotosFolderIfNeeded()
    }

    // MARK: - Directory Management

    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var proofPhotosURL: URL {
        documentsURL.appendingPathComponent(proofPhotosFolderName, isDirectory: true)
    }

    private func createProofPhotosFolderIfNeeded() {
        if !fileManager.fileExists(atPath: proofPhotosURL.path) {
            try? fileManager.createDirectory(at: proofPhotosURL, withIntermediateDirectories: true)
        }
    }

    // MARK: - Save Photo

    /// Saves a proof photo and returns the relative path
    /// - Parameters:
    ///   - image: The UIImage to save
    ///   - alarmId: The WaterAlarm ID this proof is for
    /// - Returns: Relative path to the saved photo, or nil if save failed
    func saveProofPhoto(_ image: UIImage, alarmId: UUID) -> String? {
        createProofPhotosFolderIfNeeded()

        // Generate filename: proof_[alarmId]_[timestamp].jpg
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "proof_\(alarmId.uuidString)_\(timestamp).jpg"
        let fileURL = proofPhotosURL.appendingPathComponent(filename)

        // Compress to JPEG (quality 0.7 for good balance of size/quality)
        guard let jpegData = image.jpegData(compressionQuality: 0.7) else {
            print("PhotoStorageManager: Failed to convert image to JPEG")
            return nil
        }

        do {
            try jpegData.write(to: fileURL)
            print("PhotoStorageManager: Saved photo to \(filename)")
            return "\(proofPhotosFolderName)/\(filename)"
        } catch {
            print("PhotoStorageManager: Failed to save photo - \(error)")
            return nil
        }
    }

    // MARK: - Load Photo

    /// Loads a proof photo from the given relative path
    /// - Parameter path: Relative path (e.g., "ProofPhotos/proof_xxx.jpg")
    /// - Returns: UIImage if found, nil otherwise
    func loadProofPhoto(path: String) -> UIImage? {
        let fileURL = documentsURL.appendingPathComponent(path)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            print("PhotoStorageManager: Photo not found at \(path)")
            return nil
        }

        return UIImage(contentsOfFile: fileURL.path)
    }

    // MARK: - Delete Photo

    /// Deletes a specific photo
    /// - Parameter path: Relative path to the photo
    func deletePhoto(path: String) {
        let fileURL = documentsURL.appendingPathComponent(path)

        do {
            try fileManager.removeItem(at: fileURL)
            print("PhotoStorageManager: Deleted photo at \(path)")
        } catch {
            print("PhotoStorageManager: Failed to delete photo - \(error)")
        }
    }

    // MARK: - Cleanup Old Photos

    /// Deletes photos older than the specified number of days
    /// - Parameter days: Number of days to keep photos (default 7)
    /// - Returns: Number of photos deleted
    @discardableResult
    func cleanupOldPhotos(olderThan days: Int = 7) -> Int {
        var deletedCount = 0

        guard let files = try? fileManager.contentsOfDirectory(
            at: proofPhotosURL,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return 0
        }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        for fileURL in files {
            guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                  let creationDate = attributes[.creationDate] as? Date else {
                continue
            }

            if creationDate < cutoffDate {
                do {
                    try fileManager.removeItem(at: fileURL)
                    deletedCount += 1
                    print("PhotoStorageManager: Cleaned up old photo \(fileURL.lastPathComponent)")
                } catch {
                    print("PhotoStorageManager: Failed to delete old photo - \(error)")
                }
            }
        }

        if deletedCount > 0 {
            print("PhotoStorageManager: Cleaned up \(deletedCount) old photos")
        }

        return deletedCount
    }

    // MARK: - Storage Info

    /// Returns the total size of proof photos in bytes
    var totalStorageUsed: Int64 {
        guard let files = try? fileManager.contentsOfDirectory(
            at: proofPhotosURL,
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        ) else {
            return 0
        }

        return files.reduce(0) { total, fileURL in
            let size = (try? fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
            return total + size
        }
    }

    /// Returns formatted storage string (e.g., "2.5 MB")
    var formattedStorageUsed: String {
        let bytes = totalStorageUsed
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    /// Returns number of stored photos
    var photoCount: Int {
        (try? fileManager.contentsOfDirectory(
            at: proofPhotosURL,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ))?.count ?? 0
    }
}
