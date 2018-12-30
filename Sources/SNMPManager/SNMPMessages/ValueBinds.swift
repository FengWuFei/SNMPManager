public struct ValueBinds {
    public var dic: [(key: String, value: BerTagedObject)]
    public init(_ dic: [(key: String, value: BerTagedObject)]) {
        self.dic = dic
    }
}
