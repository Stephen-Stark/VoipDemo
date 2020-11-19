//
//  CoreManager.swift
//  VoipTest
//
//  Created by StevStark on 2020/11/11.
//

import Foundation
import linphonesw

@objc class CoreManager: NSObject {
    static var theCoreManager: CoreManager?
    var lc: Core?
    private var mIterateTimer: Timer?

    @objc static func instance() -> CoreManager {
        if (theCoreManager == nil) {
            theCoreManager = CoreManager()
        }
        return theCoreManager!
    }

    @objc func setCore(core: OpaquePointer) {
        lc = Core.getSwiftObject(cObject: core)
    }

    @objc private func iterate() {
        lc?.iterate()
    }

    @objc func startIterateTimer() {
        if (mIterateTimer?.isValid ?? false) {
          
            return
        }
        mIterateTimer = Timer.scheduledTimer(timeInterval: 0.02, target: self, selector: #selector(self.iterate), userInfo: nil, repeats: true)
     

    }

    @objc func stopIterateTimer() {
        if let timer = mIterateTimer {
            timer.invalidate()
        }
    }
    
    @objc func stopLinphoneCore() {
        if (lc?.callsNb == 0) {
            stopIterateTimer()
            lc?.stop()
        }
    }
}
