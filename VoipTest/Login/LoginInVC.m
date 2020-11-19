//
//  LoginInVC.m
//  VoipTest
//
//  Created by StevStark on 2020/11/18.
//

#import "LoginInVC.h"
#import "ViewController.h"
@interface LoginInVC ()

@end

@implementation LoginInVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(registrationUpdate:)
                                               name:@"LinphoneRegistrationUpdate"
                                             object:nil];
}

- (void)viewDidDisappear:(BOOL)animated{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)registrationUpdate:(NSNotification *)notif {
    LinphoneRegistrationState state = [[notif.userInfo objectForKey:@"state"] intValue];
    if (state == LinphoneRegistrationFailed){
        [self.logView setText:@"登录失败"];
        
    } else if (state == LinphoneRegistrationOk) {
        UIStoryboard *board = [UIStoryboard storyboardWithName: @"Main" bundle: nil];
        
        ViewController *vc = [board instantiateViewControllerWithIdentifier: @"ViewController"];
        [self presentViewController:vc animated:true completion:nil];
//        
//        UIWindow *window = ((AppDelegate*)([UIApplication sharedApplication].delegate)).window;
//        [window setRootViewController:vc];
        
    }
}


- (IBAction)b_login:(id)sender {
    [LinphoneManager.instance login:_t_account.text password:_t_pwd.text domain:_t_domain.text];
}


@end
