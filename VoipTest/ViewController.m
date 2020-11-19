//
//  ViewController.m
//  VoipTest
//
//  Created by StevStark on 2020/11/10.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
   
    linphone_core_set_native_video_window_id([LinphoneManager getLc], (__bridge void *)(self.v_video));
    linphone_core_set_native_preview_window_id([LinphoneManager getLc], (__bridge void *)(self.v_self));
    // Do any additional setup after loading the view.
}

- (IBAction)startCall:(id)sender {
    [LinphoneManager.instance startCall:_t_callNum.text];
}
- (IBAction)endCall:(id)sender {
    [LinphoneManager.instance endCall];
}

- (IBAction)fetchVideo:(id)sender {
    [LinphoneManager.instance fetchVideo];
}

@end
