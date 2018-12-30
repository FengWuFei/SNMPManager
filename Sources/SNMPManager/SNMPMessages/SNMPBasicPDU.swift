public struct SNMPBasicPDU {
    public var pduType: PDUType
    public var requestId: Int
    public var errorStatus: ErrorStatus
    public var errorIndex: Int
    public var valueBinds: ValueBinds
    
    public init(type: PDUType, requestId: Int, errorStatus: ErrorStatus, errorIndex: Int, valueBinds: ValueBinds) {
        self.pduType = type
        self.requestId = requestId
        self.errorStatus = errorStatus
        self.errorIndex = errorIndex
        self.valueBinds = valueBinds
    }
}
