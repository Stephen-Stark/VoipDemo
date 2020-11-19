//
//  ConfigManager.swift
//  VoipTest
//
//  Created by StevStark on 2020/11/11.
//

import Foundation
import linphonesw

/*
* ConfigManager is a class that manipulates the configuration of the application.
* There is only one ConfigManager by calling ConfigManager.instance().
*/
@objc class ConfigManager: NSObject {
    static var theConfigManager: ConfigManager?
    var config: Config?
    let applicationKey = "app"

    @objc static func instance() -> ConfigManager {
        if (theConfigManager == nil) {
            theConfigManager = ConfigManager()
        }
        return theConfigManager!
    }

    @objc func setDb(db:OpaquePointer) {
        config = Config.getSwiftObject(cObject: db)
    }

    //pragma mark - LPConfig Functions
    @objc func lpConfigSetString(value:String, key:String, section:String) {
        if (!key.isEmpty) {
            config?.setString(section: section, key: key, value: value)
        }
    }

    @objc func lpConfigSetString(value:String, key:String) {
        lpConfigSetString(value: value, key: key, section: applicationKey)
    }

    @objc func lpConfigStringForKey(key:String, section:String, defaultValue:String) -> String {
        if (key.isEmpty) {
            return defaultValue
        }
        return config?.getString(section: section, key: key, defaultString: "") ?? defaultValue
    }

    @objc func lpConfigStringForKey(key:String, section:String) -> String {
        return lpConfigStringForKey(key: key, section: section, defaultValue: "")
    }

    @objc func lpConfigStringForKey(key:String, defaultValue:String) -> String {
        return lpConfigStringForKey(key: key, section: applicationKey, defaultValue: defaultValue)
    }

    @objc func lpConfigStringForKey(key:String) -> String {
        return lpConfigStringForKey(key: key, defaultValue: "")
    }

    @objc func lpConfigSetInt(value:Int, key:String, section:String) {
        if(!key.isEmpty) {
            config?.setInt(section: section, key: key, value: value)
        }
    }

    @objc func lpConfigSetInt(value:Int, key:String) {
        lpConfigSetInt(value: value, key: key, section: applicationKey)
    }

    @objc func lpConfigIntForKey(key:String, section:String, defaultValue:Int) -> Int {
        if (key.isEmpty) {
            return defaultValue
        }
        return config?.getInt(section: section, key: key, defaultValue: defaultValue) ?? defaultValue
    }

    @objc func lpConfigIntForKey(key:String, section:String) -> Int {
        return lpConfigIntForKey(key: key, section: section, defaultValue: -1)
    }

    @objc func lpConfigIntForKey(key:String, defaultValue:Int) -> Int {
        return lpConfigIntForKey(key: key, section: applicationKey, defaultValue: defaultValue)
    }

    @objc func lpConfigIntForKey(key:String) -> Int {
        return lpConfigIntForKey(key: key, defaultValue: -1)
    }

    @objc func lpConfigSetBool(value:Bool, key:String, section:String) {
        lpConfigSetInt(value: value ? 1:0, key: key, section: section)
    }

    @objc func lpConfigSetBool(value:Bool, key:String) {
        lpConfigSetBool(value: value, key: key, section: applicationKey)
    }

    @objc func lpConfigBoolForKey(key:String, section:String, defaultValue:Bool) -> Bool {
        if (key.isEmpty) {
            return defaultValue
        }
        let val = lpConfigIntForKey(key: key, section: section, defaultValue: -1)
        return (val != -1) ? (val == 1) : defaultValue
    }

    @objc func lpConfigBoolForKey(key:String, section:String) -> Bool {
        return lpConfigBoolForKey(key: key, section: section, defaultValue: false)
    }

    @objc func lpConfigBoolForKey(key:String, defaultValue:Bool) -> Bool {
        return lpConfigBoolForKey(key: key, section: applicationKey, defaultValue: defaultValue)
    }

    @objc func lpConfigBoolForKey(key:String) -> Bool {
        return lpConfigBoolForKey(key: key, defaultValue: false)
    }
}
