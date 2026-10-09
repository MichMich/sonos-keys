import AppKit
import Combine

final class UpdateChecker: ObservableObject {
    @Published private(set) var availableVersion: String?
    @Published private(set) var checking = false
    @Published private(set) var status: String?
    private var timer: Timer?

    init() {
        let timer = Timer(timeInterval: 3600, repeats: true) { [weak self] _ in self?.check() }
        timer.tolerance = 60
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        check()
    }

    deinit { timer?.invalidate() }

    func check() {
        guard !checking else { return }
        checking = true
        status = "Checking for updates…"
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/MichMich/sonos-keys/releases/latest")!)
        request.timeoutInterval = 20
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            struct Release: Decodable { let tag_name: String }
            let release = data.flatMap { try? JSONDecoder().decode(Release.self, from: $0) }
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.checking = false
                guard error == nil, (response as? HTTPURLResponse)?.statusCode == 200,
                      let release = release,
                      release.tag_name.range(of: "^v?[0-9]+\\.[0-9]+\\.[0-9]+$", options: .regularExpression) != nil else {
                    self.status = "Could not check for updates. Try again."
                    return
                }
                let version = release.tag_name.hasPrefix("v") ? String(release.tag_name.dropFirst()) : release.tag_name
                let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
                self.availableVersion = version.compare(current, options: .numeric) == .orderedDescending ? version : nil
                self.status = self.availableVersion == nil ? "You have the latest version." : "Version \(version) is available."
            }
        }.resume()
    }

    func openReleases() {
        NSWorkspace.shared.open(URL(string: "https://github.com/MichMich/sonos-keys/releases")!)
    }
}
