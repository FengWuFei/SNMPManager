public struct SNMPTrapPDU {
    public let pduType: PDUType = .trap
    public var enterprise: String
    public var agentAddress: String
    public var generic: Int
    public var specific: Int
    public var timeStamp: UInt
    public var valueBinds: [String: BerTagedObject]
    
    public init(enterprise: String, agentAddress: String, generic: Int, specific: Int, timeStamp: UInt, valueBinds: [String: BerTagedObject]) {
        self.enterprise = enterprise
        self.agentAddress = agentAddress
        self.generic = generic
        self.specific = specific
        self.timeStamp = timeStamp
        self.valueBinds = valueBinds
    }
}
