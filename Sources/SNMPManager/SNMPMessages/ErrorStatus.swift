public enum ErrorStatus: UInt8 {
    case noError = 0x00
    case tooBig = 0x01
    case noSuchName = 0x02
    case badValue = 0x03
    case readOnly = 0x04
    case generalError = 0x05
    case noAccess = 0x06
    case wrongType = 0x07
    case wrongLength = 0x08
    case wrongEncoding = 0x09
    case wrongValue = 0x0a
    case noCreation = 0x0b
    case inconsistentValue = 0x0c
    case resourceUnavailable = 0x0d
    case commitFailed = 0x0e
    case undoFailed = 0x0f
    case authorizationError = 0x10
    case notWritable = 0x11
    case inconsistentName = 0x12
}
