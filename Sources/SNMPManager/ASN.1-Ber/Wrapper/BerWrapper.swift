public struct BerWrapper<Value: BerTagedObject>: BerObject {
    public var tag: BerEncodable  {
        return Value.tag
    }
    public var value: Value
    
    public init(_ value: Value) {
        self.value = value
    }
}



