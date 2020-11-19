//
//  AppDelegate.h
//  VoipTest
//
//  Created by StevStark on 2020/11/10.
//

#import <UIKit/UIKit.h>
#import "LinphoneManager.h"
#import  "VoipTest-Swift.h"
#import <CallKit/CallKit.h>


@interface AppDelegate : UIResponder <UIApplicationDelegate,CXProviderDelegate> {
    LinphoneAccountCreator *account_creator;
  
 
}
@property (nonatomic, strong) UIWindow* window;


@end

