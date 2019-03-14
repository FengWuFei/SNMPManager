class BerDecoder {
    private var bytes: [UInt8] = []
    private var offset = 0
    
    var hasValue: Bool {
        return bytes.count > offset
    }
    
    init(bytes: [UInt8]) {
        self.bytes = bytes
    }
    
    init() {
        self.bytes = []
    }
    
    func set(_ bytes: [UInt8]) {
        self.bytes = bytes
        offset = 0
    }
    
    func readSequence() throws {
        try readTag(BerTag.sequence)
        try readLength()
    }
    
    func readPduType() throws -> UInt8 {
        let tag = try readTag()
        try readLength()
        return tag
    }
    
    func readValue<T: BerTagedObject>(to type: T.Type = T.self) throws -> T {
        try readTag(T.tag)
        let length = try readLength()
        return try T.berDecode(readBytesWith(length))
    }
    
    func readAny() throws -> BerTagedObject {
        let _tag = bytes[offset]
        guard let tag = BerTag(rawValue: _tag) else { throw BerDecodeError.invalidTag }
        let Type = try tag.getBerType()
        try readTag(Type.tag)
        let length = try readLength()
        return try Type.berDecode(readBytesWith(length))
    }
    
    func readValueBinds() throws -> [String: BerTagedObject] {
        var dic: [String: BerTagedObject] = [:]
        try readSequence()
        while hasValue {
            try readSequence()
            let oid: BerObjectId = try readValue()
            let value = try readAny()
            dic[oid.value] = value
        }
        return dic
    }
    
    @discardableResult
    func readTag(_ expect: BerEncodable? = nil) throws -> UInt8 {
        let readTag = try readOneByte()
        guard let expectTag = try expect?.berEncode()[0] else { return readTag }
        if readTag != expectTag {
            throw BerDecodeError.invalidTag
        }
        return readTag
    }
    
    @discardableResult
    func readLength() throws -> Int {
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
