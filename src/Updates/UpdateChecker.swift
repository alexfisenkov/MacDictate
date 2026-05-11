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
    private enum FetchResult {
        case success(UpdateInfo)
        case failure(String)
    }

    private let latestReleaseURL: URL
    private let fallbackReleaseURL: URL?
    private let session: URLSession

    init(
        latestReleaseURL: URL = URL(string: "https://macdictate.pro/downloads/latest-desktop.json")!,
        fallbackReleaseURL: URL? = URL(string: "https://api.github.com/repos/alexfisenkov/MacDictate/releases/latest")!,
        session: URLSession = .shared
    ) {
        self.latestReleaseURL = latestReleaseURL
        self.fallbackReleaseURL = fallbackReleaseURL
        self.session = session
    }

    func check(currentVersion: String, completion: @escaping (UpdateCheckResult) -> Void) {
        fetchUpdateInfo(from: latestReleaseURL) { [weak self] primaryResult in
            switch primaryResult {
            case .success(let updateInfo):
                completion(Self.compare(updateInfo: updateInfo, currentVersion: currentVersion))
            case .failure(let primaryError):
                guard let self, let fallbackReleaseURL = self.fallbackReleaseURL else {
                    completion(.unavailable(primaryError))
                    return
                }

                self.fetchUpdateInfo(from: fallbackReleaseURL) { fallbackResult in
                    switch fallbackResult {
                    case .success(let updateInfo):
                        completion(Self.compare(updateInfo: updateInfo, currentVersion: currentVersion))
                    case .failure(let fallbackError):
                        completion(.unavailable("\(primaryError) Fallback: \(fallbackError)"))
                    }
                }
            }
        }
    }

    private func fetchUpdateInfo(from url: URL, completion: @escaping (FetchResult) -> Void) {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if url.host == "api.github.com" {
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            request.setValue("MacDictate", forHTTPHeaderField: "User-Agent")
        }

        session.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error.localizedDescription))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure("\(url.host ?? "Update server") did not return an HTTP response."))
                return
            }

            guard httpResponse.statusCode == 200, let data else {
                completion(.failure("\(url.host ?? "Update server") returned HTTP \(httpResponse.statusCode)."))
                return
            }

            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let updateInfo = Self.parseUpdateInfo(from: json) else {
                    completion(.failure("\(url.host ?? "Update server") response did not contain release metadata."))
                    return
                }

                completion(.success(updateInfo))
            } catch {
                completion(.failure("Could not parse release metadata: \(error.localizedDescription)"))
            }
        }.resume()
    }

    private static func parseUpdateInfo(from json: [String: Any]) -> UpdateInfo? {
        if let rawVersion = json["version"] as? String,
           let publicURL = json["publicUrl"] as? String {
            let version = normalizedVersion(rawVersion)
            return UpdateInfo(
                version: version,
                releasePageURL: publicURL,
                releaseNotes: "Публичная стабильная версия \(version)."
            )
        }

        if let rawTagName = json["tag_name"] as? String,
           let releasePageURL = json["html_url"] as? String {
            return UpdateInfo(
                version: normalizedVersion(rawTagName),
                releasePageURL: releasePageURL,
                releaseNotes: json["body"] as? String ?? ""
            )
        }

        return nil
    }

    private static func compare(updateInfo: UpdateInfo, currentVersion: String) -> UpdateCheckResult {
        if compareVersions(updateInfo.version, currentVersion) == .orderedDescending {
            return .newer(updateInfo, currentVersion: currentVersion)
        }

        return .upToDate(currentVersion: currentVersion)
    }

    private static func normalizedVersion(_ tagName: String) -> String {
        tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
    }

    private static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        lhs.compare(rhs, options: .numeric)
    }
}
