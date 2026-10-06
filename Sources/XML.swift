import Foundation

final class Element {
    let name: String
    let attributes: [String: String]
    var text = ""
    var children: [Element] = []

    init(_ name: String, _ attributes: [String: String]) {
        self.name = name.components(separatedBy: ":").last!
        self.attributes = attributes
    }

    func all(_ name: String) -> [Element] {
        children.flatMap { ($0.name == name ? [$0] : []) + $0.all(name) }
    }

    func value(_ name: String) -> String {
        all(name).first?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

final class XML: NSObject, XMLParserDelegate {
    private var stack: [Element] = []
    private let root = Element("root", [:])

    static func parse(_ data: Data) throws -> Element {
        let delegate = XML()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        guard parser.parse() else {
            throw parser.parserError ?? Failure(message: "Sonos returned invalid XML.")
        }
        return delegate.root
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        let element = Element(name, attributes)
        (stack.last ?? root).children.append(element)
        stack.append(element)
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        stack.last?.text += string
    }

    func parser(_ parser: XMLParser, foundCDATA block: Data) {
        stack.last?.text += String(decoding: block, as: UTF8.self)
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        stack.removeLast()
    }
}

