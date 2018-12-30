public typealias BerCodable = BerEncodable & BerDecodable

protocol BerObject: BerEncodable {
    associatedtype Value: BerEncodable
    var tag: BerEncodable { get }
    var value: Value { get set }
}

extension BerEncodable where Self: BerObject {
    func berEncode() throws -> [UInt8] {
        do {
            let valueBytes = try value.berEncode()
            let lengthBytes = try Length(value: valueBytes.count).berEncode()
            let tagBytes = try tag.berEncode()
            return tagBytes + lengthBytes + valueBytes
        } catch {
            throw error
        }
    }
}
