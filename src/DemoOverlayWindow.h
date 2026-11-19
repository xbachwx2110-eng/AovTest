#import <UIKit/UIKit.h>

@class DemoMenuViewController;

@interface DemoOverlayWindow : UIWindow

@property (nonatomic, strong, readonly) DemoMenuViewController *menuViewController;

+ (instancetype)sharedInstance;
- (void)showOverlay;
- (void)hideOverlay;

@end
