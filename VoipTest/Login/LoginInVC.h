//
//  LoginInVC.h
//  VoipTest
//
//  Created by StevStark on 2020/11/18.
//

#import <UIKit/UIKit.h>
#import "LinphoneManager.h"
NS_ASSUME_NONNULL_BEGIN

@interface LoginInVC : UIViewController
@property (weak, nonatomic) IBOutlet UITextField *t_account;
@property (weak, nonatomic) IBOutlet UITextField *t_pwd;

@property (weak, nonatomic) IBOutlet UITextField *t_domain;
@property (weak, nonatomic) IBOutlet UILabel *logView;

@end

NS_ASSUME_NONNULL_END
