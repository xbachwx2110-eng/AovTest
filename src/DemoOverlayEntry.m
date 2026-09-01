#import <Foundation/Foundation.h>
#import "DemoOverlayWindow.h"

/**
 * Dylib Constructor: Automatically initializes the DemoOverlayWindow
 * when the library is loaded into the host iOS process.
 */
static void __attribute__((constructor)) DemoOverlayInit(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[DemoOverlayWindow sharedInstance] showOverlay];
        NSLog(@"[DemoOverlayUI] Initialized and attached to active UIWindowScene.");
    });
}
