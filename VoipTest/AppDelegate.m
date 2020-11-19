//
//  AppDelegate.m
//  VoipTest
//
//  Created by StevStark on 2020/11/10.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    [LinphoneManager.instance launchLinphoneCore];
    // Override point for customization after application launch.
    UIApplication *app = [UIApplication sharedApplication];
    if (!account_creator) {
        account_creator = linphone_account_creator_new(
                                                       [LinphoneManager getLc],
                                                       [ConfigManager.instance lpConfigStringForKeyWithKey:@"xmlrpc_url"  section:@"assistant" defaultValue:@""]
                                                       .UTF8String);
    }
    [self loadAssistantConfig:@"assistant_external_sip.rc"];
    return YES;
}

- (void)loadAssistantConfig:(NSString *)rcFilename {
    linphone_core_load_config_from_xml( [LinphoneManager getLc],
                                       [LinphoneManager bundleFile:rcFilename].UTF8String);
   
    if (account_creator) {
        linphone_account_creator_set_domain(account_creator, [ [ConfigManager.instance lpConfigStringForKeyWithKey:@"domain" section:@"assistant" defaultValue:@""] UTF8String]);
        
        
        linphone_account_creator_set_algorithm(account_creator, [[ConfigManager.instance lpConfigStringForKeyWithKey:@"algorithm" section:@"assistant" defaultValue:@""] UTF8String]);
    }
}
#pragma mark - UISceneSession lifecycle


- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}


- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
}

- (void)providerDidReset:(nonnull CXProvider *)provider {
    
}

@end


