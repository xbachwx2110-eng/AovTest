#import <UIKit/UIKit.h>

@interface DemoMockMarker : NSObject
@property (nonatomic, assign) CGPoint normalizedPosition; // (0.0 - 1.0, 0.0 - 1.0)
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) CGFloat hpPercentage;       // 0.0 - 1.0
@property (nonatomic, strong) UIColor *markerColor;
@property (nonatomic, assign) BOOL isTarget;
@end

@interface DemoMockMapView : UIView

@property (nonatomic, strong) NSArray<DemoMockMarker *> *mockMarkers;
- (void)refreshMockData;

@end
