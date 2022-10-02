@interface SBApplicationInfo
- (id)dataContainerURL;
@end

@interface SBApplication
@property (nonatomic, strong) SBApplicationInfo *info;
@end

@interface SBApplicationController
+ (SBApplicationController *)sharedInstance;
- (SBApplication *)applicationWithBundleIdentifier:(NSString *)arg1;
@end

@interface SPTPlayerTrack : NSObject
@property(copy, nonatomic) NSURL *URI;
@end

extern "C" CFNotificationCenterRef CFNotificationCenterGetDistributedCenter(void);
static NSDictionary *enabledSongs;
