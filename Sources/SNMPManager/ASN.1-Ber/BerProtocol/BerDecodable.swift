public protocol BerDecodable {
    static func berDecode(_ bytes: [UInt8]) throws -> Self
}
