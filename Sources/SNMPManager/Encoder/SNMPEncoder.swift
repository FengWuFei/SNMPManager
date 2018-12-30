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
        let _valueBinds = valueBinds
        let value: [BerEncodable] = [_requestId, _errorStatus, _errorIndex, _valueBinds]
        return try AnyBerWrapper(tag: pduType, value: value).berEncode()
    }
}

extension SNMPTrapPDU: BerEncodable {
    public func berEncode() throws -> [UInt8] {
        let _enterprise = BerWrapper(BerObjectId(value: enterprise))
        let _agentAddress = BerWrapper(SNMPIpAddress(value: agentAddress))
        let _generic =  BerWrapper(generic)
        let _specific = BerWrapper(specific)
        let _valueBinds = valueBinds
        let value: [BerEncodable] = [_enterprise, _agentAddress, _generic, _specific, _valueBinds]
        return try AnyBerWrapper(tag: pduType, value: value).berEncode()
    }
}

extension ValueBinds: BerEncodable {
    public func berEncode() throws -> [UInt8] {
        let bytes = try dic.reduce([]) { (res, element) throws -> [UInt8] in
            do {
                let data = try BerObjectId(value: element.key).wrapedAndEncode() + element.value.wrapedAndEncode()
                return try res + BytesSequence(value: data).wrapedAndEncode()
            } catch {
                throw error
            }
        }
        return try BytesSequence(value: bytes).wrapedAndEncode()
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
