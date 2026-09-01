#import "DemoMockMapView.h"

@implementation DemoMockMarker
@end

@interface DemoMockMapView ()
@property (nonatomic, strong) NSTimer *animationTimer;
@end

@implementation DemoMockMapView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor colorWithRed:0.08 green:0.10 blue:0.14 alpha:0.95];
        self.layer.cornerRadius = 8.0;
        self.layer.masksToBounds = YES;
        self.layer.borderWidth = 1.0;
        self.layer.borderColor = [UIColor colorWithWhite:0.3 alpha:0.8].CGColor;
        [self generateInitialMockMarkers];
        
        _animationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(simulateEntityMovement) userInfo:nil repeats:YES];
    }
    return self;
}

- (void)dealloc {
    [_animationTimer invalidate];
}

- (void)generateInitialMockMarkers {
    NSMutableArray *markers = [NSMutableArray array];
    
    NSArray *names = @[@"Entity-Alpha", @"Entity-Bravo", @"Target-Omega", @"Zone-Beacon", @"Support-Delta"];
    NSArray *colors = @[
        [UIColor colorWithRed:0.2 green:0.8 blue:0.2 alpha:1.0], // Friendly
        [UIColor colorWithRed:0.9 green:0.2 blue:0.2 alpha:1.0], // Enemy
        [UIColor colorWithRed:1.0 green:0.8 blue:0.0 alpha:1.0], // Objective
        [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:1.0], // Neutral
        [UIColor colorWithRed:0.8 green:0.3 blue:0.9 alpha:1.0]  // Special
    ];
    
    for (NSInteger i = 0; i < names.count; i++) {
        DemoMockMarker *m = [[DemoMockMarker alloc] init];
        m.name = names[i];
        m.normalizedPosition = CGPointMake(0.2 + 0.15 * i, 0.25 + 0.12 * (i % 3));
        m.hpPercentage = 0.4 + 0.12 * (i + 1);
        m.markerColor = colors[i];
        m.isTarget = (i == 2);
        [markers addObject:m];
    }
    _mockMarkers = [markers copy];
}

- (void)simulateEntityMovement {
    for (DemoMockMarker *m in _mockMarkers) {
        CGFloat dx = ((arc4random_uniform(20) - 10) / 500.0);
        CGFloat dy = ((arc4random_uniform(20) - 10) / 500.0);
        CGFloat newX = MIN(MAX(m.normalizedPosition.x + dx, 0.05), 0.95);
        CGFloat newY = MIN(MAX(m.normalizedPosition.y + dy, 0.05), 0.95);
        m.normalizedPosition = CGPointMake(newX, newY);
    }
    [self setNeedsDisplay];
}

- (void)refreshMockData {
    [self generateInitialMockMarkers];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;
    
    // 1. Draw Grid Lines
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:0.2 alpha:0.5].CGColor);
    CGContextSetLineWidth(ctx, 1.0);
    
    NSInteger gridDivisions = 6;
    for (NSInteger i = 1; i < gridDivisions; i++) {
        CGFloat x = (rect.size.width / gridDivisions) * i;
        CGContextMoveToPoint(ctx, x, 0);
        CGContextAddLineToPoint(ctx, x, rect.size.height);
        
        CGFloat y = (rect.size.height / gridDivisions) * i;
        CGContextMoveToPoint(ctx, 0, y);
        CGContextAddLineToPoint(ctx, rect.size.width, y);
    }
    CGContextStrokePath(ctx);
    
    // 2. Draw Center / Player Origin
    CGPoint center = CGPointMake(rect.size.width / 2.0, rect.size.height / 2.0);
    CGContextSetFillColorWithColor(ctx, [UIColor colorWithRed:0.0 green:1.0 blue:0.8 alpha:0.8].CGColor);
    CGContextFillEllipseInRect(ctx, CGRectMake(center.x - 4, center.y - 4, 8, 8));
    
    // 3. Draw Mock Markers & Health Bars
    NSDictionary *textAttr = @{
        NSFontAttributeName: [UIFont systemFontOfSize:9 weight:UIFontWeightMedium],
        NSForegroundColorAttributeName: [UIColor whiteColor]
    };
    
    for (DemoMockMarker *marker in _mockMarkers) {
        CGFloat px = marker.normalizedPosition.x * rect.size.width;
        CGFloat py = marker.normalizedPosition.y * rect.size.height;
        
        CGContextSetFillColorWithColor(ctx, marker.markerColor.CGColor);
        CGContextFillEllipseInRect(ctx, CGRectMake(px - 5, py - 5, 10, 10));
        
        if (marker.isTarget) {
            CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:1.0 green:0.8 blue:0.0 alpha:0.7].CGColor);
            CGContextSetLineWidth(ctx, 1.0);
            CGContextMoveToPoint(ctx, center.x, center.y);
            CGContextAddLineToPoint(ctx, px, py);
            CGContextStrokePath(ctx);
        }
        
        CGFloat barWidth = 24.0;
        CGFloat barHeight = 3.0;
        CGRect hpBg = CGRectMake(px - barWidth / 2.0, py - 10, barWidth, barHeight);
        CGRect hpFg = CGRectMake(px - barWidth / 2.0, py - 10, barWidth * marker.hpPercentage, barHeight);
        
        CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.2 alpha:0.8].CGColor);
        CGContextFillRect(ctx, hpBg);
        
        CGContextSetFillColorWithColor(ctx, [UIColor colorWithRed:0.2 green:0.85 blue:0.3 alpha:1.0].CGColor);
        CGContextFillRect(ctx, hpFg);
        
        CGSize textSize = [marker.name sizeWithAttributes:textAttr];
        [marker.name drawAtPoint:CGPointMake(px - textSize.width / 2.0, py + 6) withAttributes:textAttr];
    }
}

@end
