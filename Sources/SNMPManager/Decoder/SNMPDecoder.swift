final class SnmpDecoder {
    lazy var decoder = BerDecoder()
    init() {}
    
    func decode(_ bytes: [UInt8]) throws -> SNMPMessage {
        decoder.set(bytes)
        do {
            try decoder.readSequence()
            let _version: Int = try decoder.readValue()
            guard let version = SNMPVersion(rawValue: _version) else {
                throw BerDecodeError.invalidVersion
            }
            
            let community: String = try decoder.readValue()
            
            let _pduType = try decoder.readPduType()
            guard let pduType = PDUType(rawValue: _pduType) else { throw BerDecodeError.invalidPDUType }
            
            let pdu: PDU
            
            var valueBinds = ValueBinds([])
         
            if pduType == .trap {
                let enterprise: BerObjectId = try decoder.readValue()
                let agentAddress: SNMPIpAddress = try decoder.readValue()
                let generic: Int = try decoder.readValue()
                let specific: Int = try decoder.readValue()
                valueBinds.dic = try decoder.readValueBinds()
                pdu = .v1Trap(SNMPTrapPDU(enterprise: enterprise.value, agentAddress: agentAddress.value, generic: generic, specific: specific, valueBinds: valueBinds))
            } else {
                let requestId: Int = try decoder.readValue()
                let _errorStatus: Int = try decoder.readValue()
                guard let errorStatus = ErrorStatus(rawValue: UInt8(_errorStatus)) else {
                    throw BerDecodeError.invalidErrorStatus
                }
                let errorIndex: Int = try decoder.readValue()
                valueBinds.dic = try decoder.readValueBinds()
                pdu = .basic(SNMPBasicPDU(type: pduType, requestId: requestId, errorStatus: errorStatus, errorIndex: errorIndex, valueBinds: valueBinds))
            }
            return SNMPMessage(version: version, community: community, pdu: pdu)
        } catch {
            throw error
        }
    }
}
