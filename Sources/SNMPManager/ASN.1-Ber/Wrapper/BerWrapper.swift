struct BerWrapper<Value: BerTagedObject>: BerObject {
    var tag: BerEncodable  {
        return Value.tag
    }
    var value: Value
    
    init(_ value: Value) {
        self.value = value
    }
}



