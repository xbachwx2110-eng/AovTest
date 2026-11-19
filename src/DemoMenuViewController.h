#import <UIKit/UIKit.h>

extern NSString * const kLobbyLoggerNotification;

@interface DemoMenuViewController : UIViewController

- (void)toggleMenuVisibility;
- (void)showMenu;
- (void)hideMenu;
- (void)appendLogMessage:(NSString *)msg isLobby:(BOOL)isLobby endpoint:(NSString *)endpoint;

@end
