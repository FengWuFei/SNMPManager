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
        let queueHandler = SNMPQueueHandler(on: group)
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
        return send(
            .get,
            dic: oids.map { ($0, BerNull()) },
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
        _ dic: [(String, BerTagedObject)],
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
        dic: [(key: String, value: BerTagedObject)],
        version: SNMPVersion,
        community: String,
        hostname: String,
        port: Int,
        timeout: Int
        ) -> Future<SNMPMessage> {
        let requestId = Int.random(in: 0x1000000...0xfffffff)
        let vb = ValueBinds(dic)
        let pdu = SNMPBasicPDU(type: type, requestId: Int(requestId), errorStatus: .noError, errorIndex: 0, valueBinds: vb)
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
        return handler.enqueue([message], inputKey: uniqueId, timeout: timeout)
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

private struct SNMPOutMessage {
    var remoteAddress: SocketAddress
    var message: SNMPMessage
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

private final class SNMPQueueHandler: ChannelInboundHandler {
    typealias InboundIn = SNMPMessage
    typealias OutboundOut = SNMPOutMessage
    
    private var inputQueue: [Int: InputContext<InboundIn>]
    private var outputQueue: [OutputContext]
    
    private let eventLoop: EventLoop
    private weak var waitingCtx: ChannelHandlerContext?
    var onTrap: TrapHandler?
    var onError: ErrorHandler?
    
    init(on worker: Worker) {
        self.inputQueue = [:]
        self.outputQueue = []
        self.eventLoop = worker.eventLoop
    }
    
    func enqueue(_ output: [SNMPOutMessage], inputKey: Int, timeout: Int) -> Future<InboundIn> {
        guard eventLoop.inEventLoop else {
            return eventLoop.submit {
                // do nothing
                }.flatMap {
                    // perform this on the event loop
                    return self.enqueue(output, inputKey: inputKey, timeout: timeout)
            }
        }
        let outputPromise = eventLoop.newPromise(Void.self)
        let outputContext = OutputContext(promise: outputPromise, message: output)
        let inputPromise = eventLoop.newPromise(InboundIn.self)
        let inputContext = InputContext<InboundIn>(promise: inputPromise)
        outputQueue.insert(outputContext, at: 0)
        inputQueue[inputKey] = inputContext
        eventLoop.scheduleTask(in: TimeAmount.seconds(timeout)) { [unowned self]  in
            self.inputQueue[inputKey]?.promise.fail(error: SNMPManagerError.equipmentNoResponse)
        }
        if let ctx = waitingCtx {
            ctx.eventLoop.execute {
                self.writeOutputIfEnqueued(ctx: ctx)
            }
        }
        return outputPromise.futureResult.and(inputPromise.futureResult)
            .always { [unowned self] in
                self.inputQueue.removeValue(forKey: inputKey)
            }
            .map { $1 }
    }
    
    private func writeOutputIfEnqueued(ctx: ChannelHandlerContext) {
        while let next = outputQueue.popLast() {
            for output in next.message {
                ctx.write(wrapOutboundOut(output), promise: next.promise)
            }
            ctx.flush()
        }
        waitingCtx = ctx
    }
    
    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        let input = unwrapInboundIn(data)
        let pduType = input.pdu.type
        switch pduType {
        case .res:
            if case let PDU.basic(pdu) = input.pdu {
                let requestID = pdu.requestId
                guard let current = inputQueue[requestID] else {
                    return
                }
                current.promise.succeed(result: input)
            }
        case .trap, .v2cTrap:
            onTrap?(input)
        default:
            return
        }
    }
    
    func channelActive(ctx: ChannelHandlerContext) {
        writeOutputIfEnqueued(ctx: ctx)
    }
    
    func errorCaught(ctx: ChannelHandlerContext, error: Error) {
        onError?(error)
    }
}

fileprivate struct InputContext<In> {
    var promise: Promise<In>
}

fileprivate struct OutputContext {
    var promise: Promise<Void>
    var message: [SNMPOutMessage]
}
