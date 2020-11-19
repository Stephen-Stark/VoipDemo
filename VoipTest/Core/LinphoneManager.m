//
//  LinphoneManager.m
//  VoipTest
//
//  Created by StevStark on 2020/11/11.
//

#import "LinphoneManager.h"



NSString *const kLinphoneBluetoothAvailabilityUpdate = @"LinphoneBluetoothAvailabilityUpdate";
NSString *const kLinphoneGlobalStateUpdate = @"LinphoneGlobalStateUpdate";
NSString *const kLinphoneConfiguringStateUpdate = @"LinphoneConfiguringStateUpdate";
NSString *const kLinphoneCoreUpdate = @"LinphoneCoreUpdate";
NSString *const kLinphoneRegistrationUpdate = @"LinphoneRegistrationUpdate";
NSString *const kLinphoneNotifyPresenceReceivedForUriOrTel = @"LinphoneNotifyPresenceReceivedForUriOrTel";
NSString *const kLinphoneNotifyReceived = @"LinphoneNotifyReceived";
NSString *const kLinphoneCallEncryptionChanged = @"LinphoneCallEncryptionChanged";
NSString *const kLinphoneMessageReceived = @"LinphoneMessageReceived";
NSString *const kLinphoneTextComposeEvent = @"LinphoneTextComposeStarted";

NSString *const kLinphoneOldChatDBFilename = @"chat_database.sqlite";
NSString *const kLinphoneInternalChatDBFilename = @"linphone_chats.db";
NSString *const LINPHONERC_APPLICATION_KEY = @"app";

extern void libmsamr_init(MSFactory *factory);
extern void libmsx264_init(MSFactory *factory);
extern void libmsopenh264_init(MSFactory *factory);
extern void libmssilk_init(MSFactory *factory);
extern void libmswebrtc_init(MSFactory *factory);
extern void libmscodec2_init(MSFactory *factory);

@interface LinphoneManager ()
@property(strong, nonatomic) AVAudioPlayer* messagePlayer;
@end

@implementation LinphoneManager
- (id)init {
    if ((self = [super init])) {
        [NSNotificationCenter.defaultCenter addObserver:self
         selector:@selector(audioRouteChangeListenerCallback:)
         name:AVAudioSessionRouteChangeNotification
         object:nil];

        NSString *path = [[NSBundle mainBundle] pathForResource:@"msg" ofType:@"wav"];
        self.messagePlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL URLWithString:path] error:nil];

    
        _sounds.vibrate = kSystemSoundID_Vibrate;
        [self migrateImportantFiles];
        [self renameDefaultSettings];
        [self copyDefaultSettings];
        [self overrideDefaultSettings];

        [ConfigManager.instance lpConfigSetStringWithValue:[LinphoneManager dataFile:@"linphone.db"] key:@"uri" section:@"storage"];
        [ConfigManager.instance lpConfigSetStringWithValue:[LinphoneManager dataFile:@"x3dh.c25519.sqlite3"] key:@"x3dh_db_path" section:@"lime"];
        // set default values for first boot
        
        
        if ([ConfigManager.instance lpConfigStringForKeyWithKey:@"debugenable_preference"] == nil) {
#ifdef DEBUG
            [ConfigManager.instance lpConfigSetIntWithValue:1 key:@"debugenable_preference"];
            
#else
            [ConfigManager.instance lpConfigSetIntWithValue:0 key:@"debugenable_preference"];
            
#endif
        }

       
        // by default if handle_content_encoding is not set, we use plain text for debug purposes only
        if ( [ConfigManager.instance lpConfigStringForKeyWithKey:@"handle_content_encoding" section:@"misc"] == nil) {
#ifdef DEBUG
            [ConfigManager.instance lpConfigSetStringWithValue:@"none" key:@"handle_content_encoding" section:@"misc"];
            
#else
            [ConfigManager.instance lpConfigSetStringWithValue:@"conflate" key:@"handle_content_encoding" section:@"misc"];
#endif
        }
        [self migrateFromUserPrefs];
        
    }
    return self;
}

+ (LinphoneManager *)instance {
    @synchronized(self) {
        if (theLinphoneManager == nil) {
            theLinphoneManager = [[LinphoneManager alloc] init];
        }
    }
    return theLinphoneManager;
}

+ (LinphoneCore *)getLc {
    if (theLinphoneCore == nil) {
        @throw([NSException exceptionWithName:@"LinphoneCoreException"
            reason:@"Linphone core not initialized yet"
            userInfo:nil]);
    }
    return theLinphoneCore;
}
- (void)migrateImportantFiles {
    if ([LinphoneManager copyFile:[LinphoneManager oldPreferenceFile:@"linphonerc"] destination:[LinphoneManager preferenceFile:@"linphonerc"] override:TRUE ignore:TRUE]) {
        [NSFileManager.defaultManager
        removeItemAtPath:[LinphoneManager oldPreferenceFile:@"linphonerc"]
        error:nil];
    } else if ([LinphoneManager copyFile:[LinphoneManager documentFile:@"linphonerc"] destination:[LinphoneManager preferenceFile:@"linphonerc"] override:TRUE ignore:TRUE]) {
        [NSFileManager.defaultManager
        removeItemAtPath:[LinphoneManager documentFile:@"linphonerc"]
        error:nil];
    }

    if ([LinphoneManager copyFile:[LinphoneManager oldDataFile:@"linphone.db"] destination:[LinphoneManager dataFile:@"linphone.db"] override:TRUE ignore:TRUE]) {
        [NSFileManager.defaultManager
        removeItemAtPath:[LinphoneManager oldDataFile:@"linphone.db"]
        error:nil];
    }

    if ([LinphoneManager copyFile:[LinphoneManager oldDataFile:@"x3dh.c25519.sqlite3"] destination:[LinphoneManager dataFile:@"x3dh.c25519.sqlite3"] override:TRUE ignore:TRUE]) {
        [NSFileManager.defaultManager
        removeItemAtPath:[LinphoneManager oldDataFile:@"x3dh.c25519.sqlite3"]
        error:nil];
    }

    // call history
    if ([LinphoneManager copyFile:[LinphoneManager oldDataFile:kLinphoneInternalChatDBFilename] destination:[LinphoneManager dataFile:kLinphoneInternalChatDBFilename] override:TRUE ignore:TRUE]) {
        [NSFileManager.defaultManager
        removeItemAtPath:[LinphoneManager oldDataFile:kLinphoneInternalChatDBFilename]
        error:nil];
    }

    if ([LinphoneManager copyFile:[LinphoneManager oldDataFile:@"zrtp_secrets"] destination:[LinphoneManager dataFile:@"zrtp_secrets"] override:TRUE ignore:TRUE]) {
        [NSFileManager.defaultManager
        removeItemAtPath:[LinphoneManager oldDataFile:@"zrtp_secrets"]
        error:nil];
    }
}

- (void)renameDefaultSettings {
    // rename .linphonerc to linphonerc to ease debugging: when downloading
    // containers from MacOSX, Finder do not display hidden files leading
    // to useless painful operations to display the .linphonerc file
    NSString *src = [LinphoneManager documentFile:@".linphonerc"];
    NSString *dst = [LinphoneManager preferenceFile:@"linphonerc"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *fileError = nil;
    if ([fileManager fileExistsAtPath:src]) {
        if ([fileManager fileExistsAtPath:dst]) {
            [fileManager removeItemAtPath:src error:&fileError];
            
        } else {
            [fileManager moveItemAtPath:src toPath:dst error:&fileError];
           
        }
    }
}

- (void)copyDefaultSettings {
    NSString *src = [LinphoneManager bundleFile:@"linphonerc"];
    NSString *dst = [LinphoneManager preferenceFile:@"linphonerc"];
    [LinphoneManager copyFile:src destination:dst override:FALSE ignore:FALSE];
}

- (void)overrideDefaultSettings {
    NSString *linphonecfg = [LinphoneManager bundleFile:@"linphonerc"];
    NSString *fileStr = [NSString stringWithContentsOfFile:linphonecfg encoding:NSUTF8StringEncoding error:nil];
    _configDb = linphone_config_new_from_buffer(fileStr.UTF8String);
    //linphone_config_new_with_factory(linphonecfg.UTF8String, factory.UTF8String);
    lp_config_clean_entry(_configDb, "misc", "max_calls");
}



+ (NSString *)dataFile:(NSString *)file {
    LinphoneFactory *factory = linphone_factory_get();
    
    NSString *fullPath = [NSString stringWithUTF8String:linphone_factory_get_data_dir(factory,nil)];
    
    return [fullPath stringByAppendingPathComponent:file];
}

- (void)migrateFromUserPrefs {
    static NSString *migration_flag = @"userpref_migration_done";

    if (_configDb == nil)
        return;

    
    if ([ConfigManager.instance lpConfigIntForKeyWithKey:migration_flag defaultValue:0]) {
        return;
    }

    NSDictionary *defaults = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
    NSArray *defaults_keys = [defaults allKeys];
    NSDictionary *values =
        @{ @"backgroundmode_preference" : @NO,
           @"debugenable_preference" : @NO,
           @"start_at_boot_preference" : @YES };
    BOOL shouldSync = FALSE;

    for (NSString *userpref in values) {
        if ([defaults_keys containsObject:userpref]) {
            [ConfigManager.instance lpConfigSetBoolWithValue:[[defaults objectForKey:userpref] boolValue] key:userpref];
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:userpref];
            shouldSync = TRUE;
           
        } else if ( [ConfigManager.instance lpConfigStringForKeyWithKey:userpref] == nil) {
            // no default value found in our linphonerc, we need to add them
            
            [ConfigManager.instance lpConfigSetBoolWithValue:[[values objectForKey:userpref] boolValue] key:userpref];
        }
    }
    if (shouldSync) {
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    // don't get back here in the future
    [ConfigManager.instance lpConfigSetBoolWithValue:YES key:migration_flag];
}


- (void)audioRouteChangeListenerCallback:(NSNotification *)notif {

    // there is at least one bug when you disconnect an audio bluetooth headset
    // since we only get notification of route having changed, we cannot tell if that is due to:
    // -bluetooth headset disconnected or
    // -user wanted to use earpiece
    // the only thing we can assume is that when we lost a device, it must be a bluetooth one (strong hypothesis though)
    if ([[notif.userInfo valueForKey:AVAudioSessionRouteChangeReasonKey] integerValue] == AVAudioSessionRouteChangeReasonOldDeviceUnavailable)
        _bluetoothAvailable = NO;

    AVAudioSessionRouteDescription *newRoute = [AVAudioSession sharedInstance].currentRoute;

    if (newRoute && newRoute.outputs.count > 0) {
        NSString *route = newRoute.outputs[0].portType;
        

        CallManager.instance.speakerEnabled = [route isEqualToString:AVAudioSessionPortBuiltInSpeaker];
        if (([[AudioHelper bluetoothRoutes] containsObject:route]) && !CallManager.instance.speakerEnabled) {
            _bluetoothAvailable = TRUE;
            CallManager.instance.bluetoothEnabled = TRUE;
        } else
            CallManager.instance.bluetoothEnabled = FALSE;

        NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:_bluetoothAvailable], @"available", nil];
        [NSNotificationCenter.defaultCenter postNotificationName:kLinphoneBluetoothAvailabilityUpdate
         object:self
         userInfo:dict];
    }
}

+ (BOOL)copyFile:(NSString *)src destination:(NSString *)dst override:(BOOL)override ignore:(BOOL)ignore {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSError *error = nil;
    if ([fileManager fileExistsAtPath:src] == NO) {
        if (!ignore)
          
        return FALSE;
    }
    if ([fileManager fileExistsAtPath:dst] == YES) {
        if (override) {
            [fileManager removeItemAtPath:dst error:&error];
            if (error != nil) {
              
                return FALSE;
            }
        } else {
           
            return FALSE;
        }
    }
    [fileManager copyItemAtPath:src toPath:dst error:&error];
    if (error != nil) {
      
        return FALSE;
    }
    return TRUE;
}

+ (NSString *)oldPreferenceFile:(NSString *)file {
    // migration
    LinphoneFactory *factory = linphone_factory_get();
    NSString *fullPath = [NSString stringWithUTF8String:linphone_factory_get_config_dir(factory, nil)];
    return [fullPath stringByAppendingPathComponent:file];
}

+ (NSString *)preferenceFile:(NSString *)file {
    LinphoneFactory *factory = linphone_factory_get();
    NSString *fullPath = [NSString stringWithUTF8String:linphone_factory_get_config_dir(factory, nil)];
    return [fullPath stringByAppendingPathComponent:file];
}

+ (NSString *)documentFile:(NSString *)file {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsPath = [paths objectAtIndex:0];
    return [documentsPath stringByAppendingPathComponent:file];
}


+ (NSString *)oldDataFile:(NSString *)file {
    // migration
    LinphoneFactory *factory = linphone_factory_get();
    NSString *fullPath = [NSString stringWithUTF8String:linphone_factory_get_data_dir(factory, nil)];
    return [fullPath stringByAppendingPathComponent:file];
}

+ (NSString *)bundleFile:(NSString *)file {
    return [[NSBundle mainBundle] pathForResource:[file stringByDeletingPathExtension] ofType:[file pathExtension]];
}

static BOOL libStarted = FALSE;

- (void)launchLinphoneCore {

    if (libStarted) {
        return;
    }

    libStarted = TRUE;

    signal(SIGPIPE, SIG_IGN);

    // create linphone core
    [self createLinphoneCore];
    

  
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    BOOL bAudioInputAvailable = audioSession.inputAvailable;
    NSError *err = nil;

    if (![audioSession setActive:NO error:&err] && err) {
    
        err = nil;
    }
    if (!bAudioInputAvailable) {
       
    }
}

- (void)createLinphoneCore {
    [self migrationAllPre];
    if (theLinphoneCore != nil) {
        return;
    }


    // Set audio assets
    NSString *ring =
        ([LinphoneManager bundleFile:@"notes_of_the_optimistic.caf"])
        .lastPathComponent;
    NSString *ringback =
        ([LinphoneManager bundleFile:@"ringback.wav"])
        .lastPathComponent;
    NSString *hold =
        ([LinphoneManager bundleFile:@"hold.mkv"])
        .lastPathComponent;
    
    [ConfigManager.instance lpConfigSetStringWithValue:[LinphoneManager bundleFile:ring] key:@"local_ring" section:@"sound"];
    [ConfigManager.instance lpConfigSetStringWithValue:[LinphoneManager bundleFile:ringback] key:@"remote_ring" section:@"sound"];
    [ConfigManager.instance lpConfigSetStringWithValue:[LinphoneManager bundleFile:hold] key:@"hold_music" section:@"sound"];
 
    
    LinphoneFactory *factory = linphone_factory_get();
    LinphoneCoreCbs *cbs = linphone_factory_create_core_cbs(factory);
    linphone_core_cbs_set_registration_state_changed(cbs,linphone_iphone_registration_state);
    linphone_core_cbs_set_notify_presence_received_for_uri_or_tel(cbs, linphone_iphone_notify_presence_received_for_uri_or_tel);
    linphone_core_cbs_set_authentication_requested(cbs, linphone_iphone_popup_password_request);
    linphone_core_cbs_set_message_received(cbs, linphone_iphone_message_received);
    linphone_core_cbs_set_message_received_unable_decrypt(cbs, linphone_iphone_message_received_unable_decrypt);
    linphone_core_cbs_set_transfer_state_changed(cbs, linphone_iphone_transfer_state_changed);
    linphone_core_cbs_set_is_composing_received(cbs, linphone_iphone_is_composing_received);
    linphone_core_cbs_set_configuring_status(cbs, linphone_iphone_configuring_status_changed);
    linphone_core_cbs_set_global_state_changed(cbs, linphone_iphone_global_state_changed);
    linphone_core_cbs_set_notify_received(cbs, linphone_iphone_notify_received);
    linphone_core_cbs_set_call_encryption_changed(cbs, linphone_iphone_call_encryption_changed);
    linphone_core_cbs_set_chat_room_state_changed(cbs, linphone_iphone_chatroom_state_changed);

    linphone_core_cbs_set_call_log_updated(cbs, linphone_iphone_call_log_updated);
    linphone_core_cbs_set_user_data(cbs, (__bridge void *)(self));
    theLinphoneCore =  linphone_factory_create_core_with_config_3(factory, _configDb, NULL);
    linphone_core_add_callbacks(theLinphoneCore, cbs);

    [CallManager.instance setCoreWithCore:theLinphoneCore];
    [CoreManager.instance setCoreWithCore:theLinphoneCore];
    [ConfigManager.instance setDbWithDb:_configDb];

    linphone_core_start(theLinphoneCore);

    NSLog(@"创建成功");
    // Let the core handle cbs
    linphone_core_cbs_unref(cbs);


    // Load plugins if available in the linphone SDK - otherwise these calls will do nothing
    MSFactory *f = linphone_core_get_ms_factory(theLinphoneCore);
    libmssilk_init(f);
    libmsamr_init(f);
    libmsx264_init(f);
    libmsopenh264_init(f);
    libmswebrtc_init(f);
    libmscodec2_init(f);

    linphone_core_reload_ms_plugins(theLinphoneCore, NULL);
    [self migrationAllPost];

    /* Use the rootca from framework, which is already set*/
    //linphone_core_set_root_ca(theLinphoneCore, [LinphoneManager bundleFile:@"rootca.pem"].UTF8String);
    linphone_core_set_user_certificates_path(theLinphoneCore, [LinphoneManager cacheDirectory].UTF8String);

    /* The core will call the linphone_iphone_configuring_status_changed callback when the remote provisioning is loaded
       (or skipped).
       Wait for this to finish the code configuration */

    [NSNotificationCenter.defaultCenter addObserver:self
     selector:@selector(globalStateChangedNotificationHandler:)
     name:kLinphoneGlobalStateUpdate
     object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
     selector:@selector(configuringStateChangedNotificationHandler:)
     name:kLinphoneConfiguringStateUpdate
     object:nil];
    

    /*call iterate once immediately in order to initiate background connections with sip server or remote provisioning
     * grab, if any */
//    [self iterate];
    // start scheduler
    [CoreManager.instance startIterateTimer];
}



- (void)migrationAllPre {
    // migrate xmlrpc URL if needed
    if ([ConfigManager.instance lpConfigBoolForKeyWithKey:@"migration_xmlrpc"] == NO) {
        [ConfigManager.instance lpConfigSetStringWithValue:@"https://subscribe.linphone.org:444/wizard.php" key:@"xmlrpc_url" section:@"assistant"];
        [ConfigManager.instance lpConfigSetStringWithValue:@"sip:rls@sip.linphone.org" key:@"rls_uri" section:@"sip"];
        [ConfigManager.instance lpConfigSetBoolWithValue:YES key:@"migration_xmlrpc"];
    }
    [ConfigManager.instance lpConfigSetBoolWithValue:NO key:@"store_friends" section:@"misc"];
   //so far, storing friends in files is not needed. may change in the future.
    
}

- (void)migrationAllPost {
    [self migrationLinphoneSettings];
    [self migrationPerAccount];
}

+ (NSString *)cacheDirectory {
    LinphoneFactory *factory = linphone_factory_get();
    
    NSString *cachePath = [NSString stringWithUTF8String:linphone_factory_get_download_dir(factory, NULL)];
    BOOL isDir = NO;
    NSError *error;
    // cache directory must be created if not existing
    if (![[NSFileManager defaultManager] fileExistsAtPath:cachePath isDirectory:&isDir] && isDir == NO) {
        [[NSFileManager defaultManager] createDirectoryAtPath:cachePath
         withIntermediateDirectories:NO
         attributes:nil
         error:&error];
    }
    return cachePath;
}

- (void)globalStateChangedNotificationHandler:(NSNotification *)notif {
    if ((LinphoneGlobalState)[[[notif userInfo] valueForKey:@"state"] integerValue] == LinphoneGlobalOn) {
        [self finishCoreConfiguration];
    }
}

- (void)iterate {
    linphone_core_iterate(theLinphoneCore);
}

- (void)configuringStateChangedNotificationHandler:(NSNotification *)notif {
   
    
}


- (void)migrationPerAccount {
    const bctbx_list_t * proxies = linphone_core_get_proxy_config_list(theLinphoneCore);
    
    
    NSString *appDomain  = [ConfigManager.instance lpConfigStringForKeyWithKey:@"domain_name" section:@"app" defaultValue:@"sip.linphone.org"];
    while (proxies) {
        LinphoneProxyConfig *config = proxies->data;
        // can not create group chat without conference factory
        if (!linphone_proxy_config_get_conference_factory_uri(config)) {
            if (strcmp(appDomain.UTF8String, linphone_proxy_config_get_domain(config)) == 0) {
                linphone_proxy_config_set_conference_factory_uri(config, "sip:conference-factory@sip.linphone.org");
            }
        }
        proxies = proxies->next;
    }
    
    NSString *s = [ConfigManager.instance lpConfigStringForKeyWithKey:@"pushnotification_preference"];
    if (s && s.boolValue) {
       
        [ConfigManager.instance lpConfigSetBoolWithValue:NO key:@"pushnotification_preference"];
        const MSList *proxies = linphone_core_get_proxy_config_list(theLinphoneCore);
        while (proxies) {
            linphone_proxy_config_set_push_notification_allowed(proxies->data, true);
//            [self configurePushTokenForProxyConfig:proxies->data];
            proxies = proxies->next;
        }
    }
}
- (void)migrationLinphoneSettings {
    /* AVPF migration */
  
    
    if ( [ConfigManager.instance lpConfigBoolForKeyWithKey:@"avpf_migration_done"] == FALSE) {
        const MSList *proxies = linphone_core_get_proxy_config_list(theLinphoneCore);
        while (proxies) {
            LinphoneProxyConfig *proxy = (LinphoneProxyConfig *)proxies->data;
            const char *addr = linphone_proxy_config_get_addr(proxy);
            // we want to enable AVPF for the proxies
        
            if (addr &&
                strstr(addr,     [ConfigManager.instance lpConfigStringForKeyWithKey:@"domain_name" section:@"app" defaultValue:@"sip.linphone.org"]
                   .UTF8String) != 0) {
                linphone_proxy_config_enable_avpf(proxy, TRUE);
            }
            proxies = proxies->next;
        }
        [ConfigManager.instance lpConfigSetBoolWithValue:TRUE key:@"avpf_migration_done"];

    }
    /* Quality Reporting migration */
    if ([ConfigManager.instance lpConfigBoolForKeyWithKey:@"quality_report_migration_done"] == FALSE) {
        const MSList *proxies = linphone_core_get_proxy_config_list(theLinphoneCore);
        while (proxies) {
            LinphoneProxyConfig *proxy = (LinphoneProxyConfig *)proxies->data;
            const char *addr = linphone_proxy_config_get_addr(proxy);
            // we want to enable quality reporting for the proxies that are on linphone.org
           
            if (addr &&
                strstr(addr,  [ConfigManager.instance lpConfigStringForKeyWithKey: @"domain_name" section:@"app" defaultValue:@"sip.linphone.org"]
                   .UTF8String) != 0) {
               
                linphone_proxy_config_set_quality_reporting_collector(
                                              proxy, "sip:voip-metrics@sip.linphone.org;transport=tcp");
                linphone_proxy_config_set_quality_reporting_interval(proxy, 180);
                linphone_proxy_config_enable_quality_reporting(proxy, TRUE);
            }
            proxies = proxies->next;
        }
        [ConfigManager.instance lpConfigSetBoolWithValue:TRUE key:@"quality_report_migration_done"];
    }
    /* File transfer migration */
    if ([ConfigManager.instance lpConfigBoolForKeyWithKey:@"file_transfer_migration_done"] == FALSE) {
        const char *newURL = "https://www.linphone.org:444/lft.php";
       
        linphone_core_set_file_transfer_server(theLinphoneCore, newURL);
        [ConfigManager.instance lpConfigSetBoolWithValue:TRUE key:@"file_transfer_migration_done"];
    }
    
    if ([ConfigManager.instance lpConfigBoolForKeyWithKey:@"lime_migration_done"] == FALSE) {
        const MSList *proxies = linphone_core_get_proxy_config_list(theLinphoneCore);
        while (proxies) {
            if (!strcmp(linphone_proxy_config_get_domain((LinphoneProxyConfig *)proxies->data),"sip.linphone.org")) {
                linphone_core_set_lime_x3dh_server_url(theLinphoneCore, "https://lime.linphone.org/lime-server/lime-server.php");
                break;
            }
            proxies = proxies->next;
        }
        [ConfigManager.instance lpConfigSetBoolWithValue:TRUE key:@"lime_migration_done"];
    }

    if ([ConfigManager.instance lpConfigBoolForKeyWithKey:@"push_notification_migration_done"] == FALSE) {
        const MSList *proxies = linphone_core_get_proxy_config_list(theLinphoneCore);
        bool_t pushEnabled;
        while (proxies) {
            const char *refkey = linphone_proxy_config_get_ref_key(proxies->data);
            if (refkey) {
                pushEnabled = (strcmp(refkey, "push_notification") == 0);
            } else {
                pushEnabled = true;
            }
            linphone_proxy_config_set_push_notification_allowed(proxies->data, pushEnabled);
            proxies = proxies->next;
        }
        [ConfigManager.instance lpConfigSetBoolWithValue:TRUE key:@"push_notification_migration_done"];
    }
}

- (void)finishCoreConfiguration {
    //Force keep alive to workaround push notif on chat message
    linphone_core_enable_keep_alive(theLinphoneCore, true);

    // get default config from bundle
    NSString *zrtpSecretsFileName = [LinphoneManager dataFile:@"zrtp_secrets"];
    NSString *chatDBFileName = [LinphoneManager dataFile:kLinphoneInternalChatDBFilename];
    NSString *device = [[NSMutableString alloc] initWithString:[NSString stringWithFormat:@"%@iOS/%@ (%@) LinphoneSDK",
                                    [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleDisplayName"],
                                    [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
                                    [[UIDevice currentDevice] name]]];

   
    linphone_core_set_user_agent(theLinphoneCore, device.UTF8String,LINPHONE_SDK_VERSION);
    
   
    _contactSipField =  [ConfigManager.instance lpConfigStringForKeyWithKey:@"contact_im_type_value"  section:@"sip" defaultValue:@"SIP"];

    

    linphone_core_set_zrtp_secrets_file(theLinphoneCore, [zrtpSecretsFileName UTF8String]);
    //linphone_core_set_chat_database_path(theLinphoneCore, [chatDBFileName UTF8String]);
    linphone_core_set_call_logs_database_path(theLinphoneCore, [chatDBFileName UTF8String]);

    NSString *path = [LinphoneManager bundleFile:@"nowebcamCIF.jpg"];
    if (path) {
        const char *imagePath = [path UTF8String];
        linphone_core_set_static_picture(theLinphoneCore, imagePath);
    }

    /*DETECT cameras*/
    _frontCamId = _backCamId = nil;
    char **camlist = (char **)linphone_core_get_video_devices(theLinphoneCore);
    if (camlist) {
        for (char *cam = *camlist; *camlist != NULL; cam = *++camlist) {
            if (strcmp(FRONT_CAM_NAME, cam) == 0) {
                _frontCamId = cam;
                // great set default cam to front
              
                linphone_core_set_video_device(theLinphoneCore, _frontCamId);
            }
            if (strcmp(BACK_CAM_NAME, cam) == 0) {
                _backCamId = cam;
            }
        }
    } else {
        
    }

//    [self enableProxyPublish:([UIApplication sharedApplication].applicationState == UIApplicationStateActive)];

 
    // Post event
    NSDictionary *dict = [NSDictionary dictionaryWithObject:[NSValue valueWithPointer:theLinphoneCore] forKey:@"core"];

    [NSNotificationCenter.defaultCenter postNotificationName:kLinphoneCoreUpdate
     object:LinphoneManager.instance
     userInfo:dict];
}

- (void)onRegister:(LinphoneCore *)lc
cfg:(LinphoneProxyConfig *)cfg
state:(LinphoneRegistrationState)state
message:(const char *)cmessage {

    LinphoneReason reason = linphone_proxy_config_get_error(cfg);
    NSString *message = nil;
    switch (reason) {
    case LinphoneReasonBadCredentials:
        message = NSLocalizedString(@"Bad credentials, check your account settings", nil);
        break;
    case LinphoneReasonNoResponse:
        message = NSLocalizedString(@"No response received from remote", nil);
        break;
    case LinphoneReasonUnsupportedContent:
        message = NSLocalizedString(@"Unsupported content", nil);
        break;
    case LinphoneReasonIOError:
        message = NSLocalizedString(
                        @"Cannot reach the server: either it is an invalid address or it may be temporary down.", nil);
        break;

    case LinphoneReasonUnauthorized:
        message = NSLocalizedString(@"Operation is unauthorized because missing credential", nil);
        break;
    case LinphoneReasonNoMatch:
        message = NSLocalizedString(@"Operation could not be executed by server or remote client because it "
                        @"didn't have any context for it",
                        nil);
        break;
    case LinphoneReasonMovedPermanently:
        message = NSLocalizedString(@"Resource moved permanently", nil);
        break;
    case LinphoneReasonGone:
        message = NSLocalizedString(@"Resource no longer exists", nil);
        break;
    case LinphoneReasonTemporarilyUnavailable:
        message = NSLocalizedString(@"Temporarily unavailable", nil);
        break;
    case LinphoneReasonAddressIncomplete:
        message = NSLocalizedString(@"Address incomplete", nil);
        break;
    case LinphoneReasonNotImplemented:
        message = NSLocalizedString(@"Not implemented", nil);
        break;
    case LinphoneReasonBadGateway:
        message = NSLocalizedString(@"Bad gateway", nil);
        break;
    case LinphoneReasonServerTimeout:
        message = NSLocalizedString(@"Server timeout", nil);
        break;
    case LinphoneReasonNotAcceptable:
    case LinphoneReasonDoNotDisturb:
    case LinphoneReasonDeclined:
    case LinphoneReasonNotFound:
    case LinphoneReasonNotAnswered:
    case LinphoneReasonBusy:
    case LinphoneReasonNone:
    case LinphoneReasonUnknown:
        message = NSLocalizedString(@"Unknown error", nil);
        break;
    }

    // Post event
    NSDictionary *dict =
        [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:state], @"state",
         [NSValue valueWithPointer:cfg], @"cfg", message, @"message", nil];
    [NSNotificationCenter.defaultCenter postNotificationName:kLinphoneRegistrationUpdate object:nil userInfo:dict];
}

- (void)onNotifyPresenceReceivedForUriOrTel:(LinphoneCore *)lc
friend:(LinphoneFriend *)lf
uri:(const char *)uri
presenceModel:(const LinphonePresenceModel *)model {
    // Post event
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:[NSValue valueWithPointer:lf] forKey:@"friend"];
    [dict setObject:[NSValue valueWithPointer:uri] forKey:@"uri"];
    [dict setObject:[NSValue valueWithPointer:model] forKey:@"presence_model"];
    [NSNotificationCenter.defaultCenter postNotificationName:kLinphoneNotifyPresenceReceivedForUriOrTel
     object:self
     userInfo:dict];
}

- (void)onMessageReceived:(LinphoneCore *)lc room:(LinphoneChatRoom *)room message:(LinphoneChatMessage *)msg {

}

- (void)onMessageComposeReceived:(LinphoneCore *)core forRoom:(LinphoneChatRoom *)room {
    [NSNotificationCenter.defaultCenter postNotificationName:kLinphoneTextComposeEvent
     object:self
     userInfo:@{
            @"room" : [NSValue valueWithPointer:room]
                }];
}

-(void)login:(NSString*)username password:(NSString*)pwd domain:(NSString*) domain {
    LinphoneProxyConfig *config = linphone_core_create_proxy_config(theLinphoneCore);
    LinphoneAddress *addr = linphone_address_new(NULL);
    LinphoneAddress *tmpAddr = linphone_address_new([NSString stringWithFormat:@"sip:%@",domain].UTF8String);
    if (tmpAddr == nil) {
        return;
    }
    
    linphone_address_set_username(addr, username.UTF8String);
    linphone_address_set_port(addr, linphone_address_get_port(tmpAddr));
    linphone_address_set_domain(addr, linphone_address_get_domain(tmpAddr));
//    if (displayName && ![displayName isEqualToString:@""]) {
//        linphone_address_set_display_name(addr, displayName.UTF8String);
//    }
    linphone_proxy_config_set_identity_address(config, addr);
    // set transport
        NSString *type = @"TCP";
        linphone_proxy_config_set_route(
            config,
            [NSString stringWithFormat:@"%s;transport=%s", domain.UTF8String, type.lowercaseString.UTF8String]
                .UTF8String);
        linphone_proxy_config_set_server_addr(
            config,
            [NSString stringWithFormat:@"%s;transport=%s", domain.UTF8String, type.lowercaseString.UTF8String]
                .UTF8String);
    linphone_proxy_config_enable_publish(config, FALSE);
    linphone_proxy_config_enable_register(config, TRUE);

    LinphoneAuthInfo *info =
        linphone_auth_info_new(linphone_address_get_username(addr), // username
                               NULL,                                // user id
                               pwd.UTF8String,                        // passwd
                               NULL,                                // ha1
                               linphone_address_get_domain(addr),   // realm - assumed to be domain
                               linphone_address_get_domain(addr)    // domain
                               );
    linphone_core_add_auth_info(theLinphoneCore, info);
    linphone_address_unref(addr);
    linphone_address_unref(tmpAddr);
    if (config) {
//        [[LinphoneManager instance] configurePushTokenForProxyConfig:config];
        if (linphone_core_add_proxy_config(theLinphoneCore, config) != -1) {
            linphone_core_set_default_proxy_config(theLinphoneCore, config);
            // reload address book to prepend proxy config domain to contacts' phone number
            // todo: STOP doing that!
//            [[LinphoneManager.instance fastAddressBook] fetchContactsInBackGroundThread];
            NSLog(@"登录成功");
        }
    }
}


-(void)startCall:(NSString*)phoneNum {
    LinphoneProxyConfig *cfg = linphone_core_get_default_proxy_config(theLinphoneCore);
    const char *normvalue;
  normvalue = linphone_proxy_config_is_phone_number(cfg, phoneNum.UTF8String)
        ? linphone_proxy_config_normalize_phone_number(cfg, phoneNum.UTF8String)
      : phoneNum.UTF8String;

    LinphoneAddress *addr = linphone_proxy_config_normalize_sip_uri(cfg, normvalue);

  // numbers by default
  if (addr && cfg) {
      const char *username = linphone_proxy_config_get_dial_escape_plus(cfg) ? normvalue : phoneNum.UTF8String;
      if (linphone_proxy_config_is_phone_number(cfg, username))
          linphone_address_set_username(addr, linphone_proxy_config_normalize_phone_number(cfg, username));
   }
    [self call:addr];
    if (addr)
        linphone_address_destroy(addr);
}

-(void)endCall{
        LinphoneCall * call = linphone_core_get_current_call(theLinphoneCore);
    [CallManager.instance terminateCallWithCall:call];
}

-(void)fetchVideo{
    
    if (!linphone_core_video_display_enabled(theLinphoneCore))
        return;
    LinphoneCall *call = linphone_core_get_current_call(theLinphoneCore);
    if (call) {
        CallAppData *data = [CallManager getAppDataWithCall:call];
        data.videoRequested = TRUE;/* will be used later to notify user if video was not activated because of the linphone core*/
        [CallManager setAppDataWithCall:call appData:data];
        LinphoneCallParams *call_params = linphone_core_create_call_params(theLinphoneCore,call);
        linphone_call_params_enable_video(call_params, TRUE);
        linphone_call_update(call, call_params);
        linphone_call_params_unref(call_params);
    } else {
        
    }
    
}

- (void)call:(const LinphoneAddress *)iaddr {
    // First verify that network is available, abort otherwise.
    if (!linphone_core_is_network_reachable(theLinphoneCore)) {
        
        return;
    }

    // Then check that no GSM calls are in progress, abort otherwise.
    CTCallCenter *callCenter = [[CTCallCenter alloc] init];
    if ([callCenter currentCalls] != nil && floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_9_x_Max) {
      
        return;
    }
    
    if (!iaddr) {
        
        return;
    }
    // For OutgoingCall, show CallOutgoingView
    [CallManager.instance startCallWithAddr:iaddr isSas:FALSE];
}


- (void)onConfiguringStatusChanged:(LinphoneConfiguringState)status withMessage:(const char *)message {
    NSDictionary *dict = [NSDictionary
                  dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:status], @"state",
                  [NSString stringWithUTF8String:message ? message : ""], @"message", nil];

    // dispatch the notification asynchronously
    dispatch_async(dispatch_get_main_queue(), ^(void) {
            [NSNotificationCenter.defaultCenter postNotificationName:kLinphoneConfiguringStateUpdate
             object:self
             userInfo:dict];
        });
}


- (void)onGlobalStateChanged:(LinphoneGlobalState)state withMessage:(const char *)message {


    NSDictionary *dict = [NSDictionary
                  dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:state], @"state",
                  [NSString stringWithUTF8String:message ? message : ""], @"message", nil];

    // dispatch the notification asynchronously
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        if (theLinphoneCore && linphone_core_get_global_state(theLinphoneCore) != LinphoneGlobalOff)
            [NSNotificationCenter.defaultCenter postNotificationName:kLinphoneGlobalStateUpdate object:self userInfo:dict];
    });
}

- (void)onNotifyReceived:(LinphoneCore *)lc
event:(LinphoneEvent *)lev
notifyEvent:(const char *)notified_event
content:(const LinphoneContent *)body {
    // Post event
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:[NSValue valueWithPointer:lev] forKey:@"event"];
    [dict setObject:[NSString stringWithUTF8String:notified_event] forKey:@"notified_event"];
    if (body != NULL) {
        [dict setObject:[NSValue valueWithPointer:body] forKey:@"content"];
    }
    [NSNotificationCenter.defaultCenter postNotificationName:kLinphoneNotifyReceived object:self userInfo:dict];
}

- (void)onCallEncryptionChanged:(LinphoneCore *)lc
call:(LinphoneCall *)call
on:(BOOL)on
token:(const char *)authentication_token {
    // Post event
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:[NSValue valueWithPointer:call] forKey:@"call"];
    [dict setObject:[NSNumber numberWithBool:on] forKey:@"on"];
    if (authentication_token) {
        [dict setObject:[NSString stringWithUTF8String:authentication_token] forKey:@"token"];
    }
    [NSNotificationCenter.defaultCenter postNotificationName:kLinphoneCallEncryptionChanged object:self userInfo:dict];
}

// C Function
static void linphone_iphone_registration_state(LinphoneCore *lc, LinphoneProxyConfig *cfg,
                           LinphoneRegistrationState state, const char *message) {
    [(__bridge LinphoneManager *)linphone_core_cbs_get_user_data(linphone_core_get_current_callbacks(lc)) onRegister:lc cfg:cfg state:state message:message];
}

static void linphone_iphone_notify_presence_received_for_uri_or_tel(LinphoneCore *lc, LinphoneFriend *lf,
                                    const char *uri_or_tel,
                                    const LinphonePresenceModel *presence_model) {
    [(__bridge LinphoneManager *)linphone_core_cbs_get_user_data(linphone_core_get_current_callbacks(lc)) onNotifyPresenceReceivedForUriOrTel:lc
     friend:lf
     uri:uri_or_tel
     presenceModel:presence_model];
    
}

static void linphone_iphone_popup_password_request(LinphoneCore *lc, LinphoneAuthInfo *auth_info, LinphoneAuthMethod method) {
    // let the wizard handle its own errors
    printf("账号认证错误");
}

static void linphone_iphone_message_received(LinphoneCore *lc, LinphoneChatRoom *room, LinphoneChatMessage *message) {
    [(__bridge LinphoneManager *)linphone_core_cbs_get_user_data(linphone_core_get_current_callbacks(lc)) onMessageReceived:lc room:room message:message];
}

static void linphone_iphone_message_received_unable_decrypt(LinphoneCore *lc, LinphoneChatRoom *room,
                                LinphoneChatMessage *message) {
    NSString *callId = [NSString stringWithUTF8String:linphone_chat_message_get_custom_header(message, "Call-ID")];
}

static void linphone_iphone_transfer_state_changed(LinphoneCore *lc, LinphoneCall *call, LinphoneCallState state) {
    
    
}

static void linphone_iphone_is_composing_received(LinphoneCore *lc, LinphoneChatRoom *room) {
    [(__bridge LinphoneManager *)linphone_core_cbs_get_user_data(linphone_core_get_current_callbacks(lc)) onMessageComposeReceived:lc forRoom:room];
}

static void linphone_iphone_configuring_status_changed(LinphoneCore *lc, LinphoneConfiguringState status,
                               const char *message) {
    [(__bridge LinphoneManager *)linphone_core_cbs_get_user_data(linphone_core_get_current_callbacks(lc)) onConfiguringStatusChanged:status withMessage:message];
}

static void linphone_iphone_global_state_changed(LinphoneCore *lc, LinphoneGlobalState gstate, const char *message) {
    [(__bridge LinphoneManager *)linphone_core_cbs_get_user_data(linphone_core_get_current_callbacks(lc)) onGlobalStateChanged:gstate withMessage:message];
}

static void linphone_iphone_notify_received(LinphoneCore *lc, LinphoneEvent *lev, const char *notified_event,
                        const LinphoneContent *body) {
    [(__bridge LinphoneManager *)linphone_core_cbs_get_user_data(linphone_core_get_current_callbacks(lc)) onNotifyReceived:lc
     event:lev
     notifyEvent:notified_event
     content:body];
}

static void linphone_iphone_call_encryption_changed(LinphoneCore *lc, LinphoneCall *call, bool_t on,
                            const char *authentication_token) {
    [(__bridge LinphoneManager *)linphone_core_cbs_get_user_data(linphone_core_get_current_callbacks(lc)) onCallEncryptionChanged:lc
     call:call
     on:on
     token:authentication_token];
}

void linphone_iphone_chatroom_state_changed(LinphoneCore *lc, LinphoneChatRoom *cr, LinphoneChatRoomState state) {
    if (state == LinphoneChatRoomStateCreated) {
        [NSNotificationCenter.defaultCenter postNotificationName:kLinphoneMessageReceived object:nil];
    }
}

static void linphone_iphone_call_log_updated(LinphoneCore *lc, LinphoneCallLog *newcl) {
    if (linphone_call_log_get_status(newcl) == LinphoneCallEarlyAborted) {
        const char *cid = linphone_call_log_get_call_id(newcl);
        if (cid) {
            [CallManager.instance markCallAsDeclinedWithCallId:[NSString stringWithUTF8String:cid]];
        }
    }
}

@end
