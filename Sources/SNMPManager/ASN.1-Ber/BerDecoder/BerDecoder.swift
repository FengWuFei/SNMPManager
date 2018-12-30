public class BerDecoder {
    private var bytes: [UInt8] = []
    private var offset = 0
    
    public var hasValue: Bool {
        return bytes.count > offset
    }
    
    public init(bytes: [UInt8]) {
        self.bytes = bytes
    }
    
    public init() {
        self.bytes = []
    }
    
    public func set(_ bytes: [UInt8]) {
        self.bytes = bytes
        offset = 0
    }
    
    public func readSequence() throws {
        do {
            try readTag(BerTag.sequence)
            try readLength()
        } catch {
            throw error
        }
    }
    
    public func readPduType() throws -> UInt8 {
        do {
            let tag = try readTag()
            try readLength()
            return tag
        } catch {
            throw error
        }
    }
    
    public func readValue<T: BerTagedObject>(to type: T.Type = T.self) throws -> T {
        do {
            try readTag(T.tag)
            let length = try readLength()
            return try T.berDecode(readBytesWith(length))
        } catch {
            throw error
        }
    }
    
    public func readAny() throws -> BerTagedObject {
        do {
            let _tag = bytes[offset]
            guard let tag = BerTag(rawValue: _tag) else { throw BerDecodeError.invalidTag }
            let Type = try tag.getBerType()
            try readTag(Type.tag)
            let length = try readLength()
            return try Type.berDecode(readBytesWith(length))
        } catch {
            throw error
        }
    }
    
    func readValueBinds() throws -> [(BerObjectId, BerTagedObject)] {
        do {
            var dic: [(BerObjectId, BerTagedObject)] = []
            try readSequence()
            while hasValue {
                try readSequence()
                let oid: BerObjectId = try readValue()
                let value = try readAny()
                dic.append((oid, value))
            }
            return dic
        } catch {
            throw error
        }
    }
    
    @discardableResult public func readTag(_ expect: BerEncodable? = nil) throws -> UInt8 {
        do {
            let readTag = try readOneByte()
            guard let expectTag = try expect?.berEncode()[0] else { return readTag }
            if readTag != expectTag {
                throw BerDecodeError.invalidTag
            }
            return readTag
        } catch {
            throw error
        }
    }
    
    @discardableResult public func readLength() throws -> Int {
        do {
            var length: Int
            var lengthByte = try readOneByte() & 0xff
            if (lengthByte & 0x80) == 0x80 {
                lengthByte &= 0x7f
                if lengthByte == 0 {
                    throw BerDecodeError.indefiniteLength
                }
                if lengthByte > 3 {
                    throw BerDecodeError.lengthTooLong
                }
                if bytes.count - (offset) < Int(lengthByte) {
                    throw BerDecodeError.lengthLostBytes
                }
                length = 0
                for _ in (0..<lengthByte) {
                    length = (length << 8) + Int((try readOneByte() & 0xff))
                }
            } else {
                length = Int(lengthByte)
            }
            return length
        } catch {
            throw error
        }
    }
    
    private func readOneByte() throws -> UInt8 {
        guard hasValue else { throw BerDecodeError.outOfRange }
        let byte = bytes[offset]
        offset += 1
        return byte
    }
    
    private func readBytesWith(_ length: Int) throws -> [UInt8] {
        guard offset + length <= self.bytes.count else { throw BerDecodeError.outOfRange }
        let res = Array(self.bytes[offset..<(offset + length)])
        offset += length
        return res
    }
}