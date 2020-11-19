//
//  LinphoneManager.h
//  VoipTest
//
//  Created by StevStark on 2020/11/11.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "AudioHelper.h"
#include "linphone/lpconfig.h"
#include "linphone/factory.h"
#include "linphone/linphonecore_utils.h"
#include "linphone/linphonecore.h"
#include "mediastreamer2/mscommon.h"
#import  "VoipTest-Swift.h"
#import  "AppDelegate.h"
#import <UIKit/UIKit.h>
#import <CoreTelephony/CTCallCenter.h>
#define LINPHONE_SDK_VERSION  "4.4.0"
#define FRONT_CAM_NAME                            \
    "AV Capture: com.apple.avfoundation.avcapturedevice.built-in_video:1" /*"AV Capture: Front Camera"*/
#define BACK_CAM_NAME                            \
    "AV Capture: com.apple.avfoundation.avcapturedevice.built-in_video:0" /*"AV Capture: Back Camera"*/

NS_ASSUME_NONNULL_BEGIN


typedef struct _LinphoneManagerSounds {
    SystemSoundID vibrate;
} LinphoneManagerSounds;

@interface LinphoneManager : NSObject
- (void)launchLinphoneCore;
+ (LinphoneManager*)instance;
+ (NSString*)bundleFile:(NSString*)file;
+ (LinphoneCore*) getLc;

-(void)login:(NSString*)username password:(NSString*)pwd domain:(NSString*) domain;
-(void)startCall:(NSString*)phoneNum;
-(void) endCall;
-(void)fetchVideo;
@property (readonly) const char*  frontCamId;
@property (readonly) const char*  backCamId;
@property (readonly) LinphoneManagerSounds sounds;
@property (readonly) LpConfig *configDb;
@property (nonatomic, assign) BOOL bluetoothAvailable;
@property (readonly) NSString* contactSipField;
@end


static LinphoneCore *theLinphoneCore;
static LinphoneManager *theLinphoneManager;


NS_ASSUME_NONNULL_END
