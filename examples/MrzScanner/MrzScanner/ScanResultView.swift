//
//  ScanResultView.swift
//  MrzScanner
//
//  Displays parsed MRZ data and portrait image,
//  mirroring Android ScanResultActivity layout.
//

import SwiftUI

struct ScanResultView: View {
    let labelMap: [String: String]
    let portraitImage: UIImage?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile header
                profileHeader

                // Document info card
                documentInfoCard

                // Personal info card
                personalInfoCard

                // Scan again button
                Button(action: {
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "camera.rotate")
                        Text("Scan Again")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .padding(.top, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Scan Result")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 12) {
            // Portrait image
            Group {
                if let portrait = portraitImage {
                    Image(uiImage: portrait)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "person.crop.square.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.gray)
                        .padding(20)
                }
            }
            .frame(width: 120, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )

            // Name
            Text(value("Name"))
                .font(.title2.bold())
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            // Document type badge
            Text(value("Document Type"))
                .font(.caption.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.blue)
                .cornerRadius(12)
        }
        .padding()
    }

    // MARK: - Document Info Card

    private var documentInfoCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader("Document Info")

            infoRow("Document Type", value("Document Type"))
            Divider().padding(.leading)
            infoRow("Document Number", value("Document Number"))
            Divider().padding(.leading)
            infoRow("Issuing State", value("Issuing State"))
            Divider().padding(.leading)
            infoRow("Date of Expiry", value("Date of Expiry(YYYY-MM-DD)"))
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Personal Info Card

    private var personalInfoCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader("Personal Info")

            infoRow("Nationality", value("Nationality"))
            Divider().padding(.leading)
            infoRow("Sex", value("Sex"))
            Divider().padding(.leading)
            infoRow("Age", value("Age"))
            Divider().padding(.leading)
            infoRow("Date of Birth", value("Date of Birth(YYYY-MM-DD)"))
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Reusable Components

    private func cardHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.primary)
            .padding()
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func value(_ key: String) -> String {
        labelMap[key] ?? "—"
    }
}

#Preview {
    NavigationStack {
        ScanResultView(
            labelMap: [
                "Document Type": "PASSPORT",
                "Name": "DOE, JOHN",
                "Nationality": "USA",
                "Sex": "MALE",
                "Age": "35",
                "Document Number": "AB1234567",
                "Issuing State": "USA",
                "Date of Birth(YYYY-MM-DD)": "1990-01-15",
                "Date of Expiry(YYYY-MM-DD)": "2030-01-14"
            ],
            portraitImage: nil
        )
    }
}
