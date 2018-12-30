public struct AnyBerWrapper<Value: BerEncodable>: BerObject {
    public var tag: BerEncodable
    public var value: Value
    
    public init(tag: BerEncodable, value: Value) {
        self.tag = tag
        self.value = value
    }
}
