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
        instance = [[DemoOverlayWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    });
    return instance;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setupWindowProperties];
    }
    return self;
}

- (void)setupWindowProperties {
    self.windowLevel = UIWindowLevelAlert + 999.0;
    self.backgroundColor = [UIColor clearColor];
    self.userInteractionEnabled = YES;
    
    _menuViewController = [[DemoMenuViewController alloc] init];
    self.rootViewController = _menuViewController;
    
    // Nút nổi ban đầu đặt ở góc trái trên, kích thước 46x46
    _floatingButton = [[DemoFloatingButton alloc] initWithFrame:CGRectMake(24, 70, 46, 46)];
    __weak typeof(self) weakSelf = self;
    _floatingButton.onTap = ^{
        [weakSelf.menuViewController toggleMenuVisibility];
    };
    [self addSubview:_floatingButton];
}

- (void)attachWindowSceneIfAvailable {
    if (@available(iOS 13.0, *)) {
        if (!self.windowScene) {
            UIWindowScene *foundScene = nil;
            for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    UIWindowScene *ws = (UIWindowScene *)scene;
                    if (ws.activationState == UISceneActivationStateForegroundActive) {
                        foundScene = ws;
                        break;
                    }
                    if (!foundScene) {
                        foundScene = ws;
                    }
                }
            }
            if (foundScene) {
                self.windowScene = foundScene;
            }
        }
    }
}

- (void)showOverlay {
    [self attachWindowSceneIfAvailable];
    self.frame = [UIScreen mainScreen].bounds;
    self.hidden = NO;
    self.alpha = 1.0;
    
    if (self.rootViewController) {
        self.rootViewController.view.frame = self.bounds;
        [self.rootViewController.view layoutIfNeeded];
    }
    
    [self bringSubviewToFront:_floatingButton];
    _floatingButton.hidden = NO;
    _floatingButton.alpha = 1.0;
}

- (void)hideOverlay {
    self.hidden = YES;
}

// -----------------------------------------------------------------------------
// hitTest chuẩn xác 100%: Chỉ bắt chạm nếu trúng nút [LOG] hoặc Menu Container
// Khoảng trống ngoài menu sẽ passthrough thẳng xuống game Liên Quân!
// -----------------------------------------------------------------------------
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || self.alpha <= 0.01 || !self.userInteractionEnabled) {
        return nil;
    }
    
    // 1. Kiểm tra nếu chạm vào Nút nổi [LOG]
    if (_floatingButton && !_floatingButton.hidden && _floatingButton.alpha > 0.01) {
        CGPoint ptInBtn = [_floatingButton convertPoint:point fromView:self];
        if ([_floatingButton pointInside:ptInBtn withEvent:event]) {
            return [_floatingButton hitTest:ptInBtn withEvent:event];
        }
    }
    
    // 2. Kiểm tra nếu chạm vào Bảng Menu Log (khi đang mở)
    UIView *menu = _menuViewController.menuContainer;
    if (menu && !menu.hidden && menu.alpha > 0.01) {
        CGPoint ptInMenu = [menu convertPoint:point fromView:self];
        if ([menu pointInside:ptInMenu withEvent:event]) {
            return [menu hitTest:ptInMenu withEvent:event];
        }
    }
    
    // 3. Toàn bộ khu vực khác: trả về nil để Unity nhận cảm ứng mượt mà
    return nil;
}

@end
