extension Array where Element == UInt8 {
    public func toHex() -> [String] {
        return map { String($0, radix: 16) }
    }
}
