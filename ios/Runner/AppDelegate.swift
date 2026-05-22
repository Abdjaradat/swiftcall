import Flutter
import UIKit
import CallKit // Import CallKit

@main
@objc class AppDelegate: FlutterAppDelegate, CXProviderDelegate { // Conform to CXProviderDelegate

    private let methodChannelName = "com.swiftcall.swiftcall/callkit"
    private var provider: CXProvider!
    private var callController = CXCallController()
    private var activeCalls: [UUID: String] = [:] // Keep track of active calls (UUID to caller name)

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Configure CallKit Provider
        let providerConfiguration = CXProviderConfiguration(localizedName: "SwiftCall")
        providerConfiguration.supportsVideo = true
        providerConfiguration.maximumCallsPerCallGroup = 1
        providerConfiguration.supportedHandleTypes = [.phoneNumber, .emailAddress] // Customize as needed
        providerConfiguration.ringtoneSound = "ringtone.caf" // Optional: custom ringtone, add to project resources

        provider = CXProvider(configuration: providerConfiguration)
        provider.setDelegate(self, queue: nil)

        // Setup Flutter MethodChannel
        let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
        let methodChannel = FlutterMethodChannel(name: methodChannelName, binaryMessenger: controller.binaryMessenger)

        methodChannel.setMethodCallHandler({
            [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            guard let self = self else {
                result(FlutterError(code: "UNAVAILABLE", message: "AppDelegate instance is nil", details: nil))
                return
            }

            switch call.method {
            case "reportIncomingCall":
                guard let args = call.arguments as? [String: Any],
                      let uuidString = args["uuid"] as? String,
                      let handle = args["handle"] as? String,
                      let callerName = args["callerName"] as? String else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing UUID, handle, or callerName", details: nil))
                    return
                }

                let uuid = UUID(uuidString: uuidString) ?? UUID()
                self.activeCalls[uuid] = callerName

                let update = CXCallUpdate()
                update.remoteHandle = CXHandle(type: .phoneNumber, value: handle) // Or .emailAddress
                update.localizedCallerName = callerName
                update.hasVideo = args["hasVideo"] as? Bool ?? false

                self.provider.reportNewIncomingCall(with: uuid, update: update) { error in
                    if let error = error {
                        print("Failed to report incoming call: \(error.localizedDescription)")
                        result(FlutterError(code: "CALLKIT_ERROR", message: error.localizedDescription, details: nil))
                    } else {
                        print("Incoming call reported successfully with UUID: \(uuid.uuidString)")
                        result(true)
                    }
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        })

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - CXProviderDelegate

    func providerDidReset(_ provider: CXProvider) {
        print("CallKit Provider did reset")
        // End any ongoing calls if necessary
        for uuid in activeCalls.keys {
            provider.reportCall(with: uuid, endedAt: nil, reason: .failed)
        }
        activeCalls.removeAll()
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print("CXAnswerCallAction for UUID: \(action.callUUID)")
        // Implement logic to answer the call (e.g., start WebRTC connection)
        // Optionally, inform Flutter that the call was answered
        // Example: methodChannel.invokeMethod("callAnswered", arguments: ["uuid": action.callUUID.uuidString])
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("CXEndCallAction for UUID: \(action.callUUID)")
        // Implement logic to end the call (e.g., close WebRTC connection)
        activeCalls.removeValue(forKey: action.callUUID)
        // Optionally, inform Flutter that the call was ended
        // Example: methodChannel.invokeMethod("callEnded", arguments: ["uuid": action.callUUID.uuidString])
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        print("CXSetHeldCallAction for UUID: \(action.callUUID) onHold: \(action.isOnHold)")
        // Implement logic to put the call on/off hold
        // Optionally, inform Flutter about hold status
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        print("CXStartCallAction for UUID: \(action.callUUID) handle: \(action.handle.value)")
        // Implement logic for starting an outgoing call
        action.fulfill()
    }
    
    // You might also need to implement these for a complete CallKit integration:
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        print("CXSetMutedCallAction for UUID: \(action.callUUID) muted: \(action.isMuted)")
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetGroupCallAction) {
        print("CXSetGroupCallAction for UUID: \(action.callUUID)")
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) {
        print("CXPlayDTMFCallAction for UUID: \(action.callUUID)")
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetSendingVideoCallAction) {
        print("CXSetSendingVideoCallAction for UUID: \(action.callUUID) sendingVideo: \(action.isSendingVideo)")
        action.fulfill()
    }
}
