#import <UIKit/UIKit.h>

@interface DemoFloatingButton : UIButton

@property (nonatomic, copy) void (^onTap)(void);

@end
