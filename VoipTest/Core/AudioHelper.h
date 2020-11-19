//
//  AudioHelper.h
//  VoipTest
//
//  Created by StevStark on 2020/11/11.
//

#ifndef AudioHelper_h
#define AudioHelper_h

#import <Foundation/Foundation.h>

@import AVFoundation;

@interface AudioHelper : NSObject

+ (NSArray *)bluetoothRoutes;
+ (AVAudioSessionPortDescription *)bluetoothAudioDevice;
+ (AVAudioSessionPortDescription *)builtinAudioDevice;
+ (AVAudioSessionPortDescription *)speakerAudioDevice;
+ (AVAudioSessionPortDescription *)audioDeviceFromTypes:(NSArray *)types;
@end

#endif /* AudioHelper_h */
