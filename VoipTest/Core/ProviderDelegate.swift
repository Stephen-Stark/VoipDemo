//
//  ProviderDelegate.swift
//  VoipTest
//
//  Created by StevStark on 2020/11/11.
//
import Foundation
import CallKit
import UIKit
import linphonesw
import AVFoundation


@objc class CallInfo: NSObject {
    var callId: String = ""
    var accepted = false
    var toAddr: Address?
    var isOutgoing = false
    var sasEnabled = false
    var declined = false
    var connected = false
    
    
    static func newIncomingCallInfo(callId: String) -> CallInfo {
        let callInfo = CallInfo()
        callInfo.callId = callId
        return callInfo
    }
    
    static func newOutgoingCallInfo(addr: Address, isSas: Bool) -> CallInfo {
        let callInfo = CallInfo()
        callInfo.isOutgoing = true
        callInfo.sasEnabled = isSas
        callInfo.toAddr = addr
        return callInfo
    }
}


/*
* A delegate to support callkit.
*/
class ProviderDelegate: NSObject {
    private let provider: CXProvider
    var uuids: [String : UUID] = [:]
    var callInfos: [UUID : CallInfo] = [:]

    override init() {
        provider = CXProvider(configuration: ProviderDelegate.providerConfiguration)
        super.init()
        provider.setDelegate(self, queue: nil)
    }

    static var providerConfiguration: CXProviderConfiguration = {
        let providerConfiguration = CXProviderConfiguration(localizedName: Bundle.main.infoDictionary!["CFBundleName"] as! String)
        providerConfiguration.ringtoneSound = "notes_of_the_optimistic.caf"
        providerConfiguration.supportsVideo = true
        providerConfiguration.iconTemplateImageData = UIImage(named: "callkit_logo")?.pngData()
        providerConfiguration.supportedHandleTypes = [.generic]

        providerConfiguration.maximumCallsPerCallGroup = 10
        providerConfiguration.maximumCallGroups = 2

        //not show app's calls in tel's history
        //providerConfiguration.includesCallsInRecents = YES;
        
        return providerConfiguration
    }()

    func reportIncomingCall(call:Call?, uuid: UUID, handle: String, hasVideo: Bool) {
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type:.generic, value: handle)
        update.hasVideo = hasVideo

        let callInfo = callInfos[uuid]
        let callId = callInfo?.callId
       
        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            if error == nil {
                CallManager.instance().providerDelegate.endCallNotExist(uuid: uuid, timeout: .now() + 20)
            } else {
               
                if (call == nil) {
                    callInfo?.declined = true
                    self.callInfos.updateValue(callInfo!, forKey: uuid)
                    return
                }
                let code = (error as NSError?)?.code
                if code == CXErrorCodeIncomingCallError.filteredByBlockList.rawValue || code == CXErrorCodeIncomingCallError.filteredByDoNotDisturb.rawValue {
                    try? call?.decline(reason: Reason.Busy)
                } else {
                    try? call?.decline(reason: Reason.Unknown)
                }
            }
        }
    }

    func updateCall(uuid: UUID, handle: String, hasVideo: Bool = false) {
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type:.generic, value:handle)
        update.hasVideo = hasVideo
        provider.reportCall(with:uuid, updated:update);
    }

    func reportOutgoingCallStartedConnecting(uuid:UUID) {
        provider.reportOutgoingCall(with: uuid, startedConnectingAt: nil)
    }

    func reportOutgoingCallConnected(uuid:UUID) {
        provider.reportOutgoingCall(with: uuid, connectedAt: nil)
    }
    
    func endCall(uuid: UUID) {
        provider.reportCall(with: uuid, endedAt: .init(), reason: .declinedElsewhere)
    }

    func endCallNotExist(uuid: UUID, timeout: DispatchTime) {
        DispatchQueue.main.asyncAfter(deadline: timeout) {
            let callId = CallManager.instance().providerDelegate.callInfos[uuid]?.callId
            let call = CallManager.instance().callByCallId(callId: callId)
            if (call == nil) {
                CallManager.instance().providerDelegate.endCall(uuid: uuid)
            }
        }
    }
}

// MARK: - CXProviderDelegate
extension ProviderDelegate: CXProviderDelegate {
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        action.fulfill()
        let uuid = action.callUUID
        let callId = callInfos[uuid]?.callId

        // remove call infos first, otherwise CXEndCallAction will be called more than onece
        if (callId != nil) {
            uuids.removeValue(forKey: callId!)
        }
        callInfos.removeValue(forKey: uuid)

        let call = CallManager.instance().callByCallId(callId: callId)
        if let call = call {
            CallManager.instance().terminateCall(call: call.getCobject);
          
        }
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        let uuid = action.callUUID
        let callInfo = callInfos[uuid]
        let callId = callInfo?.callId
       
        let call = CallManager.instance().callByCallId(callId: callId)
        if (call == nil || call?.state != Call.State.IncomingReceived) {
            // The application is not yet registered or the call is not yet received, mark the call as accepted. The audio session must be configured here.
            CallManager.configAudioSession(audioSession: AVAudioSession.sharedInstance())
            callInfo?.accepted = true
            callInfos.updateValue(callInfo!, forKey: uuid)
            CallManager.instance().providerDelegate.endCallNotExist(uuid: uuid, timeout: .now() + 10)
        } else {
            CallManager.instance().acceptCall(call: call!, hasVideo: call!.params?.videoEnabled ?? false)
        }
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        let uuid = action.callUUID
        let callId = callInfos[uuid]?.callId
        let call = CallManager.instance().callByCallId(callId: callId)
        action.fulfill()
        if (call == nil) {
            return
        }

        do {
            if (CallManager.instance().lc?.isInConference ?? false && action.isOnHold) {
                try CallManager.instance().lc?.leaveConference()
               
                NotificationCenter.default.post(name: Notification.Name("LinphoneCallUpdate"), object: self)
                return
            }

            let state = action.isOnHold ? "Paused" : "Resumed"
          
            if (action.isOnHold) {
                if (call!.params?.localConferenceMode ?? false) {
                    return
                }
                CallManager.instance().speakerBeforePause = CallManager.instance().speakerEnabled
                try call!.pause()
            } else {
                if (CallManager.instance().lc?.conference != nil && CallManager.instance().lc?.callsNb ?? 0 > 1) {
                    try CallManager.instance().lc?.enterConference()
                    NotificationCenter.default.post(name: Notification.Name("LinphoneCallUpdate"), object: self)
                } else {
                    try call!.resume()
                }
            }
        } catch {
        
        }
    }

    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        do {
            let uuid = action.callUUID
            let callInfo = callInfos[uuid]
            let addr = callInfo?.toAddr
            if (addr == nil) {
                action.fail()
            }

            try CallManager.instance().doCall(addr: addr!, isSas: callInfo?.sasEnabled ?? false)
        } catch {
         
            action.fail()
        }
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetGroupCallAction) {
     
        do {
            try CallManager.instance().lc?.addAllToConference()
        } catch {
           
        }
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        let uuid = action.callUUID
        let callId = callInfos[uuid]?.callId
      
        CallManager.instance().lc!.micEnabled = !CallManager.instance().lc!.micEnabled
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) {
        let uuid = action.callUUID
        let callId = callInfos[uuid]?.callId
    
        let call = CallManager.instance().callByCallId(callId: callId)
        if (call != nil) {
            let digit = (action.digits.cString(using: String.Encoding.utf8)?[0])!
            do {
                try call!.sendDtmf(dtmf: digit)
            } catch {
            
            }
        }
        action.fulfill()
    }

    func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        let uuid = action.uuid
        let callId = callInfos[uuid]?.callId
    
        action.fulfill()
    }

    func providerDidReset(_ provider: CXProvider) {
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
      
        CallManager.instance().lc?.activateAudioSession(actived: true)
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        CallManager.instance().lc?.activateAudioSession(actived: false)
    }
}

