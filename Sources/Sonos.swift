import Foundation
import Darwin

enum SonosFeedback {
    case loading(volume: Bool)
    case failed
    case volume(Int)
    case playing
    case paused
    case next
    case previous
    case muted(Bool)
}

struct SonosSettings {
    let room: String
    let volumeStep: Int
}

struct Failure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct Service {
    let type: String
    let url: URL
}

struct Speaker {
    let uuid: String
    let room: String
    let location: URL
    let services: [Service]
}

final class Sonos {
    private let settings: SonosSettings
    private var speakers: [Speaker] = []
    private var selectedRoom: Speaker?
    private var cachedTopology: Element?
    private var topologyFetchedAt = Date.distantPast

    init(_ settings: SonosSettings) { self.settings = settings }

    private func request(_ url: URL, body: String? = nil, action: String? = nil) throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 5)
        if let body = body {
            request.httpMethod = "POST"
            request.httpBody = Data(body.utf8)
            request.setValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.setValue(action, forHTTPHeaderField: "SOAPAction")
        }
        let done = DispatchSemaphore(value: 0)
        var result: Result<Data, Error> = .failure(Failure(message: "Sonos request did not complete."))
        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { done.signal() }
            if let error = error { result = .failure(error); return }
            guard let response = response as? HTTPURLResponse, let data = data else {
                result = .failure(Failure(message: "Sonos returned no HTTP response.")); return
            }
            guard (200..<300).contains(response.statusCode) else {
                result = .failure(Failure(message: "Sonos HTTP \(response.statusCode): \(String(decoding: data, as: UTF8.self))")); return
            }
            result = .success(data)
        }.resume()
        done.wait()
        return try result.get()
    }

    private func describe(_ location: URL) throws -> Speaker {
        let xml = try XML.parse(request(location))
        let services = xml.all("service").compactMap { element -> Service? in
            guard let url = URL(string: element.value("controlURL"), relativeTo: location)?.absoluteURL else { return nil }
            return Service(type: element.value("serviceType"), url: url)
        }
        return Speaker(uuid: xml.value("UDN").replacingOccurrences(of: "uuid:", with: ""), room: xml.value("roomName"), location: location, services: services)
    }

    private func discover() throws {
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { throw Failure(message: "Cannot open the SSDP socket.") }
        defer { close(fd) }
        var timeout = timeval(tv_sec: 0, tv_usec: 250_000)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        var local = sockaddr_in()
        local.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        local.sin_family = sa_family_t(AF_INET)
        let bound = withUnsafePointer(to: &local) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard bound == 0 else { throw Failure(message: "Cannot bind the SSDP socket.") }
        var destination = sockaddr_in()
        destination.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        destination.sin_family = sa_family_t(AF_INET)
        destination.sin_port = UInt16(1900).bigEndian
        inet_pton(AF_INET, "239.255.255.250", &destination.sin_addr)
        let search = Data("M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nMX: 1\r\nST: urn:schemas-upnp-org:device:ZonePlayer:1\r\n\r\n".utf8)
        let sent = search.withUnsafeBytes { bytes in
            withUnsafePointer(to: &destination) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sendto(fd, bytes.baseAddress, bytes.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
            }
        }
        guard sent == search.count else { throw Failure(message: "Cannot send the SSDP discovery request.") }
        let deadline = Date().addingTimeInterval(2.5)
        var locations = Set<URL>()
        var buffer = [UInt8](repeating: 0, count: 8192)
        while Date() < deadline {
            let count = recv(fd, &buffer, buffer.count, 0)
            if count < 0 {
                if errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR { continue }
                throw Failure(message: "Cannot receive SSDP responses.")
            }
            let response = String(decoding: buffer.prefix(count), as: UTF8.self)
            for line in response.components(separatedBy: "\r\n") {
                guard let colon = line.firstIndex(of: ":"), line[..<colon].lowercased() == "location" else { continue }
                if let url = URL(string: line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)) { locations.insert(url) }
            }
        }
        speakers = locations.compactMap { try? describe($0) }
        guard !speakers.isEmpty else { throw Failure(message: "No Sonos speakers responded. Check the local network and firewall.") }
    }

    private func soap(_ speaker: Speaker, _ name: String, _ action: String, _ arguments: [(String, String)] = []) throws -> Element {
        let type = "urn:schemas-upnp-org:service:\(name):1"
        guard let service = speaker.services.first(where: { $0.type == type }) else {
            let services = speaker.services.map { $0.type }.joined(separator: ", ")
            throw Failure(message: "Sonos service \(name) is absent on \(speaker.room) (\(speaker.location.host ?? speaker.uuid)). Available services: \(services)")
        }
        let fields = arguments.map { "<\($0.0)>\($0.1)</\($0.0)>" }.joined()
        let body = "<?xml version=\"1.0\"?><s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\"><s:Body><u:\(action) xmlns:u=\"\(type)\">\(fields)</u:\(action)></s:Body></s:Envelope>"
        let xml = try XML.parse(request(service.url, body: body, action: "\"\(type)#\(action)\""))
        if !xml.all("Fault").isEmpty { throw Failure(message: "Sonos SOAP fault: \(xml.value("errorCode")) \(xml.value("errorDescription"))") }
        return xml
    }

    private func invalidateCache() {
        cachedTopology = nil
        topologyFetchedAt = .distantPast
        speakers = []
        selectedRoom = nil
    }

    func refreshTopology() throws {
        cachedTopology = nil
        _ = try target()
    }

    private func topology() throws -> Element {
        if let cachedTopology = cachedTopology, Date().timeIntervalSince(topologyFetchedAt) < 5 {
            return cachedTopology
        }
        do {
            if speakers.isEmpty { try discover() }
            let type = "urn:schemas-upnp-org:service:ZoneGroupTopology:1"
            guard let seed = speakers.first(where: { speaker in speaker.services.contains(where: { $0.type == type }) }) else {
                let devices = speakers.map { "\($0.room) (\($0.location.host ?? $0.uuid))" }.joined(separator: ", ")
                throw Failure(message: "No discovered Sonos device offers ZoneGroupTopology. Devices: \(devices)")
            }
            let state = try soap(seed, "ZoneGroupTopology", "GetZoneGroupState").value("ZoneGroupState")
            let topology = try XML.parse(Data(state.utf8))
            guard !topology.all("ZoneGroup").isEmpty else {
                throw Failure(message: "Sonos returned no groups from \(seed.room) (\(seed.location.host ?? seed.uuid)).")
            }
            cachedTopology = topology
            topologyFetchedAt = Date()
            return topology
        } catch {
            invalidateCache()
            throw error
        }
    }

    func roomNames() throws -> [String] {
        let names = try topology().all("ZoneGroupMember").compactMap { member -> String? in
            guard member.attributes["Invisible"] != "1" else { return nil }
            return member.attributes["ZoneName"]
        }
        return Array(Set(names)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private func target() throws -> (Speaker, Speaker) {
        let topology = try topology()
        let matches = topology.all("ZoneGroupMember").filter {
            $0.attributes["Invisible"] != "1" && $0.attributes["ZoneName"]?.caseInsensitiveCompare(settings.room) == .orderedSame
        }
        guard matches.count == 1, let member = matches.first, let uuid = member.attributes["UUID"] else {
            throw Failure(message: "Room \(settings.room) matched \(matches.count) visible rooms. Check the config.")
        }
        guard let group = topology.all("ZoneGroup").first(where: { $0.all("ZoneGroupMember").contains(where: { $0.attributes["UUID"] == uuid }) }),
              let coordinatorID = group.attributes["Coordinator"],
              let coordinatorMember = group.all("ZoneGroupMember").first(where: { $0.attributes["UUID"] == coordinatorID }) else {
            throw Failure(message: "The Sonos group coordinator is absent.")
        }
        func speaker(_ member: Element) throws -> Speaker {
            if let device = speakers.first(where: { $0.uuid == member.attributes["UUID"] }) { return device }
            guard let location = member.attributes["Location"], let url = URL(string: location) else { throw Failure(message: "The Sonos speaker location is absent.") }
            let device = try describe(url)
            speakers.append(device)
            return device
        }
        let room = try speaker(member)
        let coordinator = try speaker(coordinatorMember)
        selectedRoom = room
        return (room, coordinator)
    }

    func perform(_ command: String) throws -> SonosFeedback {
        do {
            let instance = [("InstanceID", "0")]
            if command == "up" || command == "down" || command == "mute" {
                let room: Speaker
                if let selectedRoom = selectedRoom { room = selectedRoom }
                else { room = try target().0 }
                let rendering = instance + [("Channel", "Master")]
                if command == "mute" {
                    let muted = try soap(room, "RenderingControl", "GetMute", rendering).value("CurrentMute")
                    _ = try soap(room, "RenderingControl", "SetMute", rendering + [("DesiredMute", muted == "1" ? "0" : "1")])
                    return .muted(muted != "1")
                }
                let amount = settings.volumeStep * (command == "up" ? 1 : -1)
                let response = try soap(room, "RenderingControl", "SetRelativeVolume", rendering + [("Adjustment", String(amount))])
                guard let level = Int(response.value("NewVolume")) else { throw Failure(message: "Sonos returned no volume level.") }
                return .volume(level)
            }

            let (_, coordinator) = try target()
            switch command {
            case "play":
                let state = try soap(coordinator, "AVTransport", "GetTransportInfo", instance).value("CurrentTransportState")
                if state == "PLAYING" {
                    _ = try soap(coordinator, "AVTransport", "Pause", instance)
                    return .paused
                }
                _ = try soap(coordinator, "AVTransport", "Play", instance + [("Speed", "1")])
                return .playing
            case "next", "previous":
                _ = try soap(coordinator, "AVTransport", command == "next" ? "Next" : "Previous", instance)
                return command == "next" ? .next : .previous
            default: throw Failure(message: "Unknown Sonos command: \(command)")
            }
        } catch {
            invalidateCache()
            throw error
        }
    }
}
