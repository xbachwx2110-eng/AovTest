#import "DemoOverlayWindow.h"
#import "DemoMenuViewController.h"
#import "DemoFloatingButton.h"

@interface DemoOverlayWindow ()
@property (nonatomic, strong) DemoFloatingButton *floatingButton;
@property (nonatomic, strong) DemoMenuViewController *menuViewController;
@end

@implementation DemoOverlayWindow

+ (instancetype)sharedInstance {
    static DemoOverlayWindow *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIWindowScene *scene = nil;
        if (@available(iOS 13.0, *)) {
            for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
                if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
                    scene = (UIWindowScene *)s;
                    break;
                }
            }
        }
        if (scene && @available(iOS 13.0, *)) {
            instance = [[DemoOverlayWindow alloc] initWithWindowScene:scene];
        } else {
            instance = [[DemoOverlayWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        }
    });
    return instance;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setupWindowProperties];
    }
    return self;
}

- (instancetype)initWithWindowScene:(UIWindowScene *)windowScene API_AVAILABLE(ios(13.0)) {
    if (self = [super initWithWindowScene:windowScene]) {
        [self setupWindowProperties];
    }
    return self;
}

- (void)setupWindowProperties {
    self.windowLevel = UIWindowLevelAlert + 100.0;
    self.backgroundColor = [UIColor clearColor];
    self.userInteractionEnabled = YES;
    
    _menuViewController = [[DemoMenuViewController alloc] init];
    self.rootViewController = _menuViewController;
    
    _floatingButton = [[DemoFloatingButton alloc] initWithFrame:CGRectMake(20, 100, 50, 50)];
    __weak typeof(self) weakSelf = self;
    _floatingButton.onTap = ^{
        [weakSelf.menuViewController toggleMenuVisibility];
    };
    [self addSubview:_floatingButton];
}

- (void)showOverlay {
    self.hidden = NO;
    [self makeKeyAndVisible];
}

- (void)hideOverlay {
    self.hidden = YES;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView == self || hitView == self.rootViewController.view) {
        return nil; // Transparent touch passthrough to underlying host views
    }
    return hitView;
}

@end
