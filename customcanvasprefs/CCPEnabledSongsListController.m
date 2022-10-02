#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "CCPEnabledSongsListController.h"

@implementation CCPEnabledSongsListController

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *path = [NSString stringWithFormat:@"/User/Library/Preferences/%@.plist", specifier.properties[PSDefaultsKey]];
	NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:path];
	return (settings[specifier.properties[PSKeyNameKey]]) ?: specifier.properties[PSDefaultValueKey];
}

- (void)copyCanvasFromURL:(NSURL *)from forURI:(NSString *)URI {
    if(![URI containsString:@"spotify:track:"]) return;
    if([URI length] != 36) return;
    // SBApplication *application = [[NSClassFromString(@"SBApplicationController") sharedInstance] applicationWithBundleIdentifier:@"com.spotify.client"];
    // NSURL *containerURL = [application.info dataContainerURL];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *path = [NSString stringWithFormat:@"/User/Library/Preferences/%@.plist", specifier.properties[PSDefaultsKey]];
	NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithContentsOfFile:path];
    NSString *URI = specifier.properties[PSKeyNameKey];
	[settings setObject:value forKey:URI];
	[settings writeToFile:path atomically:YES];
    [self copyCanvasFromURL:[NSURL fileURLWithPath:value] forURI:URI];
	CFStringRef notificationName = (__bridge CFStringRef)specifier.properties[PSValueChangedNotificationKey];
	if (notificationName) {
        NSDictionary *userInfo = @{@"specifier": URI};
        CFNotificationCenterPostNotification(CFNotificationCenterGetDistributedCenter(), notificationName, NULL, (__bridge CFDictionaryRef)userInfo, YES);
    }
}

- (void)removeSpecifierFromSettings:(PSSpecifier *)specifier {
    NSString *path = [NSString stringWithFormat:@"/User/Library/Preferences/%@.plist", specifier.properties[PSDefaultsKey]];
	NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithContentsOfFile:path];
    NSString *URI = specifier.properties[PSKeyNameKey];
    [settings removeObjectForKey:URI];
    [settings writeToFile:path atomically:YES];
    CFStringRef notificationName = (__bridge CFStringRef)specifier.properties[PSValueChangedNotificationKey];
    if (notificationName) {
        NSDictionary *userInfo = @{@"specifier": URI};
        CFNotificationCenterPostNotification(CFNotificationCenterGetDistributedCenter(), notificationName, NULL, (__bridge CFDictionaryRef)userInfo, YES);
    }
}

- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    gesture.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:gesture];
    self.table.allowsMultipleSelectionDuringEditing = NO;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.row != 0;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSInteger index = indexPath.row + 1;
        [self removeSpecifierFromSettings:_specifiers[index]];
        [self removeSpecifierAtIndex:index animated:YES];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (PSSpecifier *)specifierWithName:(NSString *)name {
    PSSpecifier *specifier = [PSSpecifier 
        preferenceSpecifierNamed:name
        target:self 
        set:@selector(setPreferenceValue:specifier:)
        get:@selector(readPreferenceValue:)
        detail:nil
        cell:PSEditTextCell
        edit:nil];
    [specifier.properties setObject:@"com.popsicletreehouse.customcanvasprefs" forKey:PSDefaultsKey];
    [specifier.properties setObject:@(YES) forKey:PSTextFieldNoAutoCorrectKey];
    [specifier.properties setObject:name forKey:PSKeyNameKey];
    [specifier.properties setObject:@"" forKey:PSDefaultValueKey];
    [specifier.properties setObject:@"com.popsicletreehouse.customcanvas.prefschanged" forKey:PSValueChangedNotificationKey];
    return specifier;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    NSString *path = [NSString stringWithFormat:@"/User/Library/Preferences/com.popsicletreehouse.customcanvasprefs.plist"];
    NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithContentsOfFile:path];
    for(NSString *key in settings) {
        PSSpecifier *specifier = [self specifierWithName:key];
        [self addSpecifier:specifier];
    }
}

- (void)addSong {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Add Song" message:@"Enter the URI of the song you want to add" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * textField) {}];
    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        NSString *text = [[alert textFields][0] text];
        PSSpecifier *specifier = [self specifierWithName:text];
        [self addSpecifier:specifier];
    }];
    [alert addAction:defaultAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSArray *)specifiers {
	if (!_specifiers) _specifiers = [self loadSpecifiersFromPlistName:@"SongsList" target:self];
	return _specifiers;
}

@end
