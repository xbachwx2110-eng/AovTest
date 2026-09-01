#import "DemoFloatingButton.h"

@interface DemoFloatingButton ()
@property (nonatomic, assign) CGPoint dragStartPoint;
@property (nonatomic, assign) CGPoint buttonStartCenter;
@end

@implementation DemoFloatingButton

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor colorWithRed:0.12 green:0.53 blue:0.90 alpha:0.90];
        [self setTitle:@"UI" forState:UIControlStateNormal];
        self.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        [self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.layer.cornerRadius = frame.size.width / 2.0;
        self.layer.masksToBounds = NO;
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOpacity = 0.4;
        self.layer.shadowRadius = 4.0;
        self.layer.shadowOffset = CGSizeMake(0, 2);
        self.layer.borderWidth = 1.5;
        self.layer.borderColor = [UIColor whiteColor].CGColor;
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:pan];
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        [self addGestureRecognizer:tap];
    }
    return self;
}

- (void)handleTap:(UITapGestureRecognizer *)gesture {
    if (self.onTap) {
        self.onTap();
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    UIView *parent = self.superview;
    if (!parent) return;
    
    CGPoint translation = [pan translationInView:parent];
    if (pan.state == UIGestureRecognizerStateBegan) {
        _buttonStartCenter = self.center;
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        self.center = CGPointMake(_buttonStartCenter.x + translation.x, _buttonStartCenter.y + translation.y);
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        CGRect bounds = parent.bounds;
        CGFloat midX = CGRectGetMidX(bounds);
        CGFloat targetX = (self.center.x < midX) ? (self.frame.size.width / 2.0 + 10) : (bounds.size.width - self.frame.size.width / 2.0 - 10);
        CGFloat targetY = MIN(MAX(self.center.y, 60.0), bounds.size.height - 60.0);
        
        [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.center = CGPointMake(targetX, targetY);
        } completion:nil];
    }
}

@end
