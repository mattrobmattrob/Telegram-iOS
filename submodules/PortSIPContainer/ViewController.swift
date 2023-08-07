import AVFoundation

// private implementation
//
class SoundService {
    var playerRingBackTone: AVAudioPlayer!
    var playerRingTone: AVAudioPlayer!
    var speakerOn: Bool!

    func initPlayerWithPath(_ path: String) -> AVAudioPlayer {
        let url = URL(fileURLWithPath: Bundle.main.path(forResource: path, ofType: nil)!)

        var player: AVAudioPlayer!
        do {
            player = try AVAudioPlayer(contentsOf: url)
        } catch {}

        return player
    }

    func unInit() {
        if playerRingBackTone != nil {
            if playerRingBackTone.isPlaying {
                playerRingBackTone.stop()
            }
        }

        if playerRingTone != nil {
            if playerRingTone.isPlaying {
                playerRingTone.stop()
            }
        }
    }

    //
    // SoundService
    //
    func speakerEnabled(_ enabled: Bool) {
        let session = AVAudioSession.sharedInstance()
        var options = session.categoryOptions

        if enabled {
            options.insert(AVAudioSession.CategoryOptions.defaultToSpeaker)
        } else {
            options.remove(AVAudioSession.CategoryOptions.defaultToSpeaker)
        }
        do {
            try session.setCategory(AVAudioSession.Category.playAndRecord, options: options)
            NSLog("Playback OK")
        } catch {
            NSLog("ERROR: CANNOT speakerEnabled. Message from code: \"\(error)\"")
        }


    }

    func isSpeakerEnabled() -> Bool {
        speakerOn
    }

    func playRingTone() -> Bool {
        if playerRingTone == nil {
            playerRingTone = initPlayerWithPath("ringtone.mp3")
        }
        if playerRingTone != nil {
            playerRingTone.numberOfLoops = -1
            speakerEnabled(true)
            playerRingTone.play()
            return true
        }
        return false
    }

    func stopRingTone() -> Bool {
        if playerRingTone != nil, playerRingTone.isPlaying {
            playerRingTone.stop()
            speakerEnabled(true)
        }
        return true
    }

    func playRingBackTone() -> Bool {
        if playerRingBackTone == nil {
            playerRingBackTone = initPlayerWithPath("ringtone.mp3")
        }
        if playerRingBackTone != nil {
            playerRingBackTone.numberOfLoops = -1
            speakerEnabled(false)
            playerRingBackTone.play()
            return true
        }

        return false
    }

    func stopRingBackTone() -> Bool {
        if playerRingBackTone != nil, playerRingBackTone.isPlaying {
            playerRingBackTone.stop()
            speakerEnabled(true)
        }
        return true
    }
}


//
//  PortCxProvider.swift
//  SipSample
//
//  Created by portsip on 17/2/22.
//  Copyright © 2017 portsip. All rights reserved.
//

import CallKit
import UIKit

@available(iOS 10.0, *)
class PortCxProvider: NSObject, CXProviderDelegate {
    var cxprovider: CXProvider!
    var callManager: CallManager!
    var callController: CXCallController!
    private static var instance: PortCxProvider = PortCxProvider()

    class var shareInstance: PortCxProvider {
        PortCxProvider.instance
    }

    override init() {
        super.init()
        configurationCallProvider()
    }

    func configurationCallProvider() {
        let infoDic = Bundle.main.infoDictionary!
        let localizedName = infoDic["CFBundleName"] as! String

        let providerConfiguration = CXProviderConfiguration(localizedName: localizedName)
        providerConfiguration.supportsVideo = true
        providerConfiguration.maximumCallsPerCallGroup = 2
        providerConfiguration.supportedHandleTypes = [.phoneNumber]
        if let iconMaskImage = UIImage(named: "IconMask") {
            providerConfiguration.iconTemplateImageData = iconMaskImage.pngData()
        }

        cxprovider = CXProvider(configuration: providerConfiguration)

        cxprovider.setDelegate(self, queue: DispatchQueue.main)

        callController = CXCallController()
    }

    func reportOutgoingCall(callUUID: UUID, startDate: Date) -> (UUID) {
        cxprovider.reportOutgoingCall(with: callUUID, connectedAt: startDate)
        return callUUID
    }

//    #pragma mark - CXProviderDelegate

    func providerDidReset(_: CXProvider) {
        callManager.stopAudio()
        print("Provider did reset")

        callManager.clear()
    }

    func provider(_: CXProvider, perform action: CXPlayDTMFCallAction) {
        print(" CXPlayDTMFCallAction \(action.callUUID) \(action.digits)")

        var dtmf: Int32 = 0
        switch action.digits {
        case "0":
            dtmf = 0
        case "1":
            dtmf = 1
        case "2":
            dtmf = 2
        case "3":
            dtmf = 3
        case "4":
            dtmf = 4
        case "5":
            dtmf = 5
        case "6":
            dtmf = 6
        case "7":
            dtmf = 7
        case "8":
            dtmf = 8
        case "9":
            dtmf = 9
        case "*":
            dtmf = 10
        case "#":
            dtmf = 11
        default:
            return
        }
        callManager.sendDTMF(uuid: action.callUUID, dtmf: dtmf)
        action.fulfill()
    }

    func provider(_: CXProvider, timedOutPerforming _: CXAction) {}

    func provider(_: CXProvider, perform action: CXSetGroupCallAction) {
        guard callManager.findCallByUUID(uuid: action.callUUID) != nil else {
            action.fail()
            return
        }

        if action.callUUIDToGroupWith != nil {
            callManager.joinToConference(uuid: action.callUUID)
            action.fulfill()
        } else {
            callManager.removeFromConference(uuid: action.callUUID)
            action.fulfill()
        }

        action.fulfill()
    }

    func performAnswerCall(uuid: UUID, completion completionHandler: @escaping (_ success: Bool) -> Void) {
        let session = callManager.findCallByUUID(uuid: uuid)

        if session != nil {
            if session!.session.sessionId <= INVALID_SESSION_ID {
                // Haven't received INVITE CALL
                session?.session.callKitAnswered = true
                session?.session.callKitCompletionCallback = completionHandler
            } else {
                if callManager.answerCallWithUUID(uuid: uuid, isVideo: session?.session.videoState ?? false) {
                    completionHandler(true)
                } else {
                    print("Answer Call Failed!")
                    completionHandler(false)
                }
            }
        } else {
            print("Session not found")

            completionHandler(false)
        }
    }

    func provider(_: CXProvider, perform action: CXAnswerCallAction) {
        performAnswerCall(uuid: action.callUUID) { success in
            if success {
                action.fulfill()
                print("performAnswerCallAction success")
            } else {
                action.fail()
                print("performAnswerCallAction fail")
            }
        }
        // [action fulfill];

    }

    func provider(_: CXProvider, perform action: CXStartCallAction) {
        print("performStartCallAction uuid = \(action.callUUID)")

        let sessionid = callManager.makeCallWithUUID(callee: action.handle.value, displayName: action.handle.value, videoCall: action.isVideo, uuid: action.callUUID)
        if sessionid >= 0 {
            action.fulfill()
        } else {
            action.fail()
        }
    }

    func provider(_: CXProvider, perform action: CXEndCallAction) {
        let result = callManager.findCallByUUID(uuid: action.callUUID)
        if result != nil {
            callManager.hungUpCall(uuid: action.callUUID)
        }

        action.fulfill()
    }

    func provider(_: CXProvider, perform action: CXSetHeldCallAction) {
        let result = callManager.findCallByUUID(uuid: action.callUUID)
        if result != nil {
            callManager.holdCall(uuid: action.callUUID, onHold: action.isOnHold)
        }

        action.fulfill()
    }

    func provider(_: CXProvider, perform action: CXSetMutedCallAction) {
        let result = callManager.findCallByUUID(uuid: action.callUUID)
        if result != nil {
            callManager.muteCall(action.isMuted, uuid: action.callUUID)
        }
        action.fulfill()
    }

    func provider(_: CXProvider, didActivate _: AVAudioSession) {
        callManager.startAudio()
    }

    func provider(_: CXProvider, didDeactivate _: AVAudioSession) {
        callManager.stopAudio()
    }
}


//
//  Session.m
//  SIPSample
//
//  Created by Joe Lepple on 5/1/15.
//  Copyright (c) 2015 PortSIP Solutions, Inc. All rights reserved.
//

let LINE_BASE = 0
let MAX_LINES = 8

class Session {
    var sessionId: Int
    var holdState: Bool
    var sessionState: Bool
    var conferenceState: Bool
    var recvCallState: Bool
    var isReferCall: Bool
    var originCallSessionId: Int
    var existEarlyMedia: Bool
    var videoState: Bool
    var screenShare: Bool
    var uuid: UUID
    var groupUUID: UUID?
    var status: String
    var outgoing: Bool
    var callKitAnswered: Bool
    var callKitCompletionCallback: ((Bool) -> Void)?
    var hasAdd: Bool

    init() {
        sessionId = Int(INVALID_SESSION_ID)
        holdState = false
        sessionState = false
        conferenceState = false
        recvCallState = false
        isReferCall = false
        originCallSessionId = Int(INVALID_SESSION_ID)
        existEarlyMedia = false
        videoState = false
        screenShare = false;
        outgoing = false
        uuid = UUID()
        groupUUID = nil
        status = ""
        hasAdd = false
        callKitAnswered = false
        callKitCompletionCallback = nil
    }

    func reset() {
        sessionId = Int(INVALID_SESSION_ID)
        holdState = false
        sessionState = false
        conferenceState = false
        recvCallState = false
        isReferCall = false
        originCallSessionId = Int(INVALID_SESSION_ID)
        existEarlyMedia = false
        videoState = false
        outgoing = false
        uuid = UUID()
        groupUUID = nil
        status = ""
        screenShare = false;
        hasAdd = false
        callKitAnswered = false
        callKitCompletionCallback = nil
    }
}


//
//  CallManager.swift
//  SipSample
//
//  Created by portsip on 17/2/22.
//  Copyright © 2017 portsip. All rights reserved.
//

import CallKit
import UIKit

import Foundation

protocol CallManagerDelegate: NSObjectProtocol {
    func onIncomingCallWithoutCallKit(_ sessionId: CLong, existsVideo: Bool, remoteParty: String, remoteDisplayName: String)
    func onAnsweredCall(sessionId: CLong)
    func onCloseCall(sessionId: CLong)
    func onMuteCall(sessionId: CLong, muted: Bool)
    func onHoldCall(sessionId: CLong, onHold: Bool)

    func onNewOutgoingCall(sessionid: CLong)
}

class CallManager: NSObject {
    weak var delegate: CallManagerDelegate?

    var _enableCallKit: Bool = false
    var enableCallKit: Bool {
        set {
            if _enableCallKit != newValue {
                _enableCallKit = newValue
                _portSIPSDK.enableCallKit(_enableCallKit)
            }
        }
        get {
            return _enableCallKit
        }
    }

    var isConference: Bool = false
    var _playDTMFTone: Bool = true

    var sessionArray: [Session] = []
    var _portSIPSDK: PortSIPSDK!
    var _playDTMFMethod: DTMF_METHOD!
    var _conferenceGroupID: UUID!

    init(portsipSdk: PortSIPSDK) {
        _portSIPSDK = portsipSdk

        _playDTMFTone = true
        _playDTMFMethod = DTMF_RFC2833
        _conferenceGroupID = nil

        for _ in 0 ..< MAX_LINES {
            sessionArray.append(Session())
        }

        if #available(iOS 10.0, *) {
            _enableCallKit = true
        } else {
            _enableCallKit = false
        }
        // Force disable CallKit
        // _enableCallKit = false

        _portSIPSDK.enableCallKit(_enableCallKit)
    }

    func setPlayDTMFMethod(dtmfMethod: DTMF_METHOD, playDTMFTone: Bool) {
        _playDTMFTone = playDTMFTone
        _playDTMFMethod = dtmfMethod
    }

    func reportUpdateCall(uuid: UUID, hasVideo: Bool, from: String) {
        guard findCallByUUID(uuid: uuid) != nil else {
            return
        }
        if #available(iOS 10.0, *) {
            let handle = CXHandle(type: .generic, value: from)
            let update = CXCallUpdate()
            update.remoteHandle = handle
            update.hasVideo = hasVideo
            update.supportsGrouping = true
            update.supportsDTMF = true
            update.supportsUngrouping = true
            update.localizedCallerName = from

            PortCxProvider.shareInstance.cxprovider.reportCall(with: uuid, updated: update)
        }
    }

    func reportOutgoingCall(number: String, uuid: UUID, video: Bool = false) {
        if #available(iOS 10.0, *) {
            let handle = CXHandle(type: .generic, value: number)

            let startCallAction = CXStartCallAction(call: uuid, handle: handle)

            startCallAction.isVideo = video

            let transaction = CXTransaction()
            transaction.addAction(startCallAction)
            let callController = CXCallController()
            callController.request(transaction) { error in
                if let err = error {
                    print("Error requesting transaction: \(err)")
                } else {
                    print("Requested transaction successfully")
                }
            }
        }
    }

    @available(iOS 10.0, *)
    func reportInComingCall(uuid: UUID, hasVideo: Bool, from: String, completion: ((Error?) -> Void)? = nil) {
        guard findCallByUUID(uuid: uuid) != nil else {
            return
        }

        let handle = CXHandle(type: .generic, value: from)
        let update = CXCallUpdate()
        update.remoteHandle = handle
        update.hasVideo = hasVideo
        update.supportsGrouping = true
        update.supportsDTMF = true
        update.supportsUngrouping = true

        PortCxProvider.shareInstance.cxprovider.reportNewIncomingCall(with: uuid, update: update, completion: { error in
            print("ErrorCode: \(String(describing: error))")
            completion?(error)
        })
    }

    func reportAnswerCall(uuid: UUID) {
        guard let result = findCallByUUID(uuid: uuid) else {
            return
        }
        if #available(iOS 10.0, *) {
            let answerAction = CXAnswerCallAction(call: result.session.uuid)

            let transaction = CXTransaction()
            transaction.addAction(answerAction)
            let callController = CXCallController()
            callController.request(transaction) { error in
                if let error = error {
                    print("Error requesting transaction: \(error)")
                } else {
                    print("Requested transaction successfully")
                }
            }
        }
    }

    func reportEndCall(uuid: UUID) {
        if #available(iOS 10.0, *) {
            guard let result = findCallByUUID(uuid: uuid) else {
                return
            }
            let sesion = result.session as Session
            let endCallAction = CXEndCallAction(call: sesion.uuid)
            let transaction = CXTransaction()
            transaction.addAction(endCallAction)
            let callController = CXCallController()
            callController.request(transaction) { error in
                if let error = error {
                    print("Error requesting transaction: \(error)")
                } else {
                    print("Requested transaction successfully")
                }
            }
        }
    }

    func reportSetHeld(uuid: UUID, onHold: Bool) {
        print("reportSetHeld transaction successfully")
        if #available(iOS 10.0, *) {
            guard let result = findCallByUUID(uuid: uuid) else {
                return
            }

            let setHeldCallAction = CXSetHeldCallAction(call: result.session.uuid, onHold: onHold)
            let transaction = CXTransaction()
            transaction.addAction(setHeldCallAction)
            let callController = CXCallController()
            callController.request(transaction) { error in
                if let error = error {
                    print("Error requesting transaction: \(error)")
                } else {
                    print("Requested transaction successfully")
                }
            }
        }
    }

    func reportSetMute(uuid: UUID, muted: Bool) {
        guard let result = findCallByUUID(uuid: uuid) else {
            return
        }

        if result.session.sessionState {
            if #available(iOS 10.0, *) {
                let setMutedCallAction = CXSetMutedCallAction(call: result.session.uuid, muted: muted)
                let transaction = CXTransaction()
                transaction.addAction(setMutedCallAction)
                let callController = CXCallController()
                callController.request(transaction) { error in
                    if let error = error {
                        print("Error requesting transaction: \(error)")
                    } else {
                        print("Requested transaction successfully")
                    }
                }
            }
        }
    }

    func reportJoninConference(uuid: UUID) {
        guard let result = findCallByUUID(uuid: uuid) else {
            return
        }
        if #available(iOS 10.0, *) {
            let setGroupCallAction = CXSetGroupCallAction(call: result.session.uuid, callUUIDToGroupWith: _conferenceGroupID)
            let transaction = CXTransaction()
            transaction.addAction(setGroupCallAction)
            let callController = CXCallController()
            callController.request(transaction) { error in
                if let error = error {
                    print("Error requesting transaction: \(error)")
                } else {
                    print("Requested transaction successfully")
                }
            }
        }
    }

    func reportRemoveFromConference(uuid: UUID) {
        guard let result = findCallByUUID(uuid: uuid) else {
            return
        }
        if #available(iOS 10.0, *) {
            let setGroupCallAction = CXSetGroupCallAction(call: result.session.uuid, callUUIDToGroupWith: nil)
            let transaction = CXTransaction()
            transaction.addAction(setGroupCallAction)
            let callController = CXCallController()
            callController.request(transaction) { error in
                if let error = error {
                    print("Error requesting transaction: \(error)")
                } else {
                    print("Requested transaction successfully")
                }
            }
        }
    }

    func reportPlayDtmf(uuid: UUID, tone: Int) {
        guard let result = findCallByUUID(uuid: uuid) else {
            return
        }
        var digits: String
        if tone == 10 {
            digits = "*"
        } else if tone == 11 {
            digits = "#"
        } else {
            digits = String(tone)
        }
        if #available(iOS 10.0, *) {
            let dtmfCallAction = CXPlayDTMFCallAction(call: result.session.uuid, digits: digits, type: .singleTone)
            let transaction = CXTransaction()
            transaction.addAction(dtmfCallAction)
            let callController = CXCallController()
            callController.request(transaction) { error in
                if let error = error {
                    print("Error requesting transaction: \(error)")
                } else {
                    print("Requested transaction successfully")
                }
            }
        }
    }

    //    Call Manager interface
    func makeCall(callee: String, displayName: String, videoCall: Bool) -> (CLong) {
        let num = getConnectCallNum()
        if num > MAX_LINES {
            return (CLong)(INVALID_SESSION_ID)
        }

        let sessionid = makeCallWithUUID(callee: callee, displayName: displayName, videoCall: videoCall, uuid: UUID())
        let result = findCallBySessionID(sessionid)

        if result != nil, _enableCallKit {
            reportOutgoingCall(number: callee, uuid: result!.session.uuid, video: videoCall)
            print("reportOutgoingCall uuid = \(result!.session.uuid))")
        }
        return sessionid
    }

    func incomingCall(sessionid: CLong, existsVideo: Bool, remoteParty: String, remoteDisplayName: String, callUUID: UUID, completionHandle _: () -> Void) {
        var session: Session
        let result = findCallByUUID(uuid: callUUID)
        if result != nil {
            session = result!.session
            session.sessionId = sessionid
            session.videoState = existsVideo
            if session.callKitAnswered {
                let bRet = answerCallWithUUID(uuid: session.uuid, isVideo: existsVideo)
                session.callKitCompletionCallback?(bRet)
                reportUpdateCall(uuid: session.uuid, hasVideo: existsVideo, from: remoteParty)
            }
        } else {
            session = Session()
            session.sessionId = sessionid
            session.videoState = existsVideo
            session.uuid = callUUID

            _ = addCall(call: session)

            if _enableCallKit {
                if #available(iOS 10.0, *) {
                    reportInComingCall(uuid: session.uuid, hasVideo: existsVideo, from: remoteParty)
                }
            } else {
                delegate?.onIncomingCallWithoutCallKit(sessionid, existsVideo: existsVideo, remoteParty: remoteParty, remoteDisplayName: remoteDisplayName)
            }
        }
    }

    func answerCall(sessionId: CLong, isVideo: Bool) -> (Bool) {
        guard let result = findCallBySessionID(sessionId) else {
            return false
        }
        if _enableCallKit {
            result.session.videoState = isVideo
            reportAnswerCall(uuid: result.session.uuid)
            return true
        } else {
            return answerCallWithUUID(uuid: result.session.uuid, isVideo: isVideo)
        }
    }

    func endCall(sessionid: CLong) {
        guard let result = findCallBySessionID(sessionid) else {
            return
        }
        if _enableCallKit {
            let sesion = result.session as Session
            reportEndCall(uuid: sesion.uuid)
        } else {
            hungUpCall(uuid: result.session.uuid)
        }
    }

    func holdCall(sessionid: CLong, onHold: Bool) {
        guard let result = findCallBySessionID(sessionid) else {
            return
        }
        if !result.session.sessionState || result.session.holdState == onHold {
            return
        }

        if(_enableCallKit){
            reportSetHeld(uuid:result.session.uuid, onHold: onHold)
        }else{
            holdCall(uuid: result.session.uuid, onHold: onHold)
        }

    }

    func holdAllCall(onHold: Bool) {
        for i in 0 ..< MAX_LINES {
            if sessionArray[i].hasAdd,
                sessionArray[i].sessionState,
                sessionArray[i].holdState != onHold {
                holdCall(sessionid: sessionArray[i].sessionId, onHold: onHold)
            }
        }
    }

    func muteCall(sessionid: CLong, muted: Bool) {
        guard let result = findCallBySessionID(sessionid) else {
            return
        }
        if !result.session.sessionState {
            return
        }
        if _enableCallKit {
            reportSetMute(uuid: result.session.uuid, muted: muted)
        } else {
            muteCall(muted, uuid: result.session.uuid)
        }
    }

    func muteAllCall(muted: Bool) {
        for i in 0 ..< MAX_LINES {
            if sessionArray[i].hasAdd,
                sessionArray[i].sessionState {
                muteCall(sessionid: sessionArray[i].sessionId, muted: muted)
            }
        }
    }

    func playDtmf(sessionid: CLong, tone: Int) {
        guard let result = findCallBySessionID(sessionid) else {
            return
        }

        if !result.session.sessionState {
            return
        }
        sendDTMF(uuid: result.session.uuid, dtmf: Int32(tone))
    }

    func createConference(conferenceVideoWindow: PortSIPVideoRenderView?, videoWidth: Int, videoHeight: Int, displayLocalVideoInConference: Bool) -> (Bool) {
        if isConference {
            return false
        }
        var ret = 0
        if conferenceVideoWindow != nil, videoWidth > 0, videoHeight > 0 {
            ret = Int(_portSIPSDK.createVideoConference(conferenceVideoWindow, videoWidth: Int32(videoWidth), videoHeight: Int32(videoHeight), displayLocalVideo: displayLocalVideoInConference))
        } else {
            ret = Int(_portSIPSDK.createAudioConference())
        }

        if ret != 0 {
            isConference = false
            return false
        }

        isConference = true

        for i in 0 ..< MAX_LINES {
            if sessionArray[i].hasAdd {
                _portSIPSDK.setRemoteVideoWindow(sessionArray[i].sessionId, remoteVideoWindow: nil)
                joinToConference(sessionid: sessionArray[i].sessionId)
            }
        }
        return true
    }

    func joinToConference(sessionid: CLong) {
        guard let result = findCallBySessionID(sessionid) else {
            return
        }
        if !result.session.sessionState || !isConference {
            return
        }

        if _enableCallKit {
            if(_conferenceGroupID==nil){
                _conferenceGroupID = result.session.uuid
            }else{
                var groupWith = findCallByUUID(uuid:_conferenceGroupID)
                if(groupWith==nil){
                    groupWith =  findAnotherCall(result.session.sessionId)
                }

                if(groupWith==nil){
                    _conferenceGroupID = result.session.uuid
                }else{
                    _conferenceGroupID = groupWith?.session.uuid
                }
            }

            if(_conferenceGroupID == result.session.uuid){
                joinToConference(uuid: result.session.uuid)
            }else{
                reportRemoveFromConference(uuid:result.session.uuid);
                reportJoninConference(uuid:result.session.uuid);
            }
        }else{
            joinToConference(uuid: result.session.uuid)
            if(result.session.holdState){
                holdCall(uuid: result.session.uuid, onHold: false);
            }
        }

    }

    func removeFromConference(sessionid: CLong) {
        guard let result = findCallBySessionID(sessionid) else {
            return
        }

        if !isConference {
            return
        }

        if _enableCallKit {
            reportRemoveFromConference(uuid: result.session.uuid)
        } else {
            removeFromConference(uuid: result.session.uuid)
        }
    }

    func destoryConference() {
        if isConference {
            for i in 0 ..< MAX_LINES {
                if sessionArray[i].hasAdd {
                    removeFromConference(sessionid: sessionArray[i].sessionId)
                }
            }
        }
        _portSIPSDK.destroyConference()
        _conferenceGroupID = nil
        isConference = false
        print("DestoryConference")
    }

    //    Call Manager implementation

    func makeCallWithUUID(callee: String, displayName: String?, videoCall: Bool, uuid: UUID) -> (CLong) {
        let result = findCallByUUID(uuid: uuid)
        if result != nil {
            return result!.session.sessionId
        }
        let num = getConnectCallNum()
        if num >= MAX_LINES {
            return (CLong)(INVALID_SESSION_ID)
        }
        let sessionid = _portSIPSDK.call(callee, sendSdp: true, videoCall: videoCall)

        if sessionid <= 0 {
            return sessionid
        }
        if displayName == nil {
            //            displayName = callee
        }
        let session = Session()
        session.uuid = uuid
        session.sessionId = sessionid
        session.originCallSessionId = -1
        session.videoState = videoCall
        session.outgoing = true

        _ = addCall(call: session)
        delegate?.onNewOutgoingCall(sessionid: sessionid)
        return session.sessionId
    }

    func answerCallWithUUID(uuid: UUID, isVideo: Bool) -> (Bool) {
        let sessionCall = findCallByUUID(uuid: uuid)
        guard sessionCall != nil else {
            return false
        }

        if sessionCall!.session.sessionId <= INVALID_SESSION_ID {
            // Haven't received INVITE CALL
            sessionCall!.session.callKitAnswered = true
            return true
        } else {
            let nRet = _portSIPSDK.answerCall(sessionCall!.session.sessionId, videoCall: isVideo)
            if nRet == 0 {
                sessionCall!.session.sessionState = true
                sessionCall!.session.videoState = isVideo

                if isConference {
                    joinToConference(sessionid: sessionCall!.session.sessionId)
                }
                delegate?.onAnsweredCall(sessionId: sessionCall!.session.sessionId)

                print("Answer Call on session \(sessionCall!.session.sessionId)")
                return true
            } else {
                delegate?.onCloseCall(sessionId: sessionCall!.session.sessionId)

                print("Answer Call on session \(sessionCall!.session.sessionId) Failed! ret = \(nRet)")
                return false
            }
        }
    }

    func hungUpCall(uuid: UUID) {
        guard let result = findCallByUUID(uuid: uuid) else {
            return
        }
        if isConference {
            removeFromConference(sessionid: result.session.sessionId)
        }

        if result.session.sessionState {
            _portSIPSDK.hangUp(result.session.sessionId)
            if result.session.videoState {}
            print("Hungup call on session \(result.session.sessionId)")
        } else if result.session.outgoing {
            _portSIPSDK.hangUp(result.session.sessionId)
            print("Invite call Failure on session \(result.session.sessionId)")
        } else {
            _portSIPSDK.rejectCall(result.session.sessionId, code: 486)
            print("Rejected call on session \(result.session.sessionId)")
        }

        delegate?.onCloseCall(sessionId: result.session.sessionId)
    }

    func holdCall(uuid: UUID, onHold: Bool) {
        guard let result = findCallByUUID(uuid: uuid) else {
            return
        }
        if !result.session.sessionState ||
            result.session.holdState == onHold {
            return
        }

        if onHold {
            _portSIPSDK.hold(result.session.sessionId)
            result.session.holdState = true
            print("Hold call on session: \(result.session.sessionId)")
        } else {
            _portSIPSDK.unHold(result.session.sessionId)
            result.session.holdState = false
            print("UnHold call on session: \(result.session.sessionId)")
        }
        delegate?.onHoldCall(sessionId: result.session.sessionId, onHold: onHold)
    }

    public func muteCall(_ mute: Bool, uuid: UUID) {
        guard let result = findCallByUUID(uuid: uuid) else {
            return
        }
        if result.session.sessionState {
            if mute {
                _portSIPSDK.muteSession(result.session.sessionId,
                                        muteIncomingAudio: false,
                                        muteOutgoingAudio: true,
                                        muteIncomingVideo: false,
                                        muteOutgoingVideo: true)
            } else {
                _portSIPSDK.muteSession(result.session.sessionId,
                                        muteIncomingAudio: false,
                                        muteOutgoingAudio: false,
                                        muteIncomingVideo: false,
                                        muteOutgoingVideo: false)
            }
            delegate?.onMuteCall(sessionId: result.session.sessionId, muted: mute)
        }
    }

    public func sendDTMF(uuid: UUID, dtmf: Int32) {
        guard let result = findCallByUUID(uuid: uuid) else {
            return
        }

        if result.session.sessionState {
            _portSIPSDK.sendDtmf(result.session.sessionId, dtmfMethod: _playDTMFMethod, code: dtmf, dtmfDration: 160, playDtmfTone: _playDTMFTone)
        }
    }

    public func joinToConference(uuid: UUID) {
        guard let result = findCallByUUID(uuid: uuid) else {
            return
        }
        if isConference {
            if result.session.sessionState {
                _portSIPSDK.join(toConference: result.session.sessionId)
                if(result.session.holdState){
                    holdCall(uuid: result.session.uuid, onHold: false);
                }
                _portSIPSDK.setRemoteVideoWindow(result.session.sessionId, remoteVideoWindow: nil)
                _portSIPSDK.setRemoteScreenWindow(result.session.sessionId, remoteScreenWindow: nil)
                _portSIPSDK.sendVideo(result.session.sessionId, sendState: true)
            }
        }
    }

    public func removeFromConference(uuid: UUID) {
        guard let result = findCallByUUID(uuid: uuid) else {
            return
        }

        if isConference {
            _portSIPSDK.remove(fromConference: result.session.sessionId)
        }
    }

    public func findCallBySessionID(_ sessionID: CLong) -> (session: Session, index: Int)? {
        for i in 0 ..< MAX_LINES {
            if sessionArray[i].hasAdd,
                sessionArray[i].sessionId == sessionID {
                return (sessionArray[i], i)
            }
        }
        return nil
    }

    public func findAnotherCall(_ sessionID: CLong) -> (session: Session, index: Int)? {
        for i in 0 ..< MAX_LINES {
            if sessionArray[i].hasAdd,
                sessionArray[i].sessionId != sessionID {
                return (sessionArray[i], i)
            }
        }
        return nil
    }

    public func findCallByOrignalSessionID(sessionID: CLong) -> (session: Session, index: Int)? {
        for i in 0 ..< MAX_LINES {
            if sessionArray[i].hasAdd,
                sessionArray[i].originCallSessionId == sessionID {
                return (sessionArray[i], i)
            }
        }
        return nil
    }

    public func findCallByUUID(uuid: UUID) -> (session: Session, index: Int)? {
        for i in 0 ..< MAX_LINES {
            if sessionArray[i].uuid == uuid {
                return (sessionArray[i], i)
            }
        }
        return nil
    }

    public func addCall(call: Session) -> (Int) {
        for i in 0 ..< MAX_LINES {
            if sessionArray[i].hasAdd == false {
                sessionArray[i] = call
                sessionArray[i].hasAdd = true
                return i
            }
        }
        return -1
    }

    public func removeCall(call: Session) {
        for i in 0 ..< MAX_LINES {
            if sessionArray[i] === call {
                sessionArray[i].reset()
            }
        }
    }

    public func clear() {
        for i in 0 ..< MAX_LINES {
            if sessionArray[i].hasAdd {
                _portSIPSDK.hangUp(sessionArray[i].sessionId)
                sessionArray[i].reset()
            }
        }
    }

    public func getConnectCallNum() -> Int {
        var num: Int = 0
        for i in 0 ..< MAX_LINES {
            if sessionArray[i].hasAdd {
                num += 1
            }
        }
        return num
    }

    func startAudio() {
        _portSIPSDK.startAudio()
        print("_portSIPSDK startAudio")
    }

    func stopAudio() {
        _portSIPSDK.stopAudio()
        print("_portSIPSDK stopAudio")
    }
}

// Audio Controller


//
//  ViewController.swift
//  New
//
//  Created by Eduard on 11.07.2023.
//


import UIKit
import PortSIPVoIPSDK

public class PortSIPHackViewController: UIViewController, UNUserNotificationCenterDelegate, CallManagerDelegate, PortSIPEventDelegate {

    

    var portSIPSDK: PortSIPSDK!
    var mSoundService: SoundService!
    var sipRegistered: Bool!
//    var internetReach: Reachability!
    var _callManager: CallManager!
    var sipInitialized = false

  public override func viewDidLoad() {
        super.viewDidLoad()

        portSIPSDK = PortSIPSDK()
        portSIPSDK.delegate = self
        mSoundService = SoundService()

        if #available(iOS 10.0, *) {
            let cxProvider = PortCxProvider.shareInstance
            _callManager = CallManager(portsipSdk: portSIPSDK)
            _callManager.delegate = self
            _callManager.enableCallKit = false
            cxProvider.callManager = _callManager
        } else {
            // Fallback on earlier versions
        }

        var transport = TRANSPORT_UDP // TRANSPORT_TCP

        var srtp = SRTP_POLICY_NONE

        let localPort = 10002
        let loaclIPaddress = "0.0.0.0" // Auto select IP address

        var userName = "8f42b049-3a04-4d0d-bb50-7250c3fecdda";
        var authName = "8f42b049-3a04-4d0d-bb50-7250c3fecdda";
        var password = "cf4e94c6ea86b524cf9f9bec35254d9b"
        var userDomain = "193.104.248.78";
        var sipServer = "193.104.248.78";
        var sipPort = Int32("55060");


        var ret = portSIPSDK.initialize(
                TRANSPORT_UDP
                , localIP: loaclIPaddress
                , localSIPPort: Int32(localPort)
                , loglevel: PORTSIP_LOG_NONE, logPath: ""
                , maxLine: 8
                , agent: "PortSIP SDK for IOS"
                , audioDeviceLayer: 0
                , videoDeviceLayer: 0
                , tlsCertificatesRootPath: ""
                , tlsCipherList: ""
                , verifyTLSCertificate: false
                , dnsServers: ""
        )
        if ret != 0 {
            NSLog("initialize failure ErrorCode = %d", ret)
            return
        }

        ret = portSIPSDK.setUser(
                userName
                , displayName: userName
                , authName: authName
                , password: password
                , userDomain: userDomain
                , sipServer: sipServer
                , sipServerPort: sipPort!
                , stunServer: ""
                , stunServerPort: 0
                , outboundServer: ""
                , outboundServerPort: 0
        )

        if ret != 0 {
            NSLog("setUser failure ErrorCode = %d", ret)
            return
        }

        let licenseKey = "1iOS1h00NkFBMjVCNjE4OEJDQTBEQ0RBNEJBQjU5MTlBOTU4RkA2NTkzQzYxN0QyRTIwNzA2NjM0OUI5QkQyNUQxQkI3NUBCQkU2RTUyMDY1MzkyNjdDMDAzREZGRjM4NDFFQ0VDMEAzRjAxMDE3QzUwOUZGQzU3RDY5RThENzEwMEU2Q0Q2Rg"

        let rt = portSIPSDK.setLicenseKey(licenseKey)

        NSLog("setLicenseKey %d", rt)


        if rt == ECoreTrialVersionLicenseKey {
            NSLog("This trial version SDK just allows short conversation, you can't heairng anyting after 2-3 minutes, contact us: sales@portsip.com to buy official version.")
        } else if rt == ECoreWrongLicenseKey {
            NSLog("setLicenseKey failure ErrorCode = %d", rt)
            return
        } else if rt == ECoreTrialVersionExpired {
            NSLog("setLicenseKey failure ErrorCode = %d", rt)
            return
        }

        portSIPSDK.addAudioCodec(AUDIOCODEC_OPUS)
        portSIPSDK.addAudioCodec(AUDIOCODEC_G729)
        portSIPSDK.addAudioCodec(AUDIOCODEC_PCMA)
        portSIPSDK.addAudioCodec(AUDIOCODEC_PCMU)
        
        portSIPSDK.addVideoCodec(VIDEO_CODEC_H264)
        // portSIPSDK.addVideoCodec(VIDEO_CODEC_VP8);
        // portSIPSDK.addVideoCodec(VIDEO_CODEC_VP9);

        portSIPSDK.setVideoBitrate(-1, bitrateKbps: 500) // video send bitrate,500kbps
        portSIPSDK.setVideoFrameRate(-1, frameRate: 10)
        portSIPSDK.setVideoResolution(352, height: 288)
        portSIPSDK.setAudioSamples(20, maxPtime: 60) // ptime 20
       
        portSIPSDK.setInstanceId(UIDevice.current.identifierForVendor?.uuidString)

        portSIPSDK.setVideoDeviceId(1)

        portSIPSDK.setVideoNackStatus(true)

        // enable srtp
        portSIPSDK.setSrtpPolicy(srtp)

        ret = portSIPSDK.registerServer(90, retryTimes: 0)
        
        if ret != 0 {
            portSIPSDK.unInitialize()
            NSLog("registerServer failure ErrorCode = %d", ret)
            return
        }
        
        if transport == TRANSPORT_TCP ||
            transport == TRANSPORT_TLS {
            portSIPSDK.setKeepAliveTime(0)
        }

        portSIPSDK.clearAddedSipMessageHeaders()
        portSIPSDK.addSipMessageHeader(-1, methodName: "ALL", msgType: 1, headerName: "X-Kaller-Master-Number", headerValue: "+79120000020#10");

        makeCall("${KALLER_FORMAT_NUMBER}", videoCall: false)
    }

    func makeCall(_ callee: String, videoCall: Bool) -> (CLong) {

        let sessionId = _callManager.makeCall(callee: callee, displayName: callee, videoCall: videoCall)

        if sessionId >= 0 {
            print("makeCall------------------ \(String(describing: sessionId))")
        }

        return sessionId

    }


    func onRegisterSuccess(_: CInt, withStatusText statusText: String) {
        
        print("on register success : \(statusText)")
     
//        return
    }
    
    func onRegisterFailure(_ statusCode: CInt, withStatusText statusText: String) {
        
        print("on register failed : \(statusText)")
    }

    func onIncomingCallWithoutCallKit(_ sessionId: CLong, existsVideo: Bool, remoteParty: String, remoteDisplayName: String){
        print("on incoming call without callkit : \(sessionId)");
    }

    func onAnsweredCall(sessionId: CLong){
        print("on answered call : \(sessionId)");
    }
    func onCloseCall(sessionId: CLong){
        print("on close call : \(sessionId)");
    }
    func onMuteCall(sessionId: CLong, muted: Bool){
        print("on mute call : \(sessionId)");
    }
    func onHoldCall(sessionId: CLong, onHold: Bool){
        print("on hold call : \(sessionId)");
    }

    func onNewOutgoingCall(sessionid: CLong){
        print("on new outgoing call : \(sessionid)");
    }


    public func onRegisterSuccess(_ statusText: UnsafeMutablePointer<CChar>!, statusCode: Int32, sipMessage: UnsafeMutablePointer<CChar>!) {
        print("on register success : \(statusCode)");
    }

  public func onRegisterFailure(_ statusText: UnsafeMutablePointer<CChar>!, statusCode: Int32, sipMessage: UnsafeMutablePointer<CChar>!) {
        print("on register failure : \(statusCode)");
    }

  public func onInviteIncoming(_ sessionId: Int, callerDisplayName: UnsafeMutablePointer<CChar>!, caller: UnsafeMutablePointer<CChar>!, calleeDisplayName: UnsafeMutablePointer<CChar>!, callee: UnsafeMutablePointer<CChar>!, audioCodecs: UnsafeMutablePointer<CChar>!, videoCodecs: UnsafeMutablePointer<CChar>!, existsAudio: Bool, existsVideo: Bool, sipMessage: UnsafeMutablePointer<CChar>!) {
        print("on invite incoming : \(sessionId)");
    }

  public func onInviteTrying(_ sessionId: Int) {
        print("on invite trying : \(sessionId)");
    }

  public func onInviteSessionProgress(_ sessionId: Int, audioCodecs: UnsafeMutablePointer<CChar>!, videoCodecs: UnsafeMutablePointer<CChar>!, existsEarlyMedia: Bool, existsAudio: Bool, existsVideo: Bool, sipMessage: UnsafeMutablePointer<CChar>!) {
        print("on invite session progress : \(sessionId)");
    }

  public func onInviteRinging(_ sessionId: Int, statusText: UnsafeMutablePointer<CChar>!, statusCode: Int32, sipMessage: UnsafeMutablePointer<CChar>!) {
        print("on invite ringing : \(sessionId)");
    }

  public func onInviteAnswered(_ sessionId: Int, callerDisplayName: UnsafeMutablePointer<CChar>!, caller: UnsafeMutablePointer<CChar>!, calleeDisplayName: UnsafeMutablePointer<CChar>!, callee: UnsafeMutablePointer<CChar>!, audioCodecs: UnsafeMutablePointer<CChar>!, videoCodecs: UnsafeMutablePointer<CChar>!, existsAudio: Bool, existsVideo: Bool, sipMessage: UnsafeMutablePointer<CChar>!) {
        print("on invite answered : \(sessionId)");
    }

  public func onInviteFailure(_ sessionId: Int, reason: UnsafeMutablePointer<CChar>!, code: Int32, sipMessage: UnsafeMutablePointer<CChar>!) {
        print("on invite failure : \(sessionId)");
    }

  public func onInviteUpdated(_ sessionId: Int, audioCodecs: UnsafeMutablePointer<CChar>!, videoCodecs: UnsafeMutablePointer<CChar>!, screenCodecs: UnsafeMutablePointer<CChar>!, existsAudio: Bool, existsVideo: Bool, existsScreen: Bool, sipMessage: UnsafeMutablePointer<CChar>!) {
        print("on invite updated : \(sessionId)");
    }

  public func onInviteConnected(_ sessionId: Int) {
        print("on invite connected : \(sessionId)");
    }

  public func onInviteBeginingForward(_ forwardTo: UnsafeMutablePointer<CChar>!) {
        print("on invite begin forward : ");
    }

  public func onInviteClosed(_ sessionId: Int, sipMessage: UnsafeMutablePointer<CChar>!) {
        print("on invite closed : \(sessionId)");
    }

  public func onDialogStateUpdated(_ BLFMonitoredUri: UnsafeMutablePointer<CChar>!, blfDialogState BLFDialogState: UnsafeMutablePointer<CChar>!, blfDialogId BLFDialogId: UnsafeMutablePointer<CChar>!, blfDialogDirection BLFDialogDirection: UnsafeMutablePointer<CChar>!) {
        print("on dialog updated :");
    }

  public func onRemoteHold(_ sessionId: Int) {
        print("on remote hold : \(sessionId)");
    }

  public func onRemoteUnHold(_ sessionId: Int, audioCodecs: UnsafeMutablePointer<CChar>!, videoCodecs: UnsafeMutablePointer<CChar>!, existsAudio: Bool, existsVideo: Bool) {
        print("on remote unhold : \(sessionId)");
    }

  public func onReceivedRefer(_ sessionId: Int, referId: Int, to: UnsafeMutablePointer<CChar>!, from: UnsafeMutablePointer<CChar>!, referSipMessage: UnsafeMutablePointer<CChar>!) {
        print("on receiver refer : \(sessionId)");
    }

  public func onReferAccepted(_ sessionId: Int) {
        print("on refer accepted : \(sessionId)");
    }

  public func onReferRejected(_ sessionId: Int, reason: UnsafeMutablePointer<CChar>!, code: Int32) {
        print("on refer rejected : \(sessionId)");
    }

  public func onTransferTrying(_ sessionId: Int) {
        print("on transfer trying : \(sessionId)");
    }

  public func onTransferRinging(_ sessionId: Int) {
        print("on transfer ringing : \(sessionId)");
    }

  public func onACTVTransferSuccess(_ sessionId: Int) {
        print("on acvt tansfer success : \(sessionId)");
    }

  public func onACTVTransferFailure(_ sessionId: Int, reason: UnsafeMutablePointer<CChar>!, code: Int32) {
        print("on acvt tansfer failure : \(sessionId)");
    }

  public func onReceivedSignaling(_ sessionId: Int, message: UnsafeMutablePointer<CChar>!) {
        print("on received signaling : \(sessionId)");
    }

  public func onSendingSignaling(_ sessionId: Int, message: UnsafeMutablePointer<CChar>!) {
        print("on sending signaling : \(sessionId)");
    }

  public func onWaitingVoiceMessage(_ messageAccount: UnsafeMutablePointer<CChar>!, urgentNewMessageCount: Int32, urgentOldMessageCount: Int32, newMessageCount: Int32, oldMessageCount: Int32) {
        print("on wait voice message : ");
    }

  public func onWaitingFaxMessage(_ messageAccount: UnsafeMutablePointer<CChar>!, urgentNewMessageCount: Int32, urgentOldMessageCount: Int32, newMessageCount: Int32, oldMessageCount: Int32) {
        print("on wait fax message : ");
    }

  public func onRecvDtmfTone(_ sessionId: Int, tone: Int32) {
        print("on receive dtmf tone : \(sessionId)");
    }

  public func onRecvOptions(_ optionsMessage: UnsafeMutablePointer<CChar>!) {
        print("on receive options : ");
    }

  public func onRecvInfo(_ infoMessage: UnsafeMutablePointer<CChar>!) {
        print("on receive info : ");
    }

  public func onRecvNotifyOfSubscription(_ subscribeId: Int, notifyMessage: UnsafeMutablePointer<CChar>!, messageData: UnsafeMutablePointer<UInt8>!, messageDataLength: Int32) {
        print("on receive options : ");
    }

  public func onPresenceRecvSubscribe(_ subscribeId: Int, fromDisplayName: UnsafeMutablePointer<CChar>!, from: UnsafeMutablePointer<CChar>!, subject: UnsafeMutablePointer<CChar>!) {
        print("on receive presence : ");

    }

  public func onPresenceOnline(_ fromDisplayName: UnsafeMutablePointer<CChar>!, from: UnsafeMutablePointer<CChar>!, stateText: UnsafeMutablePointer<CChar>!) {
        print("on presence online : \(fromDisplayName)");

    }

  public func onPresenceOffline(_ fromDisplayName: UnsafeMutablePointer<CChar>!, from: UnsafeMutablePointer<CChar>!) {
        print("on presence offline : \(fromDisplayName)");
    }

  public func onRecvMessage(_ sessionId: Int, mimeType: UnsafeMutablePointer<CChar>!, subMimeType: UnsafeMutablePointer<CChar>!, messageData: UnsafeMutablePointer<UInt8>!, messageDataLength: Int32) {
        print("on receive message : \(sessionId)");
    }

  public func onRecvOutOfDialogMessage(_ fromDisplayName: UnsafeMutablePointer<CChar>!, from: UnsafeMutablePointer<CChar>!, toDisplayName: UnsafeMutablePointer<CChar>!, to: UnsafeMutablePointer<CChar>!, mimeType: UnsafeMutablePointer<CChar>!, subMimeType: UnsafeMutablePointer<CChar>!, messageData: UnsafeMutablePointer<UInt8>!, messageDataLength: Int32, sipMessage: UnsafeMutablePointer<CChar>!) {
        print("on receive out of dialog :");
    }

  public func onSendMessageSuccess(_ sessionId: Int, messageId: Int, sipMessage: UnsafeMutablePointer<CChar>!) {
        print("on send message success : \(sessionId)");
    }

  public func onSendMessageFailure(_ sessionId: Int, messageId: Int, reason: UnsafeMutablePointer<CChar>!, code: Int32, sipMessage: UnsafeMutablePointer<CChar>!) {
        print("on send message failure : \(sessionId)");
    }

  public func onSendOutOfDialogMessageSuccess(_ messageId: Int, fromDisplayName: UnsafeMutablePointer<CChar>!, from: UnsafeMutablePointer<CChar>!, toDisplayName: UnsafeMutablePointer<CChar>!, to: UnsafeMutablePointer<CChar>!, sipMessage: UnsafeMutablePointer<CChar>!) {
        print("on send out dialog message success : \(messageId)");
    }

  public  func onSendOutOfDialogMessageFailure(_ messageId: Int, fromDisplayName: UnsafeMutablePointer<CChar>!, from: UnsafeMutablePointer<CChar>!, toDisplayName: UnsafeMutablePointer<CChar>!, to: UnsafeMutablePointer<CChar>!, reason: UnsafeMutablePointer<CChar>!, code: Int32, sipMessage: UnsafeMutablePointer<CChar>!) {
        print("on send out dialog message failure : \(messageId)");
    }

  public  func onSubscriptionFailure(_ subscribeId: Int, statusCode: Int32) {
        print("on subscription failure : \(subscribeId)");
    }

  public func onSubscriptionTerminated(_ subscribeId: Int) {
        print("on subscription termonated : \(subscribeId)");
    }

  public func onPlayAudioFileFinished(_ sessionId: Int, fileName: UnsafeMutablePointer<CChar>!) {
        print("on play audio finished : \(sessionId)");
    }

  public func onPlayVideoFileFinished(_ sessionId: Int) {
        print("on play video finished : \(sessionId)");
    }

  public func onRTPPacketCallback(_ sessionId: Int, mediaType: Int32, direction: DIRECTION_MODE, rtpPacket RTPPacket: UnsafeMutablePointer<UInt8>!, packetSize: Int32) {
        print("on rtp packet callback : \(sessionId)");
    }

  public func onAudioRawCallback(_ sessionId: Int, audioCallbackMode: Int32, data: UnsafeMutablePointer<UInt8>!, dataLength: Int32, samplingFreqHz: Int32) {
        print("on audio raw callback : \(sessionId)");
    }

  public func onVideoRawCallback(_ sessionId: Int, videoCallbackMode: Int32, width: Int32, height: Int32, data: UnsafeMutablePointer<UInt8>!, dataLength: Int32) -> Int32 {
        print("on video raw callback : \(sessionId)");

        return 0;
    }

}
