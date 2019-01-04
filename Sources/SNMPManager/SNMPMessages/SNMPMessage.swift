public enum SNMPVersion: Int {
    case v1 = 0
    case v2c = 1
}

public enum PDU {
    case basic(SNMPBasicPDU)
    case v1Trap(SNMPTrapPDU)
    
    public var type: PDUType {
        switch self {
        case .basic(let pdu):
            return pdu.pduType
        case .v1Trap(let pdu):
            return pdu.pduType
        }
    }
}

public struct SNMPMessage {
    public var version: SNMPVersion
    public var community: String
    public var pdu: PDU
    public var valueBinds: [String: BerTagedObject] {
        switch pdu {
        case .basic(let pdu):
            return pdu.valueBinds
        case .v1Trap(let pdu):
            return pdu.valueBinds
        }
    }
    
    public init(version: SNMPVersion, community: String, pdu: PDU) {
        self.version = version
        self.community = community
        self.pdu = pdu
    }
}
