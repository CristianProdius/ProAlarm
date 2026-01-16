//
//  HistoryView.swift
//  ProAlarm
//
//  View showing full history of alarm completions
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \ProofRecord.completedAt, order: .reverse)
    private var proofRecords: [ProofRecord]

    @State private var selectedRecord: ProofRecord?

    var body: some View {
        NavigationStack {
            Group {
                if proofRecords.isEmpty {
                    emptyState
                } else {
                    historyList
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedRecord) { record in
                ProofDetailView(record: record)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundStyle(.gray.opacity(0.5))

            Text("No History Yet")
                .font(.title2)
                .foregroundStyle(.gray)

            Text("Your completed alarms will appear here")
                .font(.subheadline)
                .foregroundStyle(.gray.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var historyList: some View {
        List {
            ForEach(groupedRecords.keys.sorted().reversed(), id: \.self) { date in
                Section(header: Text(sectionHeader(for: date))) {
                    ForEach(groupedRecords[date] ?? []) { record in
                        HistoryRow(record: record)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedRecord = record
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var groupedRecords: [Date: [ProofRecord]] {
        Dictionary(grouping: proofRecords) { record in
            Calendar.current.startOfDay(for: record.completedAt)
        }
    }

    private func sectionHeader(for date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
}

// MARK: - History Row

struct HistoryRow: View {
    let record: ProofRecord

    var body: some View {
        HStack(spacing: 12) {
            // Time
            VStack(alignment: .leading) {
                Text(timeString)
                    .font(.headline)

                HStack(spacing: 4) {
                    if record.wasOnTime {
                        Image(systemName: "clock")
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "moon.zzz")
                            .foregroundStyle(.orange)
                    }

                    if record.qrCodeScanned {
                        Image(systemName: "qrcode")
                            .foregroundStyle(.purple)
                    }

                    if record.photoPath != nil {
                        Image(systemName: "camera.fill")
                            .foregroundStyle(.cyan)
                    }
                }
                .font(.caption)
            }

            Spacer()

            // Difficulty
            VStack(alignment: .trailing) {
                HStack(spacing: 2) {
                    ForEach(0..<record.difficultyLevel, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                    }
                }
                .foregroundStyle(.yellow)

                Text(difficultyLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: record.completedAt)
    }

    private var difficultyLabel: String {
        switch record.difficultyLevel {
        case 1: return "Easy"
        case 2: return "Medium"
        case 3: return "Hard"
        case 4: return "Extreme"
        default: return ""
        }
    }
}

// MARK: - Proof Detail View

struct ProofDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let record: ProofRecord

    @State private var proofImage: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Photo preview
                    if let image = proofImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(radius: 5)
                    } else if record.photoPath != nil {
                        ProgressView()
                            .frame(height: 200)
                    } else {
                        VStack {
                            Image(systemName: "photo")
                                .font(.system(size: 60))
                                .foregroundStyle(.gray.opacity(0.5))
                            Text("No photo")
                                .foregroundStyle(.secondary)
                        }
                        .frame(height: 200)
                    }

                    // Details
                    VStack(spacing: 16) {
                        DetailRow(label: "Date", value: record.formattedDate)
                        DetailRow(label: "Status", value: record.wasOnTime ? "On Time" : "Snoozed")
                        DetailRow(label: "Difficulty", value: difficultyLabel)
                        DetailRow(label: "QR Scanned", value: record.qrCodeScanned ? "Yes" : "No")
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                    )
                }
                .padding()
            }
            .navigationTitle("Proof Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadPhoto()
            }
        }
    }

    private var difficultyLabel: String {
        switch record.difficultyLevel {
        case 1: return "Easy"
        case 2: return "Medium"
        case 3: return "Hard"
        case 4: return "Extreme"
        default: return "Unknown"
        }
    }

    private func loadPhoto() {
        guard let path = record.photoPath else { return }
        proofImage = PhotoStorageManager.shared.loadProofPhoto(path: path)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [ProofRecord.self])
}
