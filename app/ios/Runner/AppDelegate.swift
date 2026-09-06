import Flutter
import UIKit
import Darwin.Mach.time

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    private let networkHandler = NetworkHandler()

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        DevicePlatformSetup.setUp(binaryMessenger: engineBridge.binaryMessenger, api: self)
        TimingPlatformSetup.setUp(binaryMessenger: engineBridge.binaryMessenger, api: self)

        networkHandler.setFlutterApi(NetworkFlutterApi(binaryMessenger: engineBridge.binaryMessenger))
        NetworkHostPlatformSetup.setUp(binaryMessenger: engineBridge.binaryMessenger, api: networkHandler)
    }
}

extension AppDelegate: DevicePlatform {
    func getDeviceInfo() throws -> DeviceInfo {
        return DeviceInfo(
            platformName: "iOS",
            osVersion: UIDevice.current.systemVersion,
            deviceModel: UIDevice.current.model,
            brand: "Apple"
        )
    }
}

extension AppDelegate: TimingPlatform {
    func getMonotonicTimeNanos() throws -> Int64 {
        var timebaseInfo = mach_timebase_info_data()
        let result = mach_timebase_info(&timebaseInfo)
        if result != KERN_SUCCESS {
            throw PigeonError(code: "TIMEBASE_ERROR", message: "Failed to get mach timebase info", details: nil)
        }
        let continuousTime = mach_continuous_time()
        let nanos = continuousTime * UInt64(timebaseInfo.numer) / UInt64(timebaseInfo.denom)
        return Int64(nanos)
    }
}
