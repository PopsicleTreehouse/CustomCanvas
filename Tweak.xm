#import "CustomCanvas.h"

static inline BOOL extensionIsImage(NSString *extension) {
    extension = [extension lowercaseString];
    return !([extension isEqualToString:@"mov"] || [extension isEqualToString:@"mp4"]);
}

static NSString *filenameForURI(NSString *URI, NSString *extension) {
    NSString *canvasType = extensionIsImage(extension) ? @"image" : @"video";
    NSString *filename = [NSString stringWithFormat:@"upload-artist-%@-%@-%@.cnvs.%@", URI, canvasType, URI, extension];
    return filename;
}

static NSString *fakeURLForURI(NSString *URI, NSString *extension) {
    NSString *canvasType = extensionIsImage(extension) ? @"image" : @"video";
    return [NSString stringWithFormat:@"https://canvaz.scdn.co/upload/artist/%@/%@/%@.cnvs.%@", URI, canvasType, URI, extension];
}


static NSString *URIForURL(NSURL *URL) {
    NSString *spoofedURL = [URL absoluteString];
    NSString *const prefix = @"https://canvaz.scdn.co/upload/artist/";
    if(![spoofedURL hasPrefix:prefix]) return nil;
    if(![spoofedURL containsString:@"spotify:track:"]) return nil;
    NSInteger const startIdx = [prefix length];
    NSInteger const length = 36;
    NSRange const range = NSMakeRange(startIdx, length);
    NSString *URI = [spoofedURL substringWithRange:range];
    return URI;
}

static NSURL *pathForURL(NSURL *URL) {
    NSString *URI = URIForURL(URL);
    if(!URI) return nil;
    NSString *extension = [URL pathExtension];
    NSString *libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *filename = filenameForURI(URI, extension);
    NSString *filePath = [NSString stringWithFormat:@"%@/Caches/Canvases/%@", libraryPath, filename];
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    return fileURL;
}

static NSURL *pathForURI(NSString *URI, NSString *extension, BOOL sandboxed) {
    if(!URI || !extension) return nil;
    SBApplication *application = [[NSClassFromString(@"SBApplicationController") sharedInstance] applicationWithBundleIdentifier:@"com.spotify.client"];
    NSString *filename = filenameForURI(URI, extension);
    NSString *location = [NSString stringWithFormat:@"/Library/Caches/Canvases/%@", filename];
    NSURL *completeURL = [[application.info dataContainerURL] URLByAppendingPathComponent:location];
    return completeURL;
}

static void notificationCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:@"/User/Library/Preferences/com.popsicletreehouse.customcanvasprefs.plist"];
    NSDictionary *dict = (__bridge NSDictionary *)userInfo;
    NSString *URI = dict[@"specifier"];
    NSString *originalPath = settings[URI];
    if(![[NSFileManager defaultManager] fileExistsAtPath:originalPath]) return;
    NSURL *originalPathURL = [NSURL fileURLWithPath:originalPath];
    NSURL *path = pathForURI(URI, [originalPath pathExtension], NO);
    NSError *error;
    if([[NSFileManager defaultManager] fileExistsAtPath:[path path]]) {
        [[NSFileManager defaultManager]
                replaceItemAtURL:path
                withItemAtURL:originalPathURL
                backupItemName:nil
                options:NSFileManagerItemReplacementUsingNewMetadataOnly
                resultingItemURL:nil
                error:&error];
    }
    else {
        [[NSFileManager defaultManager] copyItemAtURL:originalPathURL toURL:path error:&error];
    }
}


static void refreshPrefs() {
    enabledSongs = [NSDictionary dictionaryWithContentsOfFile:@"/User/Library/Preferences/com.popsicletreehouse.customcanvasprefs.plist"];
}


%hook SPTPlayerTrack
- (NSDictionary *)metadata {
    NSString *URI = [self.URI absoluteString];
    NSString *originalPath = [enabledSongs objectForKey:URI];
    if(originalPath) {
        NSMutableDictionary *dict = [%orig mutableCopy];
        NSString *extension = [originalPath pathExtension];
        NSString *fakeURL = fakeURLForURI(URI, extension);
        NSString *canvasType = extensionIsImage(extension) ? @"IMAGE" : @"VIDEO_LOOPING_RANDOM";
        [dict setObject:fakeURL forKey:@"canvas.url"];
        [dict setObject:canvasType forKey:@"canvas.type"];
        [dict setObject:@"" forKey:@"canvas.id"];
        [dict setObject:@"" forKey:@"canvas.explicit"];
        [dict setObject:@"" forKey:@"canvas.artist.name"];
        [dict setObject:@"artist" forKey:@"canvas.uploadedBy"];
        [dict setObject:@"spotify:track:" forKey:@"canvas.entityUri"];
        [dict setObject:@"spotify:canvas:" forKey:@"canvas.canvasUri"];
        [dict setObject:@"spotify:artist:" forKey:@"canvas.artist.uri"];
        [dict setObject:@"https://www.youtube.com/watch?v=dQw4w9WgXcQ" forKey:@"canvas.artist.avatar"];
        return dict;
    }
    return %orig;
}
%end

%hook NSURLSession
- (NSURLSessionDownloadTask *)downloadTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSURL *location, NSURLResponse *response, NSError *error))completionHandler {
    void (^block)(NSURL *location, NSURLResponse *response, NSError *error) = ^void(NSURL *location, NSURLResponse *response, NSError *error) {
        NSURL *filePath = pathForURL(response.URL);
        if(!filePath) {
            completionHandler(location, response, error);
            return;
        }
        if(location) {
            [[NSFileManager defaultManager] 
                replaceItemAtURL:location
                withItemAtURL:filePath
                backupItemName:nil
                options:NSFileManagerItemReplacementUsingNewMetadataOnly
                resultingItemURL:nil
                error:nil];
        }
        NSHTTPURLResponse *fakeResponse = [[NSHTTPURLResponse alloc] initWithURL:response.URL statusCode:200 HTTPVersion:nil headerFields:nil];
        completionHandler(location, fakeResponse, nil);
    };
    return %orig(url, block);
}
%end

%ctor {
    refreshPrefs();
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if([bundleID isEqualToString:@"com.apple.springboard"]) CFNotificationCenterAddObserver(CFNotificationCenterGetDistributedCenter(), NULL, (CFNotificationCallback) notificationCallback, CFSTR("com.popsicletreehouse.customcanvas.prefschanged"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    if([bundleID isEqualToString:@"com.spotify.client"]) CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback) refreshPrefs, CFSTR("com.popsicletreehouse.customcanvas.prefschanged"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}