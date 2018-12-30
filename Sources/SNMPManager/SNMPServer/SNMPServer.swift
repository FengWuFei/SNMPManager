import Vapor

public enum SNMPManagerError: String, Error, Debuggable {
    case equipmentNoResponse
    
    public var identifier: String {
        return "SNMPManagerError"
    }
    public var reason: String {
        return self.rawValue
    }
}

public final class SNMPManager: Service {
    private let channel: Channel
    private var handler: SNMPQueueHandler
    private var eventLoop: EventLoop {
        return channel.eventLoop
    }
    public var onClose: EventLoopFuture<Void> {
        return channel.closeFuture
    }

    public static func start(
        hostname: String,
        port: Int,
        on group: EventLoopGroup,
        onError: @escaping (Error) -> () = { _ in },
        onTrap: @escaping (SNMPMessage) -> () = { _ in }
        ) -> EventLoopFuture<SNMPManager> {
        let snmpParser = SNMPResponseParser()
        let queueHandler = SNMPQueueHandler(on: group, onError: onError, onTrap: onTrap)
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
    
    public func get(
        _ oids: [String],
        version: SNMPVersion = .v2c,
        community: String,
        hostname: String,
        port: Int = 161
    )  -> Future<SNMPMessage> {
        return send(.get,
                    dic: oids.map { ($0, BerNull()) },
                    version: version,
                    community: community,
                    hostname: hostname, port: port)
    }
    
    public func set(
        _ dic: [(String, BerTagedObject)],
        version: SNMPVersion = .v2c,
        community: String,
        hostname: String,
        port: Int = 161
    )  -> Future<SNMPMessage> {
        return send(.set,
                    dic: dic,
                    version: version,
                    community: community,
                    hostname: hostname, port: port)
    }
    
    private func send(
        _ type: PDUType,
        dic: [(key: String, value: BerTagedObject)],
        version: SNMPVersion,
        community: String,
        hostname: String,
        port: Int
    )  -> Future<SNMPMessage> {
        let requestId = UInt32.random(in: 0x01010101...0xffffffff)
        let vb = ValueBinds(dic)
        let pdu = SNMPBasicPDU(type: type, requestId: Int(requestId), errorStatus: .noError, errorIndex: 0, valueBinds: vb)
        let message = SNMPMessage(version: version, community: community, pdu: .basic(pdu))
        return send(request: message, uniqueId: Int(requestId), hostname: hostname, port: port)
    }
    
    private func send(request: SNMPMessage, uniqueId: Int, hostname: String, port: Int) -> Future<SNMPMessage> {
        let bytes: [UInt8]
        do {
            bytes = try request.berEncode()
        } catch {
            return channel.eventLoop.newFailedFuture(error: error)
        }
        var buffer = channel.allocator.buffer(capacity: bytes.count)
        buffer.write(bytes: bytes)
        let ms = AddressedEnvelope(remoteAddress: try! SocketAddress.newAddressResolving(host: hostname, port: port), data: buffer)
        return send(ms, uniqueId: uniqueId)
    }

    private func send(_ request: AddressedEnvelope<ByteBuffer>, uniqueId: Int) -> Future<SNMPMessage> {
        var res: SNMPMessage?
        return handler.enqueue([request], inputKey: uniqueId) { message in
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
        let decoder = SnmpDecoder()
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
    private var errorHandler: (Error) -> ()
    private var trapHandler: (SNMPMessage) -> ()
    
    init(
        on worker: Worker,
        onError: @escaping (Error) -> (),
        onTrap: @escaping (SNMPMessage) -> ()
    ) {
        self.inputQueue = [:]
        self.outputQueue = []
        self.eventLoop = worker.eventLoop
        self.errorHandler = onError
        self.trapHandler = onTrap
    }

    func enqueue(_ output: [AddressedEnvelope<ByteBuffer>], inputKey: Int, onInput: @escaping (InboundIn) throws -> Void) -> Future<Void> {
        guard eventLoop.inEventLoop else {
            return eventLoop.submit {
                // do nothing
            }.flatMap {
                // perform this on the event loop
                return self.enqueue(output, inputKey: inputKey, onInput: onInput)
            }
        }
        outputQueue.insert(output, at: 0)
        let promise = eventLoop.newPromise(Void.self)
        let context = InputContext<InboundIn>(promise: promise, onInput: onInput)
        inputQueue[inputKey] = context
        eventLoop.scheduleTask(in: TimeAmount.seconds(5)) { [unowned self]  in
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
            trapHandler(input)
        default:
            return
        }
    }
    
    func channelActive(ctx: ChannelHandlerContext) {
        writeOutputIfEnqueued(ctx: ctx)
    }
    
    func errorCaught(ctx: ChannelHandlerContext, error: Error) {
        errorHandler(error)
    }
}

fileprivate struct InputContext<In> {
    var promise: Promise<Void>
    var onInput: (In) throws -> Void
}
