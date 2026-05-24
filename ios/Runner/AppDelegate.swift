import Flutter
import UIKit
import CallKit
import PushKit

@main
@objc class AppDelegate: FlutterAppDelegate, CXProviderDelegate, PKPushRegistryDelegate {

    private let channelName = "com.swiftcall.swiftcall/callkit"
    private var callKitProvider: CXProvider!
    // uuid → full call metadata
    private var activeCalls: [UUID: [String: Any]] = [:]
    // Flutter channel may not be ready when PushKit fires (app killed) — queue pending data
    private var pendingAnswerData: [String: Any]? = nil
    private var pendingVoipToken: String? = nil
    private var pushRegistry: PKPushRegistry?
    private weak var flutterChannel: FlutterMethodChannel?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // ── 1. Configure CallKit provider ────────────────────────────────
        let config = CXProviderConfiguration(localizedName: "SwiftCall")
        config.supportsVideo = true
        config.maximumCallsPerCallGroup = 1
        config.supportedHandleTypes = [.generic]
        config.ringtoneSound = "ringtone.caf"
        callKitProvider = CXProvider(configuration: config)
        callKitProvider.setDelegate(self, queue: nil)

        // ── 2. Flutter plugin registration ───────────────────────────────
        GeneratedPluginRegistrant.register(with: self)

        // ── 3. Flutter method channel ────────────────────────────────────
        if let controller = window?.rootViewController as? FlutterViewController {
            let channel = FlutterMethodChannel(
                name: channelName,
                binaryMessenger: controller.binaryMessenger
            )
            flutterChannel = channel
            channel.setMethodCallHandler { [weak self] call, result in
                self?.handleFlutterCall(call, result: result)
            }

            // Deliver any data that arrived before Flutter was ready
            if let token = pendingVoipToken {
                channel.invokeMethod("voipTokenReceived", arguments: token)
                pendingVoipToken = nil
            }
            if let answer = pendingAnswerData {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    channel.invokeMethod("answerCallFromNative", arguments: answer)
                }
                pendingAnswerData = nil
            }
        }

        // ── 4. Register for VoIP pushes (PushKit) ────────────────────────
        let registry = PKPushRegistry(queue: .main)
        registry.delegate = self
        registry.desiredPushTypes = [.voIP]
        pushRegistry = registry   // retain

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - Flutter → Native

    private func handleFlutterCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {

        case "reportIncomingCall":
            // Flutter asks CallKit to show system call UI (used when app is in foreground)
            guard let args = call.arguments as? [String: Any],
                  let uuidStr  = args["uuid"]       as? String,
                  let callerName = args["callerName"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing uuid/callerName", details: nil))
                return
            }
            let uuid = UUID(uuidString: uuidStr) ?? UUID()
            activeCalls[uuid] = args
            reportCall(uuid: uuid, callerName: callerName,
                       hasVideo: args["hasVideo"] as? Bool ?? false,
                       completion: result)

        case "endCall":
            guard let args   = call.arguments as? [String: Any],
                  let uuidStr = args["uuid"]   as? String,
                  let uuid    = UUID(uuidString: uuidStr) else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing uuid", details: nil))
                return
            }
            callKitProvider.reportCall(with: uuid, endedAt: Date(), reason: .remoteEnded)
            activeCalls.removeValue(forKey: uuid)
            result(true)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func reportCall(uuid: UUID, callerName: String, hasVideo: Bool,
                            completion: ((_ ok: Any?) -> Void)?) {
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: callerName)
        update.localizedCallerName = callerName
        update.hasVideo = hasVideo
        update.supportsDTMF = false
        update.supportsHolding = false
        update.supportsGrouping = false

        callKitProvider.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error = error {
                completion?(FlutterError(code: "CALLKIT_ERROR",
                                         message: error.localizedDescription, details: nil))
            } else {
                completion?(true)
            }
        }
    }

    // MARK: - PKPushRegistryDelegate

    func pushRegistry(_ registry: PKPushRegistry,
                      didUpdate credentials: PKPushCredentials,
                      for type: PKPushType) {
        guard type == .voIP else { return }
        let token = credentials.token.map { String(format: "%02x", $0) }.joined()
        if let ch = flutterChannel {
            ch.invokeMethod("voipTokenReceived", arguments: token)
        } else {
            pendingVoipToken = token
        }
    }

    func pushRegistry(_ registry: PKPushRegistry,
                      didInvalidatePushTokenFor type: PKPushType) { }

    /// Called when a VoIP push arrives — app may be killed.
    /// Apple REQUIRES reportNewIncomingCall to be called synchronously within this method.
    func pushRegistry(_ registry: PKPushRegistry,
                      didReceiveIncomingPushWith payload: PKPushPayload,
                      for type: PKPushType,
                      completion: @escaping () -> Void) {
        guard type == .voIP else { completion(); return }

        let data     = payload.dictionaryPayload
        let callId   = data["callId"]     as? String ?? UUID().uuidString
        let name     = data["callerName"] as? String ?? "SwiftCall"
        let photo    = data["callerPhoto"] as? String ?? ""
        let room     = data["roomName"]   as? String ?? ""
        let callType = data["callType"]   as? String ?? "audio"
        let hasVideo = (callType == "video")

        let uuid = UUID()
        let callData: [String: Any] = [
            "uuid":        uuid.uuidString,
            "callId":      callId,
            "callerName":  name,
            "callerPhoto": photo,
            "roomName":    room,
            "callType":    callType,
            "hasVideo":    hasVideo,
        ]
        activeCalls[uuid] = callData

        // Synchronous — Apple requires this before returning from the delegate
        callKitProvider.reportNewIncomingCall(
            with: uuid,
            update: {
                let u = CXCallUpdate()
                u.remoteHandle = CXHandle(type: .generic, value: name)
                u.localizedCallerName = name
                u.hasVideo = hasVideo
                u.supportsDTMF  = false
                u.supportsHolding  = false
                u.supportsGrouping = false
                return u
            }()
        ) { _ in completion() }
    }

    // MARK: - CXProviderDelegate

    func providerDidReset(_ provider: CXProvider) {
        activeCalls.removeAll()
    }

    /// User tapped "Answer" on the native CallKit screen
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        let callData = activeCalls[action.callUUID] ?? [:]
        action.fulfill()

        if let ch = flutterChannel {
            ch.invokeMethod("answerCallFromNative", arguments: callData)
        } else {
            // Flutter not yet ready (app was killed) — send when channel opens
            pendingAnswerData = callData
        }
    }

    /// User tapped "Decline" or the caller cancelled
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        let callData = activeCalls[action.callUUID]
        activeCalls.removeValue(forKey: action.callUUID)
        action.fulfill()
        if let data = callData {
            flutterChannel?.invokeMethod("endCallFromNative", arguments: data)
        }
    }

    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction)  { action.fulfill() }
    func provider(_ provider: CXProvider, perform action: CXStartCallAction)    { action.fulfill() }
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) { action.fulfill() }
    func provider(_ provider: CXProvider, perform action: CXSetGroupCallAction) { action.fulfill() }
    func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) { action.fulfill() }
}
