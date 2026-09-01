#import <UIKit/UIKit.h>

@interface DemoOverlayWindow : UIWindow

+ (instancetype)sharedInstance;
- (void)showOverlay;
- (void)hideOverlay;

@end
