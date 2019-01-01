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

/// SNMP NSM Server
public final class SNMPManager: Service {
    private let channel: Channel
    private var handler: SNMPQueueHandler
    
    public var onTrap: EventLoopFuture<SNMPMessage> {
        return handler.trapPromise.futureResult
    }
    
    public var onError: EventLoopFuture<Error> {
        return handler.errorPromise.futureResult
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
        let snmpParser = SNMPResponseParser()
        let queueHandler = SNMPQueueHandler(on: group)
        let bootstrap = DatagramBootstrap(group: group)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                return channel.pipeline.addHandlers([snmpParser, queueHandler], first: false)
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
    )  -> Future<SNMPMessage> {
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
    )  -> Future<SNMPMessage> {
        let requestId = Int.random(in: 0x1000000...0xfffffff)
        let vb = ValueBinds(dic)
        let pdu = SNMPBasicPDU(type: type, requestId: Int(requestId), errorStatus: .noError, errorIndex: 0, valueBinds: vb)
        let message = SNMPMessage(version: version, community: community, pdu: .basic(pdu))
        return send(request: message, uniqueId: requestId, hostname: hostname, port: port, timeout: timeout)
    }
    
    private func send(request: SNMPMessage, uniqueId: Int, hostname: String, port: Int, timeout: Int) -> Future<SNMPMessage> {
        let bytes: [UInt8]
        do {
            bytes = try request.berEncode()
        } catch {
            return channel.eventLoop.newFailedFuture(error: error)
        }
        var buffer = channel.allocator.buffer(capacity: bytes.count)
        buffer.write(bytes: bytes)
        let ms = AddressedEnvelope(remoteAddress: try! SocketAddress.newAddressResolving(host: hostname, port: port), data: buffer)
        return send(ms, uniqueId: uniqueId, timeout: timeout)
    }

    private func send(_ request: AddressedEnvelope<ByteBuffer>, uniqueId: Int, timeout: Int) -> Future<SNMPMessage> {
        var res: SNMPMessage?
        return handler.enqueue([request], inputKey: uniqueId, timeout: timeout) { message in
            res = message
        }.map(to: SNMPMessage.self) {
            return res!
        }
    }
}

private final class SNMPResponseParser: ChannelInboundHandler {
    typealias InboundIn = AddressedEnvelope<ByteBuffer>
    typealias OutboundOut = SNMPMessage
    
    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        var buffer = unwrapInboundIn(data).data
        var bytes: [UInt8] = []
        while let byte = buffer.readBytes(length: 1) {
            bytes += byte
        }
        let decoder = SNMPDecoder()
        do {
            let res = try decoder.decode(bytes)
            ctx.fireChannelRead(wrapOutboundOut(res))
        } catch {
            ctx.fireErrorCaught(error)
        }
    }
}

private final class SNMPQueueHandler: ChannelInboundHandler {
    typealias InboundIn = SNMPMessage
    typealias OutboundOut = AddressedEnvelope<ByteBuffer>
    
    private var inputQueue: [Int: InputContext<InboundIn>]
    private var outputQueue: [[AddressedEnvelope<ByteBuffer>]]
    
    private let eventLoop: EventLoop
    private weak var waitingCtx: ChannelHandlerContext?
    internal var trapPromise: EventLoopPromise<SNMPMessage>
    internal var errorPromise: EventLoopPromise<Error>
    
    init(on worker: Worker) {
        self.inputQueue = [:]
        self.outputQueue = []
        self.eventLoop = worker.eventLoop
        self.trapPromise = worker.eventLoop.newPromise()
        self.errorPromise = worker.eventLoop.newPromise()
    }

    func enqueue(_ output: [AddressedEnvelope<ByteBuffer>], inputKey: Int, timeout: Int, onInput: @escaping (InboundIn) throws -> Void) -> Future<Void> {
        guard eventLoop.inEventLoop else {
            return eventLoop.submit {
                // do nothing
            }.flatMap {
                // perform this on the event loop
                return self.enqueue(output, inputKey: inputKey, timeout: timeout, onInput: onInput)
            }
        }
        outputQueue.insert(output, at: 0)
        let promise = eventLoop.newPromise(Void.self)
        let context = InputContext<InboundIn>(promise: promise, onInput: onInput)
        inputQueue[inputKey] = context
        eventLoop.scheduleTask(in: TimeAmount.seconds(timeout)) { [unowned self]  in
            guard let onInputToRemove = self.inputQueue[inputKey] else { return }
            onInputToRemove.promise.fail(error: SNMPManagerError.equipmentNoResponse)
            self.inputQueue.removeValue(forKey: inputKey)
        }
        if let ctx = waitingCtx {
            ctx.eventLoop.execute {
                self.writeOutputIfEnqueued(ctx: ctx)
            }
        }
        return promise.futureResult
    }
    
    private func writeOutputIfEnqueued(ctx: ChannelHandlerContext) {
        while let next = outputQueue.popLast() {
            for output in next {
                ctx.write(wrapOutboundOut(output), promise: nil)
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
                do {
                    try current.onInput(input)
                    current.promise.succeed()
                    inputQueue.removeValue(forKey: requestID)
                } catch {
                    current.promise.fail(error: error)
                    inputQueue.removeValue(forKey: requestID)
                }
            }
        case .trap, .v2cTrap:
            trapPromise.succeed(result: input)
        default:
            return
        }
    }
    
    func channelActive(ctx: ChannelHandlerContext) {
        writeOutputIfEnqueued(ctx: ctx)
    }
    
    func errorCaught(ctx: ChannelHandlerContext, error: Error) {
        errorPromise.succeed(result: error)
    }
}

fileprivate struct InputContext<In> {
    var promise: Promise<Void>
    var onInput: (In) throws -> Void
}
