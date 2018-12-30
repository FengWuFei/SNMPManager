import Vapor

public enum BerDecodeError: String, Error, Debuggable {
    case outOfRange
    case invalidTag
    case indefiniteLength, lengthTooLong, lengthLostBytes
    case nullString, wrongIntBytes
    case invalidNull
    case invalidVersion, invalidPDUType, invalidErrorStatus
    
    public var identifier: String {
        return "SNMPManagerDecodeError"
    }
    public var reason: String {
        return self.rawValue
    }
}

public enum BerEncodeError: String, Error, Debuggable {
    case intValueTooLong
    case uIntValueTooLong
    case lengthTooLong
    case invalidIPAddress
    case intValueOID
    
    public var identifier: String {
        return "SNMPManagerEncodeError"
    }
    public var reason: String {
        return self.rawValue
    }
}
