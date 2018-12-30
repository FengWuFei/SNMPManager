extension Int: BerCodable {
    // 取补码
    public func berEncode() throws -> [UInt8] {
        guard self <= 0xfffffff && self >= -0xfffffff else { throw BerEncodeError.intValueTooLong }
        var size = 4
        var value = self
        var bytes: [UInt8] = []
        while (((value & 0xff800000) == 0) || ((value & 0xff800000) == 0xff800000 >> 0)) && (size > 1) {
            size -= 1
            value <<= 8
        }
        guard size <= 4 else { return [] }
        while size > 0 {
            bytes.append(UInt8((value & 0xff000000) >> 24))
            value <<= 8
            size -= 1
        }
        return bytes
    }
    
    public static func berDecode(_ bytes: [UInt8]) throws -> Int {
        let length = bytes.count
        guard length <= 4 && length > 0 else { throw BerDecodeError.wrongIntBytes }
        var value: Int = 0
        bytes.forEach { i in
            value <<= 8
            value = (0xff & Int(i)) | value
        }
        
        if (bytes.first! & 0x80) == 0x80 {
            value -= 1 << (length * 8)
        }
        return value
    }
}

extension UInt: BerCodable {
    public static func berDecode(_ bytes: [UInt8]) throws -> UInt {
        let length = bytes.count
        var value: UInt = 0
        
        if (length > 5) {
            throw BerEncodeError.uIntValueTooLong
        } else if (length == 5) {
            if (bytes[0] != 0) {
                throw BerEncodeError.uIntValueTooLong
            }
        }
        bytes.forEach { byte in
            value *= 256
            value += UInt(byte)
        }
        return value
    }
    
    public func berEncode() throws -> [UInt8] {
        do {
            return try Int(self).berEncode()
        } catch {
            throw error
        }
    }
}

extension String: BerCodable {
    public func berEncode() -> [UInt8] {
        return Array(self.utf8)
    }
    
    public static func berDecode(_ bytes: [UInt8]) throws -> String {
        guard let str = String(bytes: bytes, encoding: .ascii) else { throw BerDecodeError.nullString }
        return str
    }
}

extension BerNull: BerCodable {
    public func berEncode() -> [UInt8] {
        return []
    }
    
    public static func berDecode(_ bytes: [UInt8]) throws -> BerNull {
        guard bytes.count < 1 else { throw BerDecodeError.invalidNull }
        return BerNull()
    }
}

extension BerObjectId: BerCodable {
    public func berEncode() -> [UInt8] {
        var bytes: [UInt8] = []
        var tmp = oid.split(separator: ".")
            .map { Int($0)! }
        let head = 40 * tmp.removeFirst() + tmp.removeFirst()
        bytes.append(UInt8(head & 0xff))
        
        func encodeOctet(_ octet: Int) {
            if octet < 128 {
                bytes.append(UInt8(octet))
            } else if octet < 16384 {
                bytes.append(UInt8((octet >> 7) | 0x80))
                bytes.append(UInt8(octet & 0x7F))
            } else if octet < 2097152 {
                bytes.append(UInt8((octet >> 14) | 0x80))
                bytes.append(UInt8(((octet >> 7) | 0x80) & 0xFF))
                bytes.append(UInt8(octet & 0x7F))
            } else if octet < 268435456 {
                bytes.append(UInt8((octet >> 21) | 0x80))
                bytes.append(UInt8(((octet >> 14) | 0x80) & 0xFF))
                bytes.append(UInt8(((octet >> 7) | 0x80) & 0xFF))
                bytes.append(UInt8(octet & 0x7F))
            } else {
                bytes.append(UInt8(((octet >> 28) | 0x80) & 0xFF))
                bytes.append(UInt8(((octet >> 21) | 0x80) & 0xFF))
                bytes.append(UInt8(((octet >> 14) | 0x80) & 0xFF))
                bytes.append(UInt8(((octet >> 7) | 0x80) & 0xFF))
                bytes.append(UInt8(octet & 0x7F))
            }
        }
        tmp.forEach { encodeOctet($0) }
        return bytes
    }
    
    public static func berDecode(_ bytes: [UInt8]) throws -> BerObjectId {
        var values = [Int]()
        var value = 0
        
        bytes.forEach { byte in
            value <<= 7
            value += Int(byte) & 0x7f
            
            if (byte & 0x80) == 0 {
                values.append(Int(value >> 0))
                value = 0
            }
        }
        value = values.removeFirst()
        values.insert(value % 40, at: 0)
        values.insert((value / 40) >> 0, at: 0)
        
        let str = values.map(String.init).joined(separator: ".")
        guard let ob = BerObjectId(str) else { throw BerDecodeError.wrongOID }
        return ob
    }
}

extension BytesSequence: BerCodable {
    public func berEncode() -> [UInt8] {
        return value
    }
    
    public static func berDecode(_ bytes: [UInt8]) throws -> BytesSequence {
        return BytesSequence(value: bytes)
    }
}

extension SNMPIpAddress: BerCodable {
    public func berEncode() throws -> [UInt8] {
        return try self.value.split(separator: ".").map { byteStr throws -> UInt8 in
            guard let byte = UInt8(byteStr) else { throw BerEncodeError.invalidIPAddress }
            return byte
        }
    }
    
    public static func berDecode(_ bytes: [UInt8]) throws -> SNMPIpAddress {
        return  SNMPIpAddress(value: bytes.map { String($0) }.joined(separator: "."))
    }
}

extension SNMPTimeTicks: BerCodable {
    public func berEncode() throws -> [UInt8] {
        return try value.berEncode()
    }
    
    public static func berDecode(_ bytes: [UInt8]) throws -> SNMPTimeTicks {
        return try SNMPTimeTicks(value: UInt.berDecode(bytes))
    }
}

extension Array: BerEncodable where Element == BerEncodable {
    public func berEncode() throws -> [UInt8] {
        return try reduce([]) { try $0 + $1.berEncode() }
    }
}
