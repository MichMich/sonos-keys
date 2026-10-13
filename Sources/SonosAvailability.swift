import Foundation
import Network

final class SonosAvailability {
    var onChange: ((Bool) -> Void)?
    var onNetworkChange: (() -> Void)?
    private let settings: SonosSettings
    private let monitor = NWPathMonitor()
    private let worker = DispatchQueue(label: "sonos-keys.availability")
    private var client: Sonos
    private var timer: Timer?
    private var running = false
    private var checking = false
    private var receivedPath = false
    private var generation = 0
    private var failures = 0
    private var available: Bool?

    init(settings: SonosSettings) {
        self.settings = settings
        client = Sonos(settings)
    }

    deinit {
        timer?.invalidate()
        monitor.cancel()
    }

    func start() {
        running = true
        monitor.pathUpdateHandler = { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self, self.running else { return }
                if self.receivedPath { self.onNetworkChange?() }
                self.receivedPath = true
                self.generation += 1
                self.checking = false
                self.failures = 0
                self.available = nil
                self.client = Sonos(self.settings)
                self.check()
            }
        }
        monitor.start(queue: worker)
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in self?.check() }
        timer.tolerance = 3
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        running = false
        generation += 1
        timer?.invalidate()
        timer = nil
        monitor.cancel()
    }

    private func check() {
        guard running, !checking else { return }
        checking = true
        let generation = generation
        let client = client
        worker.async { [weak self] in
            let reachable = (try? client.checkAvailability()) != nil
            DispatchQueue.main.async {
                guard let self = self, self.running, self.generation == generation else { return }
                self.checking = false
                self.failures = reachable ? 0 : self.failures + 1
                guard reachable || self.failures >= 3 else { return }
                guard self.available != reachable else { return }
                self.available = reachable
                self.onChange?(reachable)
            }
        }
    }
}
