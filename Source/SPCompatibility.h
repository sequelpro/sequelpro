//
//  SPCompatibility.h
//  sequel-pro
//
//  Created by Max Lohrmann on 31.03.17.
//  Copyright (c) 2017 Max Lohrmann. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//
//  More info at <https://github.com/sequelpro/sequelpro>

/**
 * This file contains declarations for backward compatibility to
 * older XCode versions / SDKs.
 *
 * The current minimum required SDK is 10.8!
 */

#ifndef SPCompatibility
#define SPCompatibility

#pragma mark - 10.8 Mountain Lion

#ifndef __MAC_10_8
#define __MAC_10_8 1080
#endif

#if __MAC_OS_X_VERSION_MAX_ALLOWED < __MAC_10_8
#error You need to have at least SDK 10.8!
#endif

#pragma mark - 10.9 Mavericks

#ifndef __MAC_10_9
#define __MAC_10_9 1090
#endif

#if __MAC_OS_X_VERSION_MAX_ALLOWED < __MAC_10_9

@interface NSString (Mavericks)

@property (readonly, copy) NSString *stringByRemovingPercentEncoding;

@end

// This is actually a @protocol
@interface NSWindow (Mavericks)

// actual return type is `NSAppearance *`
@property (readonly) id effectiveAppearance;

@end

#define NSAppearanceNameAqua @"NSAppearanceNameAqua"

#endif

#pragma mark - 10.10 Yosemite

#ifndef __MAC_10_10
#define __MAC_10_10 101000
#endif

#if __MAC_OS_X_VERSION_MAX_ALLOWED < __MAC_10_10

// This enum is available since 10.5 but only got a "name" in 10.10
typedef NSUInteger NSCellHitResult;
// This bitfield is available since 10.0 but only got a "name" in 10.10
typedef NSUInteger NSAutoresizingMaskOptions;
// This enum has been around since 10.0 but only got a "name" in 10.10
typedef NSUInteger NSEventModifierFlags;

@compatibility_alias NSTitlebarAccessoryViewController NSViewController;

@interface NSViewController (NSTitlebarAccessoryViewController)

@property NSLayoutAttribute layoutAttribute;

@end

@interface NSWindow (Yosemite)

- (NSArray *)titlebarAccessoryViewControllers;
- (void)removeTitlebarAccessoryViewControllerAtIndex:(NSInteger)index;
- (void)addTitlebarAccessoryViewController:(NSTitlebarAccessoryViewController *)controller;

@end

// This code is available since 10.8 but public only since 10.10
typedef struct {
	NSInteger majorVersion;
	NSInteger minorVersion;
	NSInteger patchVersion;
} NSOperatingSystemVersion;

@interface NSProcessInfo ()
- (NSOperatingSystemVersion)operatingSystemVersion;
- (BOOL)isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion)version;
@end

#endif

#pragma mark - 10.11 El Capitan

#ifndef __MAC_10_11
#define __MAC_10_11 101100
#endif

#if !__has_feature(objc_kindof)
#define __kindof
#endif

#if __MAC_OS_X_VERSION_MAX_ALLOWED < __MAC_10_11

// formal protocol since 10.11, NSObject category before
@protocol WebFrameLoadDelegate <NSObject>
@end

// formal protocol since 10.11, NSObject category before
@protocol WebPolicyDelegate <NSObject>
@end

// formal protocol since 10.11, NSObject category before
@protocol WebUIDelegate <NSObject>
@end

@interface NSOpenPanel (ElCapitan)

@property (getter=isAccessoryViewDisclosed) BOOL accessoryViewDisclosed;

@end

#endif

#pragma mark - 10.12 Sierra

#ifndef __MAC_10_12
#define __MAC_10_12 101200
#endif

#if __MAC_OS_X_VERSION_MAX_ALLOWED < __MAC_10_12

//those enums got renamed in 10.12, probably for consistency
#define NSAlertStyleInformational NSInformationalAlertStyle
#define NSAlertStyleWarning       NSWarningAlertStyle
#define NSAlertStyleCritical      NSCriticalAlertStyle

#define NSEventModifierFlagShift                      NSShiftKeyMask
#define NSEventModifierFlagControl                    NSControlKeyMask
#define NSEventModifierFlagOption                     NSAlternateKeyMask
#define NSEventModifierFlagCommand                    NSCommandKeyMask
#define NSEventModifierFlagNumericPad                 NSNumericPadKeyMask
#define NSEventModifierFlagFunction                   NSFunctionKeyMask
#define NSEventModifierFlagDeviceIndependentFlagsMask NSDeviceIndependentModifierFlagsMask

@interface NSWindow (Sierra)
+ (void)setAllowsAutomaticWindowTabbing:(BOOL)arg;
@end

#endif

#endif

#pragma mark - 10.13 High Sierra

#ifndef __MAC_10_13
#define __MAC_10_13 101300
#endif

#if __MAC_OS_X_VERSION_MAX_ALLOWED < __MAC_10_13

// was an anonymous enum before
#define NSFontPanelModeMask NSUInteger

#endif

#pragma mark - 10.14 Mojave

#ifndef __MAC_10_14
#define __MAC_10_14 101400
#endif

#if __MAC_OS_X_VERSION_MAX_ALLOWED < __MAC_10_14

// NSAppearance class is supported since 10.9, but this file has to go back to 10.8
@interface NSObject (NSAppearance_Mojave)

- (NSString *)bestMatchFromAppearancesWithNames:(NSArray *)appearances;

@end

#define NSAppearanceNameDarkAqua @"NSAppearanceNameDarkAqua"

#endif
