#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

TEST_SWIFT="$TMP_DIR/main.swift"
TEST_BIN="$TMP_DIR/test-update-checker-response"

cat >"$TEST_SWIFT" <<'SWIFT'
import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
}

final class MockURLProtocol: URLProtocol {
    struct Response {
        let statusCode: Int
        let body: String
    }

    static var responses: [URL: Response] = [:]

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url,
              let response = Self.responses[url] else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: response.statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(response.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

func makeSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: configuration)
}

func waitForResult(_ checker: UpdateChecker, currentVersion: String) -> UpdateCheckResult {
    let semaphore = DispatchSemaphore(value: 0)
    var result: UpdateCheckResult?

    checker.check(currentVersion: currentVersion) { updateResult in
        result = updateResult
        semaphore.signal()
    }

    if semaphore.wait(timeout: .now() + 5) == .timedOut {
        fputs("Timed out waiting for update result\n", stderr)
        exit(1)
    }

    guard let result else {
        fputs("Missing update result\n", stderr)
        exit(1)
    }
    return result
}

let manifestURL = URL(string: "https://macdictate.pro/downloads/latest-desktop.json")!
let githubURL = URL(string: "https://api.github.com/repos/alexfisenkov/MacDictate/releases/latest")!

func testWebsiteManifestDrivesDownloadURL() {
    MockURLProtocol.responses = [
        manifestURL: .init(statusCode: 200, body: """
        {
          "version": "v1.5.1",
          "publicUrl": "https://macdictate.pro/downloads/MacDictate_Latest.dmg"
        }
        """)
    ]

    let checker = UpdateChecker(
        latestReleaseURL: manifestURL,
        fallbackReleaseURL: githubURL,
        session: makeSession()
    )

    switch waitForResult(checker, currentVersion: "1.5.0") {
    case .newer(let updateInfo, let currentVersion):
        expect(currentVersion == "1.5.0", "expected current version")
        expect(updateInfo.version == "1.5.1", "expected website manifest version")
        expect(updateInfo.releasePageURL == "https://macdictate.pro/downloads/MacDictate_Latest.dmg", "expected direct website download URL")
    default:
        fputs("Expected newer result from website manifest\n", stderr)
        exit(1)
    }
}

func testUpToDateFromWebsiteManifest() {
    MockURLProtocol.responses = [
        manifestURL: .init(statusCode: 200, body: """
        {
          "version": "v1.5.1",
          "publicUrl": "https://macdictate.pro/downloads/MacDictate_Latest.dmg"
        }
        """)
    ]

    let checker = UpdateChecker(
        latestReleaseURL: manifestURL,
        fallbackReleaseURL: githubURL,
        session: makeSession()
    )

    switch waitForResult(checker, currentVersion: "1.5.1") {
    case .upToDate(let currentVersion):
        expect(currentVersion == "1.5.1", "expected up-to-date version")
    default:
        fputs("Expected up-to-date result\n", stderr)
        exit(1)
    }
}

func testGitHubFallbackStillWorks() {
    MockURLProtocol.responses = [
        manifestURL: .init(statusCode: 404, body: "{}"),
        githubURL: .init(statusCode: 200, body: """
        {
          "tag_name": "v1.5.2",
          "html_url": "https://github.com/alexfisenkov/MacDictate/releases/tag/v1.5.2",
          "body": "Release notes"
        }
        """)
    ]

    let checker = UpdateChecker(
        latestReleaseURL: manifestURL,
        fallbackReleaseURL: githubURL,
        session: makeSession()
    )

    switch waitForResult(checker, currentVersion: "1.5.1") {
    case .newer(let updateInfo, _):
        expect(updateInfo.version == "1.5.2", "expected fallback GitHub version")
        expect(updateInfo.releasePageURL == "https://github.com/alexfisenkov/MacDictate/releases/tag/v1.5.2", "expected fallback GitHub URL")
    default:
        fputs("Expected newer result from GitHub fallback\n", stderr)
        exit(1)
    }
}

testWebsiteManifestDrivesDownloadURL()
testUpToDateFromWebsiteManifest()
testGitHubFallbackStillWorks()
print("UpdateChecker response test passed.")
SWIFT

swiftc \
    "$ROOT_DIR/src/Updates/UpdateChecker.swift" \
    "$TEST_SWIFT" \
    -o "$TEST_BIN"

"$TEST_BIN"
