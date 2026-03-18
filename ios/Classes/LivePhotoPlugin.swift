import Flutter
import UIKit

public class LivePhotoPlugin: NSObject, FlutterPlugin {
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "live_photo_plugin",
            binaryMessenger: registrar.messenger()
        )
        
        let instance = LivePhotoPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "saveAsLivePhoto":
            guard
                let args = call.arguments as? [String: Any],
                let videoPath = args["videoPath"] as? String,
                !videoPath.isEmpty
            else {
                result(
                    FlutterError(
                        code: "BAD_ARGS",
                        message: "videoPath is missing",
                        details: nil
                    )
                )
                return
            }
            
            let videoURL = URL(fileURLWithPath: videoPath)
            
            LivePhotoSaveUtility.shared.saveAsLivePhoto(videoURL: videoURL) { saveResult in
                DispatchQueue.main.async {
                    switch saveResult {
                    case .success:
                        result(true)
                        
                    case .failure(let error):
                        result(
                            FlutterError(
                                code: "SAVE_AS_LIVE_PHOTO_FAILED",
                                message: error.localizedDescription,
                                details: nil
                            )
                        )
                    }
                }
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
