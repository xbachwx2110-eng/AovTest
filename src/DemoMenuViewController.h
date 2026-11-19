#import <UIKit/UIKit.h>

extern NSString * const kLobbyLoggerNotification;

@interface DemoMenuViewController : UIViewController <UIDocumentInteractionControllerDelegate>

@property (nonatomic, strong, readonly) UIView *menuContainer;

- (void)toggleMenuVisibility;
- (void)showMenu;
- (void)hideMenu;
- (void)appendLogMessage:(NSString *)msg isLobby:(BOOL)isLobby endpoint:(NSString *)endpoint;

@end
