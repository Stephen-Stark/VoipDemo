//
//  CallManager.swift
//  VoipTest
//
//  Created by StevStark on 2020/11/11.
//

import Foundation
import linphonesw
import CallKit
import AVFoundation

@objc class CallAppData: NSObject {
    @objc var batteryWarningShown = false
    @objc var videoRequested = false /*set when user has requested for video*/
}

@objc class CallManager: NSObject {
    static var theCallManager: CallManager?
    let providerDelegate: ProviderDelegate! // to support callkit
    let callController: CXCallController! // to support callkit
    let manager: CoreManagerDelegate! // callbacks of the linphonecore
    var lc: Core?
    @objc var speakerBeforePause : Bool = false
    @objc var speakerEnabled : Bool = false
    @objc var bluetoothEnabled : Bool = false
    @objc var nextCallIsTransfer: Bool = false
    @objc var alreadyRegisteredForNotification: Bool = false
    var referedFromCall: String?
    var referedToCall: String?


    fileprivate override init() {
        providerDelegate = ProviderDelegate()
        callController = CXCallController()
        manager = CoreManagerDelegate()
    }

    @objc static func instance() -> CallManager {
        if (theCallManager == nil) {
            theCallManager = CallManager()
        }
        return theCallManager!
    }

    @objc func setCore(core: OpaquePointer) {
        lc = Core.getSwiftObject(cObject: core)
        lc?.addDelegate(delegate: manager)
    }

    @objc static func getAppData(call: OpaquePointer) -> CallAppData? {
        let sCall = Call.getSwiftObject(cObject: call)
        return getAppData(sCall: sCall)
    }
    
    static func getAppData(sCall:Call) -> CallAppData? {
        if (sCall.userData == nil) {
            return nil
        }
        return Unmanaged<CallAppData>.fromOpaque(sCall.userData!).takeUnretainedValue()
    }

    @objc static func setAppData(call:OpaquePointer, appData: CallAppData) {
        let sCall = Call.getSwiftObject(cObject: call)
        setAppData(sCall: sCall, appData: appData)
    }
    
    static func setAppData(sCall:Call, appData:CallAppData?) {
        if (sCall.userData != nil) {
            Unmanaged<CallAppData>.fromOpaque(sCall.userData!).release()
        }
        if (appData == nil) {
            sCall.userData = nil
        } else {
            sCall.userData = UnsafeMutableRawPointer(Unmanaged.passRetained(appData!).toOpaque())
        }
    }

    @objc func findCall(callId: String?) -> OpaquePointer? {
        let call = callByCallId(callId: callId)
        return call?.getCobject
    }

    func callByCallId(callId: String?) -> Call? {
        if (callId == nil) {
            return nil
        }
        let calls = lc?.calls
        if let callTmp = calls?.first(where: { $0.callLog?.callId == callId }) {
            return callTmp
        }
        return nil
    }

    @objc static func callKitEnabled() -> Bool {
        #if !targetEnvironment(simulator)
        if ConfigManager.instance().lpConfigBoolForKey(key: "use_callkit", section: "app") {
            return true
        }
        #endif
        return false
    }

    @objc func allowSpeaker() -> Bool {
        if (UIDevice.current.userInterfaceIdiom == .pad) {
            // For now, ipad support only speaker.
            return true
        }

        var allow = true
        let newRoute = AVAudioSession.sharedInstance().currentRoute
        if (newRoute.outputs.count > 0) {
            let route = newRoute.outputs[0].portType
            allow = !( route == .lineOut || route == .headphones || (AudioHelper.bluetoothRoutes() as Array).contains(where: {($0 as! AVAudioSession.Port) == route}))
        }

        return allow
    }

    @objc func enableSpeaker(enable: Bool) {
        speakerEnabled = enable
        do {
            if (enable && allowSpeaker()) {
                try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
                UIDevice.current.isProximityMonitoringEnabled = false
                bluetoothEnabled = false
            } else {
                try AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
                let buildinPort = AudioHelper.builtinAudioDevice()
                try AVAudioSession.sharedInstance().setPreferredInput(buildinPort)
                UIDevice.current.isProximityMonitoringEnabled = (lc!.callsNb > 0)
            }
        } catch {
           
        }
    }

    func requestTransaction(_ transaction: CXTransaction, action: String) {
        callController.request(transaction) { error in
            if let error = error {
               
            } else {
               
            }
        }
    }

    // From ios13, display the callkit view when the notification is received.
    @objc func displayIncomingCall(callId: String) {
        let uuid = CallManager.instance().providerDelegate.uuids["\(callId)"]
        if (uuid != nil) {
            let callInfo = providerDelegate.callInfos[uuid!]
            if (callInfo?.declined ?? false) {
                // This call was declined.
                providerDelegate.reportIncomingCall(call:nil, uuid: uuid!, handle: "Calling", hasVideo: true)
                providerDelegate.endCall(uuid: uuid!)
            }
            return
        }

        let call = CallManager.instance().callByCallId(callId: callId)
        if (call != nil) {
            let addr = "Unknow"
            let video = UIApplication.shared.applicationState == .active && (lc!.videoActivationPolicy?.automaticallyAccept ?? false) && (call!.remoteParams?.videoEnabled ?? false)
            displayIncomingCall(call: call, handle: addr, hasVideo: video, callId: callId)
        } else {
            displayIncomingCall(call: nil, handle: "Calling", hasVideo: true, callId: callId)
        }
    }

    func displayIncomingCall(call:Call?, handle: String, hasVideo: Bool, callId: String) {
        let uuid = UUID()
        let callInfo = CallInfo.newIncomingCallInfo(callId: callId)

        providerDelegate.callInfos.updateValue(callInfo, forKey: uuid)
        providerDelegate.uuids.updateValue(uuid, forKey: callId)
        providerDelegate.reportIncomingCall(call:call, uuid: uuid, handle: handle, hasVideo: hasVideo)
    }

    @objc func acceptCall(call: OpaquePointer?, hasVideo:Bool) {
        if (call == nil) {
           
            return
        }
        let call = Call.getSwiftObject(cObject: call!)
        acceptCall(call: call, hasVideo: hasVideo)
    }

    func acceptCall(call: Call, hasVideo:Bool) {
        do {
            let callParams = try lc!.createCallParams(call: call)
            callParams.videoEnabled = hasVideo
            if (ConfigManager.instance().lpConfigBoolForKey(key: "edge_opt_preference")) {
                let low_bandwidth = (AppManager.network() == .network_2g)
                if (low_bandwidth) {
                   
                }
                callParams.lowBandwidthEnabled = low_bandwidth
            }

            //We set the record file name here because we can't do it after the call is started.
            let address = call.callLog?.fromAddress
            let writablePath = AppManager.recordingFilePathFromCall(address: address?.username ?? "")
          
            callParams.recordFile = writablePath

            try call.acceptWithParams(params: callParams)
        } catch {
           
        }
    }

    // for outgoing call. There is not yet callId
    @objc func startCall(addr: OpaquePointer?, isSas: Bool) {
        if (addr == nil) {
            print("Can not start a call with null address!")
            return
        }

        let sAddr = Address.getSwiftObject(cObject: addr!)
        if (CallManager.callKitEnabled() && !CallManager.instance().nextCallIsTransfer) {
            let uuid = UUID()
            let name = "unknow"
            let handle = CXHandle(type: .generic, value: name)
            let startCallAction = CXStartCallAction(call: uuid, handle: handle)
            let transaction = CXTransaction(action: startCallAction)

            let callInfo = CallInfo.newOutgoingCallInfo(addr: sAddr, isSas: isSas)
            providerDelegate.callInfos.updateValue(callInfo, forKey: uuid)
            providerDelegate.uuids.updateValue(uuid, forKey: "")

            requestTransaction(transaction, action: "startCall")
        }else {
            try? doCall(addr: sAddr, isSas: isSas)
        }
    }

    func doCall(addr: Address, isSas: Bool) throws {
        let displayName = "unknow"

        let lcallParams = try CallManager.instance().lc!.createCallParams(call: nil)
        if ConfigManager.instance().lpConfigBoolForKey(key: "edge_opt_preference") && AppManager.network() == .network_2g {
           
            lcallParams.lowBandwidthEnabled = true
        }

        if (displayName != nil) {
            try addr.setDisplayname(newValue: displayName)
        }

        if(ConfigManager.instance().lpConfigBoolForKey(key: "override_domain_with_default_one")) {
            try addr.setDomain(newValue: ConfigManager.instance().lpConfigStringForKey(key: "domain", section: "assistant"))
        }

        if (CallManager.instance().nextCallIsTransfer) {
            let call = CallManager.instance().lc!.currentCall
            try call?.transfer(referTo: addr.asString())
            CallManager.instance().nextCallIsTransfer = false
        } else {
            //We set the record file name here because we can't do it after the call is started.
            let writablePath = AppManager.recordingFilePathFromCall(address: addr.username )
    
            lcallParams.recordFile = writablePath
            if (isSas) {
                lcallParams.mediaEncryption = .ZRTP
            }
            let call = CallManager.instance().lc!.inviteAddressWithParams(addr: addr, params: lcallParams)
            if (call != nil) {
                // The LinphoneCallAppData object should be set on call creation with callback
                // - (void)onCall:StateChanged:withMessage:. If not, we are in big trouble and expect it to crash
                // We are NOT responsible for creating the AppData.
                let data = CallManager.getAppData(sCall: call!)
                if (data == nil) {
                   
                    /* will be used later to notify user if video was not activated because of the linphone core*/
                } else {
                    data!.videoRequested = lcallParams.videoEnabled
                    CallManager.setAppData(sCall: call!, appData: data)
                }
            }
        }
    }

    @objc func groupCall() {
        if (CallManager.callKitEnabled()) {
            let calls = lc?.calls
            if (calls == nil || calls!.isEmpty) {
                return
            }
            let firstCall = calls!.first?.callLog?.callId ?? ""
            let lastCall = (calls!.count > 1) ? calls!.last?.callLog?.callId ?? "" : ""

            let currentUuid = CallManager.instance().providerDelegate.uuids["\(firstCall)"]
            if (currentUuid == nil) {
               
                return
            }

            let newUuid = CallManager.instance().providerDelegate.uuids["\(lastCall)"]
            let groupAction = CXSetGroupCallAction(call: currentUuid!, callUUIDToGroupWith: newUuid)
            let transcation = CXTransaction(action: groupAction)
            requestTransaction(transcation, action: "groupCall")

            // To simulate the real group call action
            let heldAction = CXSetHeldCallAction(call: currentUuid!, onHold: false)
            let otherTransacation = CXTransaction(action: heldAction)
            requestTransaction(otherTransacation, action: "heldCall")
        } else {
            try? lc?.addAllToConference()
        }
    }

    @objc func removeAllCallInfos() {
        providerDelegate.callInfos.removeAll()
        providerDelegate.uuids.removeAll()
    }

    // To be removed.
    static func configAudioSession(audioSession: AVAudioSession) {
        do {
            try audioSession.setCategory(AVAudioSession.Category.playAndRecord, mode: AVAudioSession.Mode.voiceChat, options: AVAudioSession.CategoryOptions(rawValue: AVAudioSession.CategoryOptions.allowBluetooth.rawValue | AVAudioSession.CategoryOptions.allowBluetoothA2DP.rawValue))
            try audioSession.setMode(AVAudioSession.Mode.voiceChat)
            try audioSession.setPreferredSampleRate(48000.0)
            try AVAudioSession.sharedInstance().setActive(true, options: [])
        } catch {
          
        }
    }

    @objc func terminateCall(call: OpaquePointer?) {
        if (call == nil) {
           
            return
        }
        let call = Call.getSwiftObject(cObject: call!)
        do {
            try call.terminate()
            
        } catch {
           
        }
        if (UIApplication.shared.applicationState == .background) {
            CoreManager.instance().stopLinphoneCore()
        }
    }

    @objc func markCallAsDeclined(callId: String) {
        if !CallManager.callKitEnabled() {
            return
        }

        let uuid = providerDelegate.uuids["\(callId)"]
        if (uuid == nil) {
           
            let uuid = UUID()
            providerDelegate.uuids.updateValue(uuid, forKey: callId)
            let callInfo = CallInfo.newIncomingCallInfo(callId: callId)
            callInfo.declined = true
            providerDelegate.callInfos.updateValue(callInfo, forKey: uuid)
        } else {
            // end call
            providerDelegate.endCall(uuid: uuid!)
        }
    }

    @objc func setHeld(call: OpaquePointer, hold: Bool) {
        let sCall = Call.getSwiftObject(cObject: call)
        let callid = sCall.callLog?.callId ?? ""
        let uuid = providerDelegate.uuids["\(callid)"]

        if (uuid == nil) {
          
            return
        }
        let setHeldAction = CXSetHeldCallAction(call: uuid!, onHold: hold)
        let transaction = CXTransaction(action: setHeldAction)

        requestTransaction(transaction, action: "setHeld")
    }
}
