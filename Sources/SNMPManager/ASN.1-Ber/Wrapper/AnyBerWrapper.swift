struct AnyBerWrapper<Value: BerEncodable>: BerObject {
    var tag: BerEncodable
    var value: Value
    
    init(tag: BerEncodable, value: Value) {
        self.tag = tag
        self.value = value
    }
}
