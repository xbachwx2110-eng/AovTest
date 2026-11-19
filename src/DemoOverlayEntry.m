#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "DemoOverlayWindow.h"

/**
 * Dylib Constructor: Tự động khởi tạo và hiển thị Overlay UI khi vào game.
 * Đảm bảo tương thích 100% với chu kỳ khởi động của Unity trên iOS 13+.
 */
static void __attribute__((constructor)) DemoOverlayInit(void) {
    // 1. Lắng nghe thông báo ứng dụng đã hoạt động (Foreground)
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        [[DemoOverlayWindow sharedInstance] showOverlay];
    }];
    
    // 2. Thử gắn overlay liên tục trong 12 giây đầu khởi động để bắt đúng lúc Unity tạo xong Window
    dispatch_async(dispatch_get_main_queue(), ^{
        static int retryCount = 0;
        NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.5 repeats:YES block:^(NSTimer * _Nonnull t) {
            retryCount++;
            [[DemoOverlayWindow sharedInstance] showOverlay];
            if (retryCount >= 8) {
                [t invalidate];
            }
        }];
    });
}
