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
    static var tag: BerEncodable {
        return BerTag.null
    }
    
    var codableValue: Codable {
        return "BerNull"
    }
}

extension BerObjectId: BerTagedObject {
    static var tag: BerEncodable {
        return BerTag.objectID
    }
    
    var codableValue: Codable {
        return self.value
    }
}

extension BytesSequence: BerTagedObject {
    static var tag: BerEncodable {
        return BerTag.sequence
    }
    
    var codableValue: Codable {
        return self.value
    }
}

extension SNMPIpAddress: BerTagedObject {
    static var tag: BerEncodable {
        return BerTag.ipAddress
    }
    
    var codableValue: Codable {
        return self.value
    }
}

extension SNMPTimeTicks: BerTagedObject {
    static var tag: BerEncodable {
        return BerTag.timeTicks
    }
    
    var codableValue: Codable {
        return self.value
    }
}
