public enum BerDecodeError: Error {
    case outOfRange
    case invalidTag
    case indefiniteLength, lengthTooLong, lengthLostBytes
    case nullString, wrongIntBytes, wrongOID
    case invalidNull
}

public enum BerEncodeError: Error {
    case intValueTooLong
    case uIntValueTooLong
    case lengthTooLong
    case invalidIPAddress
}

public enum SnmpError: Error {
    case invalidVersion, invalidPDUType, invalidErrorStatus
}
