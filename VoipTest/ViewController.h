//
//  ViewController.h
//  VoipTest
//
//  Created by StevStark on 2020/11/10.
//

#import <UIKit/UIKit.h>
#import "LinphoneManager.h"
@interface ViewController : UIViewController
@property (weak, nonatomic) IBOutlet UIView *v_video;
@property (weak, nonatomic) IBOutlet UITextField *t_callNum;

@property (weak, nonatomic) IBOutlet UIView *v_self;

@end

