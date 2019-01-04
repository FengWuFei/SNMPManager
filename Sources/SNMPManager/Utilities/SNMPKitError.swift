import Vapor

public struct BerDecodeError: Error, Debuggable {
    public static var outOfRange = BerDecodeError(reason: "outOfRange")
    public static var invalidTag = BerDecodeError(reason: "invalidTag")
    public static var indefiniteLength = BerDecodeError(reason: "indefiniteLength")
    public static var lengthTooLong = BerDecodeError(reason: "lengthTooLong")
    public static var lengthLostBytes = BerDecodeError(reason: "lengthLostBytes")
    public static var nullString = BerDecodeError(reason: "nullString")
    public static var wrongIntBytes = BerDecodeError(reason: "wrongIntBytes")
    public static var invalidNull = BerDecodeError(reason: "invalidNull")
    public static var invalidVersion = BerDecodeError(reason: "invalidVersion")
    public static var invalidPDUType = BerDecodeError(reason: "invalidPDUType")
    public static var invalidErrorStatus = BerDecodeError(reason: "invalidErrorStatus")
    
    public var identifier: String {
        return "SNMPManagerDecodeError"
    }
    public var reason: String
    
    public init(reason: String) {
        self.reason = reason
    }
    
    public mutating func addReason(reason: String) -> BerDecodeError {
        let error = BerDecodeError(reason: self.reason + ":" + reason)
        return error
    }
}

public struct BerEncodeError: Error, Debuggable {
    public static var intValueTooLong = BerDecodeError(reason: "intValueTooLong")
    public static var uIntValueTooLong = BerDecodeError(reason: "uIntValueTooLong")
    public static var lengthTooLong = BerDecodeError(reason: "lengthTooLong")
    public static var invalidIPAddress = BerDecodeError(reason: "invalidIPAddress")
    public static var intValueOID = BerDecodeError(reason: "intValueOID")
    
    public var identifier: String {
        return "SNMPManagerEncodeError"
    }
    public var reason: String
    
    public init(reason: String) {
        self.reason = reason
    }
    
    public mutating func addReason(reason: String) -> BerEncodeError {
        let error = BerEncodeError(reason: self.reason + ":" + reason)
        return error
    }
}
