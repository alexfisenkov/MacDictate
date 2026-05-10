import Foundation

struct UpdateInfo {
    let version: String
    let releasePageURL: String
    let releaseNotes: String
}

enum UpdateCheckResult {
    case newer(UpdateInfo, currentVersion: String)
    case upToDate(currentVersion: String)
    case unavailable(String)
}

final class UpdateChecker {
    private let latestReleaseURL: URL
    private let session: URLSession

    init(
        latestReleaseURL: URL = URL(string: "https://api.github.com/repos/alexfisenkov/MacDictate/releases/latest")!,
        session: URLSession = .shared
    ) {
        self.latestReleaseURL = latestReleaseURL
        self.session = session
    }

    func check(currentVersion: String, completion: @escaping (UpdateCheckResult) -> Void) {
        var request = URLRequest(url: latestReleaseURL)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        session.dataTask(with: request) { data, response, error in
            if let error {
                completion(.unavailable(error.localizedDescription))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.unavailable("GitHub did not return an HTTP response."))
                return
            }

            guard httpResponse.statusCode == 200, let data else {
                completion(.unavailable("GitHub returned HTTP \(httpResponse.statusCode)."))
                return
            }

            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let rawTagName = json["tag_name"] as? String,
                      let releasePageURL = json["html_url"] as? String else {
                    completion(.unavailable("GitHub response did not contain release metadata."))
                    return
                }

                let fetchedVersion = Self.normalizedVersion(rawTagName)
                let releaseNotes = json["body"] as? String ?? ""
                if Self.compareVersions(fetchedVersion, currentVersion) == .orderedDescending {
                    completion(.newer(
                        UpdateInfo(
                            version: fetchedVersion,
                            releasePageURL: releasePageURL,
                            releaseNotes: releaseNotes
                        ),
                        currentVersion: currentVersion
                    ))
                } else {
                    completion(.upToDate(currentVersion: currentVersion))
                }
            } catch {
                completion(.unavailable("Could not parse GitHub release metadata: \(error.localizedDescription)"))
            }
        }.resume()
    }

    private static func normalizedVersion(_ tagName: String) -> String {
        tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
    }

    private static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        lhs.compare(rhs, options: .numeric)
    }
}
