extension Int: BerTagedObject {
    public static var tag: BerEncodable {
        return BerTag.integer
    }
    
    public var codableValue: Codable {
        return self
    }
}

extension String: BerTagedObject {
    public static var tag: BerEncodable {
        return BerTag.octetString
    }
    
    public var codableValue: Codable {
        return self
    }
}

extension BerNull: BerTagedObject {
    public static var tag: BerEncodable {
        return BerTag.null
    }
    
    public var codableValue: Codable {
        return "BerNull"
    }
}

extension BerObjectId: BerTagedObject {
    public static var tag: BerEncodable {
        return BerTag.objectID
    }
    
    public var codableValue: Codable {
        return self.oid
    }
}

extension BytesSequence: BerTagedObject {
    public static var tag: BerEncodable {
        return BerTag.sequence
    }
    
    public var codableValue: Codable {
        return self.value
    }
}

extension SNMPIpAddress: BerTagedObject {
    public static var tag: BerEncodable {
        return BerTag.ipAddress
    }
    
    public var codableValue: Codable {
        return self.value
    }
}

extension SNMPTimeTicks: BerTagedObject {
    public static var tag: BerEncodable {
        return BerTag.timeTicks
    }
    
    public var codableValue: Codable {
        return self.value
    }
}
