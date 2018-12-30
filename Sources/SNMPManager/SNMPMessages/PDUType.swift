public enum PDUType: UInt8 {
    case get = 0xa0
    case getNext = 0xa1
    case res = 0xa2
    case set = 0xa3
    case trap = 0xa4
    case getBulk = 0xa5
    case inform = 0xa6
    case v2cTrap = 0xa7
    case report = 0xa8
}
