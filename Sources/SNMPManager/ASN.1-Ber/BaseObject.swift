import Foundation

public enum BerTag: UInt8 {
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
    public func berEncode() -> [UInt8] {
        return [rawValue]
    }
}

public struct Length: BerEncodable {
    public var value: Int
    
    public func berEncode() throws -> [UInt8] {
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

public struct BytesSequence {
    var value: [UInt8]
}

public struct BerNull {
    public init() {}
}

public struct BerObjectId {
    public var oid: String
    
    public init?(_ oid: String) {
        guard NSPredicate(format: "SELF MATCHES %@", "^([0-9]+\\\(".")){3,}[0-9]+$")
            .evaluate(with: oid) else {
                return nil
        }
        self.oid = oid
    }
}

public struct SNMPIpAddress {
    public var value: String
}

public struct SNMPTimeTicks {
    public var value: UInt
}
