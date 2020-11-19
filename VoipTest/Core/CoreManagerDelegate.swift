//
//  CallManagerDelegate.swift
//  VoipTest
//
//  Created by StevStark on 2020/11/11.
//

import Foundation
import linphonesw
import CallKit
import AVFoundation


class CoreManagerDelegate: CoreDelegate {
    
    static var speaker_already_enabled : Bool = false

    override func onCallStateChanged(lc: Core, call: Call, cstate: Call.State, message: String) {
        let addr = call.remoteAddress;
        let address = "Unknow"
        let callLog = call.callLog
        let callId = callLog?.callId
        let video = UIApplication.shared.applicationState == .active && (lc.videoActivationPolicy?.automaticallyAccept ?? false) && (call.remoteParams?.videoEnabled ?? false)
        // we keep the speaker auto-enabled state in this static so that we don't
        // force-enable it on ICE re-invite if the user disabled it.
        CoreManagerDelegate.speaker_already_enabled = false

        if (call.userData == nil) {
            let appData = CallAppData()
            CallManager.setAppData(sCall: call, appData: appData)
        }


        switch cstate {
            case .IncomingReceived:
                if (CallManager.callKitEnabled()) {
                    let uuid = CallManager.instance().providerDelegate.uuids["\(callId!)"]
                    if (uuid != nil) {
                        // Tha app is now registered, updated the call already existed.
                        CallManager.instance().providerDelegate.updateCall(uuid: uuid!, handle: address, hasVideo: video)
                        let callInfo = CallManager.instance().providerDelegate.callInfos[uuid!]
                        if (callInfo?.declined ?? false) {
                            // The call is already declined.
                            try? call.decline(reason: Reason.Unknown)
                        } else if (callInfo?.accepted ?? false) {
                            // The call is already answered.
                            CallManager.instance().acceptCall(call: call, hasVideo: video)
                        }
                    } else {
                        CallManager.instance().displayIncomingCall(call: call, handle: address, hasVideo: video, callId: callId!)
                    }
                }
                break
            case .StreamsRunning:
                if (CallManager.callKitEnabled()) {
                    let uuid = CallManager.instance().providerDelegate.uuids["\(callId!)"]
                    if (uuid != nil) {
                        let callInfo = CallManager.instance().providerDelegate.callInfos[uuid!]
                        if (callInfo != nil && callInfo!.isOutgoing && !callInfo!.connected) {
                           
                            CallManager.instance().providerDelegate.reportOutgoingCallConnected(uuid: uuid!)
                            callInfo!.connected = true
                            CallManager.instance().providerDelegate.callInfos.updateValue(callInfo!, forKey: uuid!)
                        }
                    }
                }

                if (CallManager.instance().speakerBeforePause) {
                    CallManager.instance().speakerBeforePause = false
                    CallManager.instance().enableSpeaker(enable: true)
                    CoreManagerDelegate.speaker_already_enabled = true
                }
                break
            case .OutgoingRinging:
                if (CallManager.callKitEnabled()) {
                    let uuid = CallManager.instance().providerDelegate.uuids[""]
                    if (uuid != nil) {
                        let callInfo = CallManager.instance().providerDelegate.callInfos[uuid!]
                        callInfo!.callId = callId!
                        CallManager.instance().providerDelegate.callInfos.updateValue(callInfo!, forKey: uuid!)
                        CallManager.instance().providerDelegate.uuids.removeValue(forKey: "")
                        CallManager.instance().providerDelegate.uuids.updateValue(uuid!, forKey: callId!)

                        CallManager.instance().providerDelegate.reportOutgoingCallStartedConnecting(uuid: uuid!)
                    } else {
                        CallManager.instance().referedToCall = callId
                    }
                }
                break
            case .End,
                 .Error:
                UIDevice.current.isProximityMonitoringEnabled = false
                CoreManagerDelegate.speaker_already_enabled = false
                if (CallManager.instance().lc!.callsNb == 0) {
                    CallManager.instance().enableSpeaker(enable: false)
                    // disable this because I don't find anygood reason for it: _bluetoothAvailable = FALSE;
                    // furthermore it introduces a bug when calling multiple times since route may not be
                    // reconfigured between cause leading to bluetooth being disabled while it should not
                    CallManager.instance().bluetoothEnabled = false
                }

                if UIApplication.shared.applicationState != .active && (callLog == nil || callLog?.status == .Missed || callLog?.status == .Aborted || callLog?.status == .EarlyAborted)  {
                    // Configure the notification's payload.
                    let content = UNMutableNotificationContent()
                    content.title = NSString.localizedUserNotificationString(forKey: NSLocalizedString("Missed call", comment: ""), arguments: nil)
                    content.body = NSString.localizedUserNotificationString(forKey: address, arguments: nil)

                    // Deliver the notification.
                    let request = UNNotificationRequest(identifier: "call_request", content: content, trigger: nil) // Schedule the notification.
                    let center = UNUserNotificationCenter.current()
                    center.add(request) { (error : Error?) in
                        if error != nil {
                       
                        }
                    }
                }

                if (CallManager.callKitEnabled()) {
                    var uuid = CallManager.instance().providerDelegate.uuids["\(callId!)"]
                    if (callId == CallManager.instance().referedToCall) {
                        // refered call ended before connecting
                        CallManager.instance().referedFromCall = nil
                        CallManager.instance().referedToCall = nil
                    }
                    if uuid == nil {
                        // the call not yet connected
                        uuid = CallManager.instance().providerDelegate.uuids[""]
                    }
                    if (uuid != nil) {
                        if (callId == CallManager.instance().referedFromCall) {
                           
                            CallManager.instance().referedFromCall = nil
                            let callInfo = CallManager.instance().providerDelegate.callInfos[uuid!]
                            callInfo!.callId = CallManager.instance().referedToCall ?? ""
                            CallManager.instance().providerDelegate.callInfos.updateValue(callInfo!, forKey: uuid!)
                            CallManager.instance().providerDelegate.uuids.removeValue(forKey: callId!)
                            CallManager.instance().providerDelegate.uuids.updateValue(uuid!, forKey: callInfo!.callId)
                            CallManager.instance().referedToCall = nil
                            break
                        }

                        let transaction = CXTransaction(action:
                        CXEndCallAction(call: uuid!))
                        CallManager.instance().requestTransaction(transaction, action: "endCall")
                    }
                }
                break
            case .Released:
                call.userData = nil
                break
            case .Referred:
                CallManager.instance().referedFromCall = call.callLog?.callId
                break
            default:
                break
        }

        if (cstate == .IncomingReceived || cstate == .OutgoingInit || cstate == .Connected || cstate == .StreamsRunning) {
            if ((call.currentParams?.videoEnabled ?? false) && !CoreManagerDelegate.speaker_already_enabled && !CallManager.instance().bluetoothEnabled) {
                CallManager.instance().enableSpeaker(enable: true)
                CoreManagerDelegate.speaker_already_enabled = true
            }
        }

        // post Notification kLinphoneCallUpdate
        NotificationCenter.default.post(name: Notification.Name("LinphoneCallUpdate"), object: self, userInfo: [
            AnyHashable("call"): NSValue.init(pointer:UnsafeRawPointer(call.getCobject)),
            AnyHashable("state"): NSNumber(value: cstate.rawValue),
            AnyHashable("message"): message
        ])
    }
}
