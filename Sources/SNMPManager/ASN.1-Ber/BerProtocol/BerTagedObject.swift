public protocol BerTagedObject: BerCodable {
    static var tag: BerEncodable { get }
    var codableValue: Codable { get }
}

extension BerTagedObject {
    func wraped() -> BerWrapper<Self> {
        return BerWrapper(self)
    }
    
    func wrapedAndEncode() throws -> [UInt8] {
        return try BerWrapper(self).berEncode()
    }
}

extension BerTagedObject {
    static var null: BerNull {
        return BerNull()
    }
}
