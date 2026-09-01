#import "DemoMenuViewController.h"
#import "DemoMockMapView.h"

NSString * const kDemoOverlayCameraZoomDidChangeNotification = @"kDemoOverlayCameraZoomDidChangeNotification";

@interface DemoMenuViewController ()

@property (nonatomic, strong) UIView *menuContainer;
@property (nonatomic, strong) UISegmentedControl *tabSelector;
@property (nonatomic, strong) UIView *mapContentView;
@property (nonatomic, strong) UIView *cameraContentView;
@property (nonatomic, strong) UIView *settingsContentView;

@property (nonatomic, strong) DemoMockMapView *mockMapView;
@property (nonatomic, strong) UIButton *refreshMapBtn;

@property (nonatomic, strong) UISlider *zoomSlider;
@property (nonatomic, strong) UILabel *zoomValueLabel;
@property (nonatomic, strong) UIButton *resetZoomBtn;

@property (nonatomic, assign) CGPoint panelStartCenter;

@end

@implementation DemoMenuViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    [self setupMenuContainer];
    [self setupTabs];
    [self setupMapContentView];
    [self setupCameraContentView];
    [self setupSettingsContentView];
    
    [self switchTab:0];
    self.menuContainer.hidden = YES;
}

- (void)setupMenuContainer {
    CGFloat panelWidth = 320.0;
    CGFloat panelHeight = 380.0;
    
    _menuContainer = [[UIView alloc] initWithFrame:CGRectMake(40, 100, panelWidth, panelHeight)];
    _menuContainer.backgroundColor = [UIColor colorWithRed:0.10 green:0.12 blue:0.16 alpha:0.96];
    _menuContainer.layer.cornerRadius = 12.0;
    _menuContainer.layer.masksToBounds = YES;
    _menuContainer.layer.borderWidth = 1.0;
    _menuContainer.layer.borderColor = [UIColor colorWithWhite:0.3 alpha:0.6].CGColor;
    
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, panelWidth, 40)];
    header.backgroundColor = [UIColor colorWithRed:0.14 green:0.18 blue:0.24 alpha:1.0];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, 200, 24)];
    titleLabel.text = @"Demo Overlay Controller";
    titleLabel.font = [UIFont boldSystemFontOfSize:14];
    titleLabel.textColor = [UIColor whiteColor];
    [header addSubview:titleLabel];
    
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeBtn.frame = CGRectMake(panelWidth - 36, 6, 28, 28);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor colorWithWhite:0.7 alpha:1.0] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    [closeBtn addTarget:self action:@selector(hideMenu) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeBtn];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanelPan:)];
    [header addGestureRecognizer:pan];
    
    [_menuContainer addSubview:header];
    [self.view addSubview:_menuContainer];
}

- (void)setupTabs {
    _tabSelector = [[UISegmentedControl alloc] initWithItems:@[@"Map View", @"Camera", @"Settings"]];
    _tabSelector.frame = CGRectMake(12, 48, _menuContainer.frame.size.width - 24, 30);
    _tabSelector.selectedSegmentIndex = 0;
    [_tabSelector addTarget:self action:@selector(tabChanged:) forControlEvents:UIControlEventValueChanged];
    
    if (@available(iOS 13.0, *)) {
        _tabSelector.selectedSegmentTintColor = [UIColor colorWithRed:0.18 green:0.55 blue:0.92 alpha:1.0];
        [_tabSelector setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]} forState:UIControlStateSelected];
        [_tabSelector setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor colorWithWhite:0.8 alpha:1.0]} forState:UIControlStateNormal];
    }
    [_menuContainer addSubview:_tabSelector];
}

- (void)setupMapContentView {
    _mapContentView = [[UIView alloc] initWithFrame:CGRectMake(12, 88, _menuContainer.frame.size.width - 24, 280)];
    
    _mockMapView = [[DemoMockMapView alloc] initWithFrame:CGRectMake(0, 0, _mapContentView.frame.size.width, 230)];
    [_mapContentView addSubview:_mockMapView];
    
    _refreshMapBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _refreshMapBtn.frame = CGRectMake(0, 240, _mapContentView.frame.size.width, 32);
    [_refreshMapBtn setTitle:@"🔄 Refresh Mock Markers" forState:UIControlStateNormal];
    _refreshMapBtn.backgroundColor = [UIColor colorWithRed:0.18 green:0.22 blue:0.30 alpha:1.0];
    _refreshMapBtn.layer.cornerRadius = 6.0;
    [_refreshMapBtn setTitleColor:[UIColor colorWithRed:0.3 green:0.7 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    _refreshMapBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [_refreshMapBtn addTarget:self action:@selector(refreshMapClicked) forControlEvents:UIControlEventTouchUpInside];
    [_mapContentView addSubview:_refreshMapBtn];
    
    [_menuContainer addSubview:_mapContentView];
}

- (void)setupCameraContentView {
    _cameraContentView = [[UIView alloc] initWithFrame:CGRectMake(12, 88, _menuContainer.frame.size.width - 24, 280)];
    _cameraContentView.hidden = YES;
    
    UILabel *camTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, _cameraContentView.frame.size.width, 20)];
    camTitle.text = @"Camera Zoom Scale (1.0x - 10.0x)";
    camTitle.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    camTitle.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
    [_cameraContentView addSubview:camTitle];
    
    _zoomSlider = [[UISlider alloc] initWithFrame:CGRectMake(0, 40, _cameraContentView.frame.size.width, 30)];
    _zoomSlider.minimumValue = 1.0f;
    _zoomSlider.maximumValue = 10.0f;
    _zoomSlider.value = 1.0f;
    _zoomSlider.minimumTrackTintColor = [UIColor colorWithRed:0.18 green:0.55 blue:0.92 alpha:1.0];
    [_zoomSlider addTarget:self action:@selector(zoomSliderChanged:) forControlEvents:UIControlEventValueChanged];
    [_cameraContentView addSubview:_zoomSlider];
    
    _zoomValueLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 80, _cameraContentView.frame.size.width, 26)];
    _zoomValueLabel.text = @"Current Zoom: 1.00x";
    _zoomValueLabel.font = [UIFont boldSystemFontOfSize:16];
    _zoomValueLabel.textColor = [UIColor colorWithRed:0.3 green:0.85 blue:1.0 alpha:1.0];
    _zoomValueLabel.textAlignment = NSTextAlignmentCenter;
    [_cameraContentView addSubview:_zoomValueLabel];
    
    _resetZoomBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _resetZoomBtn.frame = CGRectMake(0, 120, _cameraContentView.frame.size.width, 34);
    [_resetZoomBtn setTitle:@"Reset Zoom (1.0x)" forState:UIControlStateNormal];
    _resetZoomBtn.backgroundColor = [UIColor colorWithRed:0.18 green:0.22 blue:0.30 alpha:1.0];
    _resetZoomBtn.layer.cornerRadius = 6.0;
    [_resetZoomBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _resetZoomBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [_resetZoomBtn addTarget:self action:@selector(resetZoomClicked) forControlEvents:UIControlEventTouchUpInside];
    [_cameraContentView addSubview:_resetZoomBtn];
    
    UILabel *descLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 170, _cameraContentView.frame.size.width, 60)];
    descLabel.text = @"Broadcasts NSNotification 'kDemoOverlayCameraZoomDidChangeNotification' with zoom factor to host application.";
    descLabel.font = [UIFont systemFontOfSize:11];
    descLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    descLabel.numberOfLines = 0;
    descLabel.textAlignment = NSTextAlignmentCenter;
    [_cameraContentView addSubview:descLabel];
    
    [_menuContainer addSubview:_cameraContentView];
}

- (void)setupSettingsContentView {
    _settingsContentView = [[UIView alloc] initWithFrame:CGRectMake(12, 88, _menuContainer.frame.size.width - 24, 280)];
    _settingsContentView.hidden = YES;
    
    UILabel *info = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, _settingsContentView.frame.size.width, 100)];
    info.text = @"Demo Mode Active
• Isolated UIKit Architecture
• 0 Memory modifications
• 0 Hooks or patches
• Safe for App Store & QA";
    info.font = [UIFont systemFontOfSize:12];
    info.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    info.numberOfLines = 0;
    [_settingsContentView addSubview:info];
    
    [_menuContainer addSubview:_settingsContentView];
}

- (void)tabChanged:(UISegmentedControl *)sender {
    [self switchTab:sender.selectedSegmentIndex];
}

- (void)switchTab:(NSInteger)index {
    _mapContentView.hidden = (index != 0);
    _cameraContentView.hidden = (index != 1);
    _settingsContentView.hidden = (index != 2);
}

- (void)refreshMapClicked {
    [_mockMapView refreshMockData];
}

- (void)zoomSliderChanged:(UISlider *)slider {
    _zoomValueLabel.text = [NSString stringWithFormat:@"Current Zoom: %.2fx", slider.value];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kDemoOverlayCameraZoomDidChangeNotification
                                                        object:self
                                                      userInfo:@{@"zoomFactor": @(slider.value)}];
}

- (void)resetZoomClicked {
    _zoomSlider.value = 1.0f;
    [self zoomSliderChanged:_zoomSlider];
}

- (void)handlePanelPan:(UIPanGestureRecognizer *)pan {
    UIView *parent = self.view;
    CGPoint translation = [pan translationInView:parent];
    
    if (pan.state == UIGestureRecognizerStateBegan) {
        _panelStartCenter = _menuContainer.center;
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        _menuContainer.center = CGPointMake(_panelStartCenter.x + translation.x, _panelStartCenter.y + translation.y);
    }
}

- (void)toggleMenuVisibility {
    if (_menuContainer.hidden) {
        [self showMenu];
    } else {
        [self hideMenu];
    }
}

- (void)showMenu {
    _menuContainer.hidden = NO;
    _menuContainer.alpha = 0.0;
    _menuContainer.transform = CGAffineTransformMakeScale(0.9, 0.9);
    [UIView animateWithDuration:0.25 animations:^{
        self.menuContainer.alpha = 1.0;
        self.menuContainer.transform = CGAffineTransformIdentity;
    }];
}

- (void)hideMenu {
    [UIView animateWithDuration:0.2 animations:^{
        self.menuContainer.alpha = 0.0;
        self.menuContainer.transform = CGAffineTransformMakeScale(0.9, 0.9);
    } completion:^(BOOL finished) {
        self.menuContainer.hidden = YES;
    }];
}

@end
