//
//  AppManager.swift
//  VoipTest
//
//  Created by StevStark on 2020/11/11.
//

import Foundation
import CoreTelephony

enum NetworkType: Int {
    case network_none = 0
    case network_2g = 1
    case network_3g = 2
    case network_4g = 3
    case network_lte = 4
    case network_wifi = 5
}

/*
* AppManager is a class that includes some useful functions.
*/
@objc class AppManager: NSObject {
    static func network() -> NetworkType {
        let info = CTTelephonyNetworkInfo()
        let currentRadio = info.currentRadioAccessTechnology
        if (currentRadio == CTRadioAccessTechnologyEdge) {
            return NetworkType.network_2g
        } else if (currentRadio == CTRadioAccessTechnologyLTE) {
            return NetworkType.network_4g
        }
        return NetworkType.network_3g
    }

    @objc static func recordingFilePathFromCall(address: String) -> String {
        var filePath = "recording_"
        filePath = filePath.appending(address.isEmpty ? "unknow" : address)
        let now = Date()
        let dateFormat = DateFormatter()
        dateFormat.dateFormat = "E-d-MMM-yyyy-HH-mm-ss"
        let date = dateFormat.string(from: now)
        
        filePath = filePath.appending("_\(date).mkv")
        
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        var writablePath = paths[0]
        writablePath = writablePath.appending("/\(filePath)")
        return writablePath
        //file name is recording_contact-name_dayName-day-monthName-year-hour-minutes-seconds
        //The recording prefix is used to identify recordings in the cache directory.
        //We will use name_dayName-day-monthName-year to separate recordings by days, then hour-minutes-seconds to order them in each day.
    }
}
