import SwiftUI
import GoogleMaps
import OSLog

enum Acknowledgement: String, CaseIterable, Identifiable {
    case googleMapsNotices, googleMapsPackage, googleMapsUtils, kingfisher

    var id: String { rawValue }

    var title: String {
        switch self {
        case .googleMapsNotices: return "Google Maps SDK Notices"
        case .googleMapsPackage: return "Google Maps Swift Package"
        case .googleMapsUtils: return "Google Maps Utils"
        case .kingfisher: return "Kingfisher"
        }
    }

    var license: String {
        switch self {
        case .googleMapsNotices: return "SDK-provided open-source notices"
        case .googleMapsPackage, .googleMapsUtils: return "Apache License 2.0"
        case .kingfisher: return "MIT License"
        }
    }

    var resourceName: String? {
        switch self {
        case .googleMapsNotices: return nil
        case .googleMapsPackage: return "GoogleMapsPackage-LICENSE"
        case .googleMapsUtils: return "GoogleMapsUtils-LICENSE"
        case .kingfisher: return "Kingfisher-LICENSE"
        }
    }

    func text(bundle: Bundle = .main) throws -> String {
        let text: String
        if let resourceName {
            guard let url = bundle.url(forResource: resourceName, withExtension: "txt") else {
                throw LicenseError.missingResource
            }
            text = try String(contentsOf: url, encoding: .utf8)
        } else {
            text = GMSServices.openSourceLicenseInfo()
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LicenseError.emptyText
        }
        return text
    }

    enum LicenseError: Error {
        case missingResource, emptyText
    }
}

struct LicensesView: View {
    var body: some View {
        Form {
            Section {
                ForEach(Acknowledgement.allCases) { acknowledgement in
                    NavigationLink {
                        LicenseTextView(acknowledgement: acknowledgement)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(acknowledgement.title)
                            Text(acknowledgement.license)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } footer: {
                Text("Acknowledgements for the open-source software used by fotolokashen. Google Maps attribution is also shown on the map.")
            }
        }
        .navigationTitle("Licenses & Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LicenseTextView: View {
    let acknowledgement: Acknowledgement
    @State private var paragraphs: [String]?
    @State private var failed = false

    var body: some View {
        Group {
            if let paragraphs {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        Text(acknowledgement.title)
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(paragraphs.indices, id: \.self) { index in
                            Text(verbatim: paragraphs[index])
                                .font(.body)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                }
            } else if failed {
                ContentUnavailableView(
                    "License Text Unavailable",
                    systemImage: "doc.text",
                    description: Text("The acknowledgement could not be loaded. Please reopen this page to try again.")
                )
            } else {
                ProgressView("Loading license")
            }
        }
        .navigationTitle(acknowledgement.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard paragraphs == nil, !failed else { return }
            do {
                paragraphs = try acknowledgement.text()
                    .components(separatedBy: "\n\n")
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            } catch {
                Log.app.error("Bundled acknowledgement could not be loaded")
                failed = true
            }
        }
    }
}
