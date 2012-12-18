//
//  AppDelegate.m
//  browser-selector
//
//  Created by Ankit Solanki on 01/11/12.
//  Copyright (c) 2012 nth loop. All rights reserved.
//

#import "Constants.h"
#import "AppDelegate.h"
#import "PrefsController.h"
#import "HotkeyManager.h"
#import "NSWorkspace+Utils.h"
#import "ImageUtils.h"
#import "BrowsersMenu.h"
#import <ZeroKit/ZeroKitUtilities.h>

@interface AppDelegate()
{
    @private
    NSStatusItem *statusBarIcon;
    BrowsersMenu *browserMenu;
    NSUserDefaults *defaults;
    NSWorkspace *sharedWorkspace;
    HotkeyManager *hotkeyManager;
    NSArray *blacklist;
}
@end

@implementation AppDelegate

{} // TODO Figure out why the first pragma mark requires this empty block to show up

#pragma mark - NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSLog(@"applicationDidFinishLaunching");

    self.prefsController = [[PrefsController alloc] initWithWindowNibName:@"PrefsController"];
    sharedWorkspace = [NSWorkspace sharedWorkspace];
    blacklist = [[NSArray alloc] initWithContentsOfFile:[[NSBundle mainBundle]
                                                         pathForResource:@"Blacklist"
                                                         ofType:@"plist"]];

    browserMenu = [[BrowsersMenu alloc] init];

    hotkeyManager = [HotkeyManager sharedInstance];

    NSLog(@"Setting defaults");
    [ZeroKitUtilities registerDefaultsForBundle:[NSBundle mainBundle]];
    defaults = [NSUserDefaults standardUserDefaults];

    [defaults addObserver:self
               forKeyPath:PrefAutoHideIcon
                  options:NSKeyValueObservingOptionNew
                  context:NULL];
    [defaults addObserver:self
               forKeyPath:PrefStartAtLogin
                  options:NSKeyValueObservingOptionNew
                  context:NULL];

    if ([defaults boolForKey:PrefAutoHideIcon]) [hotkeyManager registerStoredHotkey];
    [self showAndHideIcon:nil];

    NSLog(@"Initial debug data");
    NSArray *browsers = [sharedWorkspace installedBrowserIdentifiers];
    NSLog(@"Browser: %@", browsers);
    NSLog(@"Default browser: %@", [sharedWorkspace defaultBrowserIdentifier]);

    NSLog(@"applicationDidFinishLaunching :: finish");
}

- (BOOL)applicationShouldHandleReopen: (NSApplication *)application hasVisibleWindows: (BOOL)visibleWindows
{
    [self showAndHideIcon:nil];
    return YES;
}


#pragma mark - NSKeyValueObserving

-(void)observeValueForKeyPath:(NSString *)keyPath
                     ofObject:(id)object
                       change:(NSDictionary *)change
                      context:(void *)context
{

    if ([keyPath isEqualToString:PrefAutoHideIcon])
    {
        if ([change valueForKey:@"new"])
        {
            [hotkeyManager registerStoredHotkey];
        } else
        {
            [hotkeyManager clearHotkey];
        }

        [self showAndHideIcon:nil];
    }
    else if ([keyPath isEqualToString:PrefStartAtLogin])
    {
        [self toggleLoginItem];
    }
}

#pragma mark - "Business" Logic

- (void) selectABrowser:sender
{
    NSString *newDefaultBrowser = [sender representedObject];
    NSMenuItem *menuItem = sender;
    NSMenu *menu = menuItem.menu;

    [menu.itemArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [obj setState:NSOffState];
    }];
    menuItem.state = NSOnState;

    NSLog(@"Selecting a browser: %@", newDefaultBrowser);
    [sharedWorkspace setDefaultBrowserWithIdentifier:newDefaultBrowser];
    statusBarIcon.image = [ImageUtils statusBarIconForAppId:newDefaultBrowser];

    [self showNotification:newDefaultBrowser];
}

- (void) toggleLoginItem
{
    if ([defaults boolForKey:PrefStartAtLogin])
    {
        [ZeroKitUtilities enableLoginItemForBundle:[NSBundle mainBundle]];
    }
    else
    {
        [ZeroKitUtilities disableLoginItemForBundle:[NSBundle mainBundle]];
    }
}

- (BOOL) isBlacklisted:(NSString*) browserIdentifier
{
    if (!blacklist.count || !browserIdentifier) return NO;

    NSInteger index = [blacklist indexOfObjectPassingTest:^BOOL(id blacklistedIdentifier, NSUInteger idx, BOOL *stop) {
        NSRange range = [browserIdentifier rangeOfString:blacklistedIdentifier];
        return range.location != NSNotFound;
    }];

    return  index != NSNotFound;
}

#pragma mark - UI

- (void) hotkeyTriggered
{
    NSLog(@"@Hotkey triggered");
    [self showAndHideIcon:nil];
}

- (void) createStatusBarIcon
{
    NSLog(@"createStatusBarIcon");
    if (statusBarIcon != nil) return;
    NSStatusBar *statusBar = [NSStatusBar systemStatusBar];
    NSString *defaultBrowser = [sharedWorkspace defaultBrowserIdentifier];

    statusBarIcon = [statusBar statusItemWithLength:NSVariableStatusItemLength];
    statusBarIcon.toolTip = AppDescription;
    statusBarIcon.image = [ImageUtils statusBarIconForAppId:defaultBrowser];

    statusBarIcon.menu = browserMenu;
}

- (void) destroyStatusBarIcon
{
    NSLog(@"destroyStatusBarIcon");
    if (![defaults boolForKey:PrefAutoHideIcon])
    {
        return;
    }
    if (browserMenu.menuIsOpen)
    {
        [self performSelector:@selector(destroyStatusBarIcon) withObject:nil afterDelay:10];
    }
    else
    {
        [[statusBarIcon statusBar] removeStatusItem:statusBarIcon];
        statusBarIcon = nil;
    }
}

- (void) showAndHideIcon:(NSEvent*)hotKeyEvent
{
    NSLog(@"showAndHideIcon");
    [self createStatusBarIcon];
    if ([defaults boolForKey:PrefAutoHideIcon])
    {
        [self performSelector:@selector(destroyStatusBarIcon) withObject:nil afterDelay:10];
    }
}

- (void) showAbout
{
    [[NSApplication sharedApplication] orderFrontStandardAboutPanel:nil];
}

- (void) doQuit
{
    [NSApp terminate:nil];
}

#pragma mark - Utilities

- (void) showNotification:(NSString *)browserIdentifier
{
    NSString *browserPath = [sharedWorkspace absolutePathForAppBundleWithIdentifier:browserIdentifier];
    NSString *browserName = [[NSFileManager defaultManager] displayNameAtPath:browserPath];

    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = [NSString stringWithFormat:NotificationTitle, browserName];
    notification.informativeText = [NSString stringWithFormat:NotificationText, browserName, AppName];

    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

@end
