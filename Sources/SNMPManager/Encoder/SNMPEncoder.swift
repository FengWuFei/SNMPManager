extension SNMPMessage: BerEncodable {
    public func berEncode() throws -> [UInt8] {
        let _version = BerWrapper(version.rawValue)
        let _community = BerWrapper(community)
        let _pdu = pdu
        let value: [BerEncodable] = [_version, _community, _pdu]
        return try BytesSequence(value: value.berEncode()).wrapedAndEncode()
    }
}

extension PDU: BerEncodable {
    public func berEncode() throws -> [UInt8] {
        switch self {
        case .basic(let pdu):
            return try pdu.berEncode()
        case .v1Trap(let pdu):
            return try pdu.berEncode()
        }
    }
}

extension SNMPBasicPDU: BerEncodable {
    public func berEncode() throws -> [UInt8] {
        let _requestId = BerWrapper(requestId)
        let _errorStatus = errorStatus
        let _errorIndex = BerWrapper(errorIndex)
        let value: [BerEncodable] = [_requestId, _errorStatus, _errorIndex, valueBinds]
        return try AnyBerWrapper(tag: pduType, value: value).berEncode()
    }
}

extension SNMPTrapPDU: BerEncodable {
    public func berEncode() throws -> [UInt8] {
        let _enterprise = BerWrapper(BerObjectId(value: enterprise))
        let _agentAddress = BerWrapper(SNMPIpAddress(value: agentAddress))
        let _generic =  BerWrapper(generic)
        let _specific = BerWrapper(specific)
        let value: [BerEncodable] = [_enterprise, _agentAddress, _generic, _specific, valueBinds]
        return try AnyBerWrapper(tag: pduType, value: value).berEncode()
    }
}

extension ErrorStatus: BerEncodable {
    public func berEncode() throws -> [UInt8] {
        return try BerWrapper(Int((self.rawValue))).berEncode()
    }
}

extension PDUType: BerEncodable {
    public func berEncode() -> [UInt8] {
        return [self.rawValue]
    }
}
