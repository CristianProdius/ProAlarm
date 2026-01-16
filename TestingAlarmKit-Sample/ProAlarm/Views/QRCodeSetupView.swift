//
//  QRCodeSetupView.swift
//  ProAlarm
//
//  View for setting up QR code for alarm verification
//

import SwiftUI

struct QRCodeSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var qrCodeIdentifier: String?

    @State private var showScanner = false
    @State private var tempScannedCode: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Icon
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 80))
                    .foregroundStyle(.purple)
                    .padding(.top, 40)

                // Instructions
                VStack(spacing: 16) {
                    Text("Setup QR Code Verification")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Place a QR code sticker near your sink or water source. You'll need to scan this QR code each morning to stop the alarm.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Current status
                VStack(spacing: 12) {
                    if let code = qrCodeIdentifier ?? tempScannedCode {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("QR Code Registered")
                                .fontWeight(.medium)
                        }

                        Text("Code: \(code.prefix(20))...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundStyle(.orange)
                            Text("No QR Code Set")
                                .fontWeight(.medium)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                Spacer()

                // Scan button
                Button {
                    showScanner = true
                } label: {
                    Label(
                        qrCodeIdentifier != nil ? "Scan New QR Code" : "Scan QR Code",
                        systemImage: "qrcode.viewfinder"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .padding(.horizontal)

                // Tips
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tips:")
                        .font(.caption)
                        .fontWeight(.semibold)

                    Text("• Use any QR code - you can print one from qr-code-generator.com")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("• Place it somewhere you'll see it while drinking water")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("• Make sure it's well-lit and easy to scan")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("QR Code Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if let temp = tempScannedCode {
                            qrCodeIdentifier = temp
                        }
                        dismiss()
                    }
                    .disabled(qrCodeIdentifier == nil && tempScannedCode == nil)
                }
            }
            .sheet(isPresented: $showScanner) {
                QRScannerView(expectedCode: nil) { code in
                    tempScannedCode = code
                    showScanner = false
                }
            }
        }
    }
}

#Preview {
    QRCodeSetupView(qrCodeIdentifier: .constant(nil))
}
