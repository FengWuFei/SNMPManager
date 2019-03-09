import Vapor

public enum SNMPManagerError: String, Error, Debuggable {
    case equipmentNoResponse
    
    public var identifier: String {
        return "SNMPManager"
    }
    public var reason: String {
        return self.rawValue
    }
}

public typealias TrapHandler = (SNMPMessage) -> Void
public typealias ErrorHandler = (Error) -> Void

/// SNMP NSM Server
public final class SNMPManager: Service {
    private let channel: Channel
    private var handler: SNMPQueueHandler
    
    public var onTrap: TrapHandler? {
        didSet {
            handler.onTrap = onTrap
        }
    }
    public var onError: ErrorHandler? {
        didSet {
            handler.onError = onError
        }
    }
    
    public var eventLoop: EventLoop {
        return channel.eventLoop
    }
    
    public var onClose: EventLoopFuture<Void> {
        return channel.closeFuture
    }
    
    /// Start a Datagram Server and bind to the host & port
    ///
    /// - Parameters:
    ///   - hostname: The hostname to bind on
    ///   - port: The port to bind on
    ///   - group: The eventLoopGroup to run
    /// - Returns: future SNMPManager
    public static func start(
        hostname: String,
        port: Int,
        on group: EventLoopGroup
    ) -> EventLoopFuture<SNMPManager> {
        let snmpDecoder = SNMPMessageDecoder()
        let snmpEncoder = SNMPMessageEncoder()
        let queueHandler = SNMPQueueHandler()
        let bootstrap = DatagramBootstrap(group: group)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                return channel.pipeline.addHandlers([snmpDecoder, snmpEncoder, queueHandler], first: false)
        }
        return bootstrap.bind(host: hostname, port: port)
            .map { SNMPManager(channel: $0, handler: queueHandler) }
    }
    
    private init(channel: Channel, handler: SNMPQueueHandler) {
        self.channel = channel
        self.handler = handler
    }
    
    public func close() -> EventLoopFuture<Void> {
        return channel.close(mode: .all)
    }
    
    /// SNMP get method
    ///
    /// Example:
    ///
    /// ```swift
    ///     let message = nsm.get(["1.3.6.5.1.1.0"], community: "public", hostname: "10.3.10.1")
    /// ```
    ///
    /// - Parameters:
    ///   - oids: oid array
    ///   - version: SNMP version
    ///   - community: community string
    ///   - hostname: endpoint hostname
    ///   - port: endpoint port
    ///   - timeout: wait timeout
    /// - Returns: future SNMPMessage
    public func get(
        _ oids: [String],
        version: SNMPVersion = .v2c,
        community: String,
        hostname: String,
        port: Int = 161,
        timeout: Int = 15
        )  -> Future<SNMPMessage> {
        var dic: [String: BerTagedObject] = [:]
        oids.forEach { dic[$0] = BerNull() }
        return send(
            .get,
            dic: dic,
            version: version,
            community: community,
            hostname: hostname,
            port: port,
            timeout: timeout
        )
    }
    
    /// SNMP set method
    ///
    /// - Parameters:
    ///   - oids: oid array
    ///   - version: SNMP version
    ///   - community: community string
    ///   - hostname: endpoint hostname
    ///   - port: endpoint port
    ///   - timeout: wait timeout
    /// - Returns: future SNMPMessage
    public func set(
        dic: [String: BerTagedObject],
        version: SNMPVersion = .v2c,
        community: String,
        hostname: String,
        port: Int = 161,
        timeout: Int = 15
        ) -> Future<SNMPMessage> {
        return send(
            .set,
            dic: dic,
            version: version,
            community: community,
            hostname: hostname,
            port: port,
            timeout: timeout
        )
    }
    
    private func send(
        _ type: PDUType,
        dic: [String: BerTagedObject],
        version: SNMPVersion,
        community: String,
        hostname: String,
        port: Int,
        timeout: Int
        ) -> Future<SNMPMessage> {
        let requestId = Int.random(in: 0x1000000...0xfffffff)
        let pdu = SNMPBasicPDU(type: type, requestId: Int(requestId), errorStatus: .noError, errorIndex: 0, valueBinds: dic)
        let message = SNMPMessage(version: version, community: community, pdu: .basic(pdu))
        return send(message: message, uniqueId: requestId, hostname: hostname, port: port, timeout: timeout)
    }
    
    private func send(message: SNMPMessage, uniqueId: Int, hostname: String, port: Int, timeout: Int) -> Future<SNMPMessage> {
        do {
            let address = try SocketAddress.newAddressResolving(host: hostname, port: port)
            let ms = SNMPOutMessage(remoteAddress: address, message: message)
            return send(ms, uniqueId: uniqueId, timeout: timeout)
        } catch {
            return channel.eventLoop.newFailedFuture(error: error)
        }
    }
    
    private func send(_ message: SNMPOutMessage, uniqueId: Int, timeout: Int) -> Future<SNMPMessage> {
        let inboundPromise = channel.eventLoop.newPromise(SNMPMessage.self)
        let outboundPromise = channel.eventLoop.newPromise(Void.self)
        let context = SNMPClientRequestContext(
            message: message,
            uniqueId: uniqueId,
            timeout: timeout,
            inboundPromise: inboundPromise
        )
        self.channel.write(context, promise: outboundPromise)
        return outboundPromise.futureResult
            .and(inboundPromise.futureResult)
            .map { $1 }
    }
}

private final class SNMPMessageDecoder: ChannelInboundHandler {
    typealias InboundIn = AddressedEnvelope<ByteBuffer>
    typealias InboundOut = SNMPMessage
    
    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        var buffer = unwrapInboundIn(data).data
        var bytes: [UInt8] = []
        while let byte = buffer.readBytes(length: 1) {
            bytes += byte
        }
        let decoder = SNMPDecoder()
        do {
            let res = try decoder.decode(bytes)
            ctx.fireChannelRead(wrapInboundOut(res))
        } catch {
            ctx.fireErrorCaught(error)
        }
    }
}

private final class SNMPMessageEncoder: ChannelOutboundHandler {
    typealias OutboundIn = SNMPOutMessage
    typealias OutboundOut = AddressedEnvelope<ByteBuffer>
    
    func write(ctx: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let outMessage = self.unwrapOutboundIn(data)
        do {
            let bytes = try outMessage.message.berEncode()
            var buffer = ctx.channel.allocator.buffer(capacity: bytes.count)
            buffer.write(bytes: bytes)
            let udpMessage = AddressedEnvelope(remoteAddress: outMessage.remoteAddress, data: buffer)
            ctx.write(self.wrapOutboundOut(udpMessage), promise: promise)
        } catch {
            promise?.fail(error: error)
        }
    }
}

private final class SNMPQueueHandler: ChannelDuplexHandler {
    typealias OutboundIn = SNMPClientRequestContext
    typealias OutboundOut = SNMPOutMessage
    typealias InboundIn = SNMPMessage
    
    private var queue: [Int: SNMPClientRequestContext]
    var onTrap: TrapHandler?
    var onError: ErrorHandler?
    
    init() {
        self.queue = [:]
    }

    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        let res = unwrapInboundIn(data)
        let pduType = res.pdu.type
        switch pduType {
        case .res:
            if case let PDU.basic(pdu) = res.pdu {
                let requestID = pdu.requestId
                guard let current = queue[requestID] else { return }
                current.inboundPromise.succeed(result: res)
                queue.removeValue(forKey: requestID)
            }
        case .trap, .v2cTrap:
            onTrap?(res)
        default:
            return
        }
    }
    
    func write(ctx: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let req = self.unwrapOutboundIn(data)
        queue[req.uniqueId] = req
        ctx.write(self.wrapOutboundOut(req.message), promise: promise)
        ctx.eventLoop.scheduleTask(in: TimeAmount.seconds(req.timeout)) { [unowned self]  in
            self.queue[req.uniqueId]?.inboundPromise.fail(error: SNMPManagerError.equipmentNoResponse)
            self.queue.removeValue(forKey: req.uniqueId)
        }
        ctx.flush()
    }
    
    func errorCaught(ctx: ChannelHandlerContext, error: Error) {
        onError?(error)
    }
}

fileprivate struct SNMPOutMessage {
    var remoteAddress: SocketAddress
    var message: SNMPMessage
}

fileprivate struct SNMPClientRequestContext {
    var message: SNMPOutMessage
    var uniqueId: Int
    var timeout: Int
    var inboundPromise: EventLoopPromise<SNMPMessage>
}
