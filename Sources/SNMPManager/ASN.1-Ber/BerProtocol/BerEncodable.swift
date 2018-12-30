public protocol BerEncodable {
    func berEncode() throws -> [UInt8]
}

