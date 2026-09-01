#ifndef DEMO_OVERLAY_UI_H
#define DEMO_OVERLAY_UI_H

#import <UIKit/UIKit.h>

FOUNDATION_EXPORT double DemoOverlayUIVersionNumber;
FOUNDATION_EXPORT const unsigned char DemoOverlayUIVersionString[];

/**
 * Public notification posted when the demo camera zoom slider changes.
 * UserInfo contains @{"zoomFactor": @(float_val)}
 */
FOUNDATION_EXPORT NSString * const kDemoOverlayCameraZoomDidChangeNotification;

#endif /* DEMO_OVERLAY_UI_H */
