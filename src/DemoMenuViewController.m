#import "DemoMenuViewController.h"

NSString * const kLobbyLoggerNotification = @"kLobbyLoggerNotification";

@interface DemoMenuViewController ()

@property (nonatomic, strong) UIView *menuContainer;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIView *statusBar;
@property (nonatomic, strong) UILabel *lobbyStatusLabel;
@property (nonatomic, strong) UIButton *btnCopyLobby;
@property (nonatomic, strong) UITextView *logTextView;
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UIButton *exportBtn;
@property (nonatomic, strong) UIButton *btnCopyAll;
@property (nonatomic, strong) UIButton *clearBtn;
@property (nonatomic, strong) UIButton *scrollBottomBtn;

@property (nonatomic, copy) NSString *latestLobbyEndpoint;
@property (nonatomic, assign) CGPoint panelStartCenter;
@property (nonatomic, strong) UILabel *toastLabel;

@end

@implementation DemoMenuViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    
    [self setupMenuContainer];
    self.menuContainer.hidden = YES;
    
    // Đăng ký nhận log real-time từ socket hooks
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleLogNotification:)
                                                 name:kLobbyLoggerNotification
                                               object:nil];
    
    // Nạp log cũ nếu đã có sẵn trong file
    [self loadInitialLogFile];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setupMenuContainer {
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    CGFloat screenW = MAX(screenBounds.size.width, screenBounds.size.height);
    CGFloat screenH = MIN(screenBounds.size.width, screenBounds.size.height);
    
    CGFloat panelW = MIN(screenW - 40.0, 520.0);
    CGFloat panelH = MIN(screenH - 30.0, 310.0);
    CGFloat panelX = (screenW - panelW) / 2.0;
    CGFloat panelY = (screenH - panelH) / 2.0;
    
    _menuContainer = [[UIView alloc] initWithFrame:CGRectMake(panelX, panelY, panelW, panelH)];
    _menuContainer.backgroundColor = [UIColor colorWithRed:0.07 green:0.09 blue:0.13 alpha:0.96];
    _menuContainer.layer.cornerRadius = 10.0;
    _menuContainer.layer.masksToBounds = YES;
    _menuContainer.layer.borderWidth = 1.2;
    _menuContainer.layer.borderColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.4 alpha:0.8].CGColor;
    
    // 1. Header (Có thể kéo di chuyển)
    _headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, panelW, 36)];
    _headerView.backgroundColor = [UIColor colorWithRed:0.11 green:0.15 blue:0.21 alpha:1.0];
    
    _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 6, panelW - 70, 24)];
    _titleLabel.text = @"📡 LOBBY SNIFFER & NETWORK LOG";
    _titleLabel.font = [UIFont boldSystemFontOfSize:13];
    _titleLabel.textColor = [UIColor colorWithRed:0.2 green:1.0 blue:0.5 alpha:1.0];
    [_headerView addSubview:_titleLabel];
    
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeBtn.frame = CGRectMake(panelW - 36, 4, 28, 28);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor colorWithWhite:0.85 alpha:1.0] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    [closeBtn addTarget:self action:@selector(hideMenu) forControlEvents:UIControlEventTouchUpInside];
    [_headerView addSubview:closeBtn];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanelPan:)];
    [_headerView addGestureRecognizer:pan];
    [_menuContainer addSubview:_headerView];
    
    // 2. Status Bar: Hiển thị IP & Port Lobby Server bắt được
    _statusBar = [[UIView alloc] initWithFrame:CGRectMake(0, 36, panelW, 32)];
    _statusBar.backgroundColor = [UIColor colorWithRed:0.09 green:0.12 blue:0.18 alpha:1.0];
    
    _lobbyStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 4, panelW - 110, 24)];
    _lobbyStatusLabel.text = @"⏳ Đang chờ kết nối Lobby Server...";
    _lobbyStatusLabel.font = [UIFont boldSystemFontOfSize:12];
    _lobbyStatusLabel.textColor = [UIColor colorWithRed:1.0 green:0.85 blue:0.3 alpha:1.0];
    [_statusBar addSubview:_lobbyStatusLabel];
    
    _btnCopyLobby = [UIButton buttonWithType:UIButtonTypeSystem];
    _btnCopyLobby.frame = CGRectMake(panelW - 95, 4, 85, 24);
    [_btnCopyLobby setTitle:@"📋 Copy IP" forState:UIControlStateNormal];
    _btnCopyLobby.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    _btnCopyLobby.backgroundColor = [UIColor colorWithRed:0.15 green:0.25 blue:0.35 alpha:1.0];
    _btnCopyLobby.layer.cornerRadius = 4.0;
    [_btnCopyLobby setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_btnCopyLobby addTarget:self action:@selector(copyLobbyEndpoint) forControlEvents:UIControlEventTouchUpInside];
    [_statusBar addSubview:_btnCopyLobby];
    
    [_menuContainer addSubview:_statusBar];
    
    // 3. TextView hiển thị Log console
    CGFloat logH = panelH - 36 - 32 - 40;
    _logTextView = [[UITextView alloc] initWithFrame:CGRectMake(8, 70, panelW - 16, logH)];
    _logTextView.backgroundColor = [UIColor colorWithRed:0.04 green:0.05 blue:0.07 alpha:1.0];
    _logTextView.textColor = [UIColor colorWithRed:0.85 green:0.92 blue:0.95 alpha:1.0];
    if (@available(iOS 13.0, *)) {
        _logTextView.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    } else {
        _logTextView.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
    }
    _logTextView.editable = NO;
    _logTextView.layer.cornerRadius = 6.0;
    _logTextView.layer.borderWidth = 0.8;
    _logTextView.layer.borderColor = [UIColor colorWithWhite:0.2 alpha:0.8].CGColor;
    [_menuContainer addSubview:_logTextView];
    
    // 4. Bottom Action Bar (Các nút chức năng)
    _bottomBar = [[UIView alloc] initWithFrame:CGRectMake(0, panelH - 40, panelW, 40)];
    _bottomBar.backgroundColor = [UIColor colorWithRed:0.10 green:0.13 blue:0.18 alpha:1.0];
    
    CGFloat btnW = (panelW - 32) / 4.0;
    CGFloat btnH = 28.0;
    CGFloat btnY = 6.0;
    
    // Button: Xuất TXT
    _exportBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _exportBtn.frame = CGRectMake(8, btnY, btnW, btnH);
    [_exportBtn setTitle:@"📤 Xuất TXT" forState:UIControlStateNormal];
    _exportBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    _exportBtn.backgroundColor = [UIColor colorWithRed:0.12 green:0.48 blue:0.28 alpha:1.0];
    _exportBtn.layer.cornerRadius = 5.0;
    [_exportBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_exportBtn addTarget:self action:@selector(exportLogAsTxt) forControlEvents:UIControlEventTouchUpInside];
    [_bottomBar addSubview:_exportBtn];
    
    // Button: Sao Chép Toàn Bộ
    _btnCopyAll = [UIButton buttonWithType:UIButtonTypeSystem];
    _btnCopyAll.frame = CGRectMake(8 + btnW + 5, btnY, btnW, btnH);
    [_btnCopyAll setTitle:@"📋 Sao Chép" forState:UIControlStateNormal];
    _btnCopyAll.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    _btnCopyAll.backgroundColor = [UIColor colorWithRed:0.18 green:0.35 blue:0.55 alpha:1.0];
    _btnCopyAll.layer.cornerRadius = 5.0;
    [_btnCopyAll setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_btnCopyAll addTarget:self action:@selector(copyAllLogs) forControlEvents:UIControlEventTouchUpInside];
    [_bottomBar addSubview:_btnCopyAll];
    
    // Button: Xóa Log
    _clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _clearBtn.frame = CGRectMake(8 + (btnW + 5) * 2, btnY, btnW, btnH);
    [_clearBtn setTitle:@"🧹 Xóa Log" forState:UIControlStateNormal];
    _clearBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    _clearBtn.backgroundColor = [UIColor colorWithRed:0.45 green:0.20 blue:0.20 alpha:1.0];
    _clearBtn.layer.cornerRadius = 5.0;
    [_clearBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_clearBtn addTarget:self action:@selector(clearLogs) forControlEvents:UIControlEventTouchUpInside];
    [_bottomBar addSubview:_clearBtn];
    
    // Button: Cuộn Xuống Cuối
    _scrollBottomBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _scrollBottomBtn.frame = CGRectMake(8 + (btnW + 5) * 3, btnY, btnW, btnH);
    [_scrollBottomBtn setTitle:@"⬇ Cuộn Cuối" forState:UIControlStateNormal];
    _scrollBottomBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    _scrollBottomBtn.backgroundColor = [UIColor colorWithRed:0.25 green:0.28 blue:0.35 alpha:1.0];
    _scrollBottomBtn.layer.cornerRadius = 5.0;
    [_scrollBottomBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_scrollBottomBtn addTarget:self action:@selector(scrollToBottom) forControlEvents:UIControlEventTouchUpInside];
    [_bottomBar addSubview:_scrollBottomBtn];
    
    [_menuContainer addSubview:_bottomBar];
    [self.view addSubview:_menuContainer];
}

#pragma mark - Logic Xử Lý & Thao Tác

- (void)loadInitialLogFile {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (paths.count > 0) {
        NSString *docDir = paths[0];
        NSString *logPath = [docDir stringByAppendingPathComponent:@"lobby_traffic.log"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:logPath]) {
            NSString *content = [NSString stringWithContentsOfFile:logPath encoding:NSUTF8StringEncoding error:nil];
            if (content.length > 0) {
                _logTextView.text = content;
                [self scrollToBottom];
            }
        }
    }
}

- (void)handleLogNotification:(NSNotification *)noti {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *ui = noti.userInfo;
        NSString *msg = ui[@"log"];
        BOOL isLobby = [ui[@"is_lobby"] boolValue];
        NSString *endpoint = ui[@"endpoint"];
        
        if (msg) {
            [self appendLogMessage:msg isLobby:isLobby endpoint:endpoint];
        }
    });
}

- (void)appendLogMessage:(NSString *)msg isLobby:(BOOL)isLobby endpoint:(NSString *)endpoint {
    if (isLobby && endpoint.length > 0) {
        _latestLobbyEndpoint = endpoint;
        _lobbyStatusLabel.text = [NSString stringWithFormat:@"🟢 Lobby: %@", endpoint];
        _lobbyStatusLabel.textColor = [UIColor colorWithRed:0.2 green:1.0 blue:0.4 alpha:1.0];
    }
    
    NSString *curr = _logTextView.text ?: @"";
    _logTextView.text = [curr stringByAppendingFormat:@"%@\n", msg];
    [self scrollToBottom];
}

- (void)scrollToBottom {
    if (_logTextView.text.length > 0) {
        NSRange bottom = NSMakeRange(_logTextView.text.length - 1, 1);
        [_logTextView scrollRangeToVisible:bottom];
    }
}

- (void)copyLobbyEndpoint {
    if (_latestLobbyEndpoint.length > 0) {
        [UIPasteboard generalPasteboard].string = _latestLobbyEndpoint;
        [self showToast:[NSString stringWithFormat:@"✓ Đã copy: %@", _latestLobbyEndpoint]];
    } else {
        [self showToast:@"Chưa bắt được IP:Port của Lobby!"];
    }
}

- (void)copyAllLogs {
    NSString *text = _logTextView.text;
    if (text.length > 0) {
        [UIPasteboard generalPasteboard].string = text;
        [self showToast:@"✓ Đã copy toàn bộ nội dung log!"];
    } else {
        [self showToast:@"Log hiện đang trống!"];
    }
}

- (void)clearLogs {
    _logTextView.text = @"";
    [self showToast:@"✓ Đã xóa trắng màn hình log."];
}

- (void)exportLogAsTxt {
    NSString *logText = _logTextView.text;
    if (logText.length == 0) {
        [self showToast:@"Log trống, chưa có dữ liệu để xuất!"];
        return;
    }
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (paths.count == 0) return;
    NSString *docDir = paths[0];
    NSString *filePath = [docDir stringByAppendingPathComponent:@"lobby_log.txt"];
    
    NSError *err = nil;
    [logText writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:&err];
    
    if (err) {
        [self showToast:[NSString stringWithFormat:@"Lỗi lưu file: %@", err.localizedDescription]];
        return;
    }
    
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = _exportBtn;
        activityVC.popoverPresentationController.sourceRect = _exportBtn.bounds;
    }
    
    [self presentViewController:activityVC animated:YES completion:nil];
}

- (void)showToast:(NSString *)msg {
    if (!_toastLabel) {
        _toastLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, 260, 34)];
        _toastLabel.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.9];
        _toastLabel.textColor = [UIColor colorWithRed:0.2 green:1.0 blue:0.5 alpha:1.0];
        _toastLabel.textAlignment = NSTextAlignmentCenter;
        _toastLabel.font = [UIFont boldSystemFontOfSize:12];
        _toastLabel.layer.cornerRadius = 6.0;
        _toastLabel.layer.masksToBounds = YES;
        _toastLabel.layer.borderWidth = 1.0;
        _toastLabel.layer.borderColor = [UIColor greenColor].CGColor;
        [_menuContainer addSubview:_toastLabel];
    }
    _toastLabel.text = msg;
    _toastLabel.center = CGPointMake(_menuContainer.frame.size.width / 2.0, _menuContainer.frame.size.height / 2.0);
    _toastLabel.alpha = 1.0;
    _toastLabel.hidden = NO;
    [_menuContainer bringSubviewToFront:_toastLabel];
    
    [UIView animateWithDuration:0.4 delay:2.0 options:0 animations:^{
        self.toastLabel.alpha = 0.0;
    } completion:^(BOOL finished) {
        self.toastLabel.hidden = YES;
    }];
}

#pragma mark - Menu Visibility & Kéo Di Chuyển

- (void)toggleMenuVisibility {
    if (self.menuContainer.hidden) {
        [self showMenu];
    } else {
        [self hideMenu];
    }
}

- (void)showMenu {
    self.menuContainer.hidden = NO;
    self.menuContainer.alpha = 0.0;
    [UIView animateWithDuration:0.25 animations:^{
        self.menuContainer.alpha = 1.0;
    }];
    [self scrollToBottom];
}

- (void)hideMenu {
    [UIView animateWithDuration:0.2 animations:^{
        self.menuContainer.alpha = 0.0;
    } completion:^(BOOL finished) {
        self.menuContainer.hidden = YES;
    }];
}

- (void)handlePanelPan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.view];
    if (pan.state == UIGestureRecognizerStateBegan) {
        _panelStartCenter = self.menuContainer.center;
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        self.menuContainer.center = CGPointMake(_panelStartCenter.x + translation.x, _panelStartCenter.y + translation.y);
    }
}

@end
