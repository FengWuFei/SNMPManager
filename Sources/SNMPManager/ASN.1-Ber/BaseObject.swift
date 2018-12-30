enum BerTag: UInt8 {
    case boolean = 0x01
    case integer = 0x02
    case octetString = 0x04
    case null = 0x05
    case objectID = 0x06
    case sequence = 0x30
    
    case ipAddress = 0x40
    case Counter = 0x41
    case Gauge = 0x42
    case timeTicks = 0x43
    case Opaque = 0x44
    case Counter64 = 0x46
    case NoSuchObject = 0x80
    case NoSuchInstance = 0x81
    case EndOfMibView = 0x82
    
    func getBerType() throws -> BerTagedObject.Type {
        switch self {
        case .integer:
            return Int.self
        case .octetString:
            return String.self
        case .null:
            return BerNull.self
        case .objectID:
            return BerObjectId.self
        case .sequence:
            return BytesSequence.self
        case .ipAddress:
            return SNMPIpAddress.self
        case .timeTicks:
            return SNMPTimeTicks.self
        default:
            throw BerDecodeError.invalidTag
        }
    }
}

extension BerTag: BerEncodable {
    func berEncode() -> [UInt8] {
        return [rawValue]
    }
}

struct Length: BerEncodable {
    var value: Int
    
    func berEncode() throws -> [UInt8] {
        if value <= 0x7f {
            return [UInt8(value)]
        } else if value <= 0xff {
            return [0x81, UInt8(value)]
        } else if value <= 0xffff {
            return [0x82, UInt8((value & 0xff00) >> 8), UInt8(value & 0xff)]
        } else if value <= 0xffffff {
            return [0x83, UInt8((value & 0xff0000) >> 16), UInt8((value & 0xff00) >> 8), UInt8(value & 0xff)]
        } else {
            throw BerEncodeError.lengthTooLong
        }
    }
}

struct BytesSequence {
    var value: [UInt8]
}

struct BerNull {
    init() {}
}

struct BerObjectId {
    var value: String
}

struct SNMPIpAddress {
    var value: String
}

struct SNMPTimeTicks {
    var value: UInt
}
