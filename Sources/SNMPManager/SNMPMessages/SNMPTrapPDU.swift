public struct SNMPTrapPDU {
    public let pduType: PDUType = .trap
    public var enterprise: String
    public var agentAddress: String
    public var generic: Int
    public var specific: Int
    public var valueBinds: ValueBinds
    
    public init(enterprise: String, agentAddress: String, generic: Int, specific: Int, valueBinds: ValueBinds) {
        self.enterprise = enterprise
        self.agentAddress = agentAddress
        self.generic = generic
        self.specific = specific
        self.valueBinds = valueBinds
    }
}
