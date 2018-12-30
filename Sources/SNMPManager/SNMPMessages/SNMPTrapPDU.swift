public struct SNMPTrapPDU {
    public let pduType: PDUType = .trap
    public var enterprise: BerObjectId
    public var agentAddress: SNMPIpAddress
    public var generic: Int
    public var specific: Int
    public var valueBinds: ValueBinds
    
    public init(enterprise: BerObjectId, agentAddress: SNMPIpAddress, generic: Int, specific: Int, valueBinds: ValueBinds) {
        self.enterprise = enterprise
        self.agentAddress = agentAddress
        self.generic = generic
        self.specific = specific
        self.valueBinds = valueBinds
    }
}
