//
//  SRCommon.h
//  ShortcutRecorder
//
//  Copyright 2006-2007 Contributors. All rights reserved.
//
//  License: BSD
//
//  Contributors:
//      David Dauer
//      Jesper
//      Jamie Kirkpatrick

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <CoreServices/CoreServices.h>

#pragma mark Dummy class 

@interface SRDummyClass : NSObject {} @end

#pragma mark -
#pragma mark Typedefs

typedef struct _KeyCombo {
	NSUInteger flags; // 0 for no flags
	NSInteger code; // -1 for no code
} KeyCombo;

#pragma mark -
#pragma mark Enums

// Unicode values of some keyboard glyphs
enum {
	KeyboardTabRightGlyph       = 0x21E5,
	KeyboardTabLeftGlyph        = 0x21E4,
	KeyboardCommandGlyph        = kCommandUnicode,
	KeyboardOptionGlyph         = kOptionUnicode,
	KeyboardShiftGlyph          = kShiftUnicode,
	KeyboardControlGlyph        = kControlUnicode,
	KeyboardReturnGlyph         = 0x2305,
	KeyboardReturnR2LGlyph      = 0x21A9,	
	KeyboardDeleteLeftGlyph     = 0x232B,
	KeyboardDeleteRightGlyph    = 0x2326,	
	KeyboardPadClearGlyph       = 0x2327,
    KeyboardLeftArrowGlyph      = 0x2190,
	KeyboardRightArrowGlyph     = 0x2192,
	KeyboardUpArrowGlyph        = 0x2191,
	KeyboardDownArrowGlyph      = 0x2193,
    KeyboardPageDownGlyph       = 0x21DF,
	KeyboardPageUpGlyph         = 0x21DE,
	KeyboardNorthwestArrowGlyph = 0x2196,
	KeyboardSoutheastArrowGlyph = 0x2198,
	KeyboardEscapeGlyph         = 0x238B,
	KeyboardHelpGlyph           = 0x003F,
	KeyboardUpArrowheadGlyph    = 0x2303,
};

// Special keys
enum {
	kSRKeysF1 = 122,
	kSRKeysF2 = 120,
	kSRKeysF3 = 99,
	kSRKeysF4 = 118,
	kSRKeysF5 = 96,
	kSRKeysF6 = 97,
	kSRKeysF7 = 98,
	kSRKeysF8 = 100,
	kSRKeysF9 = 101,
	kSRKeysF10 = 109,
	kSRKeysF11 = 103,
	kSRKeysF12 = 111,
	kSRKeysF13 = 105,
	kSRKeysF14 = 107,
	kSRKeysF15 = 113,
	kSRKeysF16 = 106,
	kSRKeysF17 = 64,
	kSRKeysF18 = 79,
	kSRKeysF19 = 80,
	kSRKeysSpace = 49,
	kSRKeysDeleteLeft = 51,
	kSRKeysDeleteRight = 117,
	kSRKeysPadClear = 71,
	kSRKeysLeftArrow = 123,
	kSRKeysRightArrow = 124,
	kSRKeysUpArrow = 126,
	kSRKeysDownArrow = 125,
	kSRKeysSoutheastArrow = 119,
	kSRKeysNorthwestArrow = 115,
	kSRKeysEscape = 53,
	kSRKeysPageDown = 121,
	kSRKeysPageUp = 116,
	kSRKeysReturnR2L = 36,
	kSRKeysReturn = 76,
	kSRKeysTabRight = 48,
	kSRKeysHelp = 114
};

#pragma mark -
#pragma mark Macros

// Localization macros, for use in any bundle
#define SRLoc(key) SRLocalizedString(key, nil)
#define SRLocalizedString(key, comment) NSLocalizedStringFromTableInBundle(key, @"ShortcutRecorder", [NSBundle bundleForClass: [SRDummyClass class]], comment)

// Image macros, for use in any bundle
//#define SRImage(name) [[[NSImage alloc] initWithContentsOfFile: [[NSBundle bundleForClass: [self class]] pathForImageResource: name]] autorelease]
#define SRResIndImage(name) [SRSharedImageProvider supportingImageWithName:name]
#define SRImage(name) SRResIndImage(name)

//#define SRCommonWriteDebugImagery

// Macros for glyps
#define SRInt(x) [NSNumber numberWithInteger:x]
#define SRChar(x) [NSString stringWithFormat: @"%C", x]

// Some default values
#define ShortcutRecorderEmptyFlags 0
#define ShortcutRecorderAllFlags ShortcutRecorderEmptyFlags | (NSCommandKeyMask | NSAlternateKeyMask | NSControlKeyMask | NSShiftKeyMask | NSFunctionKeyMask)
#define ShortcutRecorderEmptyCode -1

// These keys will cancel the recoding mode if not pressed with any modifier
#define ShortcutRecorderEscapeKey 53
#define ShortcutRecorderBackspaceKey 51
#define ShortcutRecorderDeleteKey 117

#pragma mark -
#pragma mark Getting a string of the key combination

//
// ################### +- Returns string from keyCode like NSEvent's -characters
// #   EXPLANATORY   # | +- Returns string from keyCode like NSEvent's -charactersUsingModifiers
// #      CHART      # | | +- Returns fully readable and localized name of modifier (if modifier given)
// ################### | | | +- Returns glyph of modifier (if modifier given)
// SRString...         X - - X
// SRReadableString... X - X -
// SRCharacter...      - X - -
//
NSString * SRStringForKeyCode( NSInteger keyCode );
NSString * SRStringForCarbonModifierFlags( NSUInteger flags );
NSString * SRStringForCarbonModifierFlagsAndKeyCode( NSUInteger flags, NSInteger keyCode );
NSString * SRStringForCocoaModifierFlags( NSUInteger flags );
NSString * SRStringForCocoaModifierFlagsAndKeyCode( NSUInteger flags, NSInteger keyCode );
NSString * SRReadableStringForCarbonModifierFlagsAndKeyCode( NSUInteger flags, NSInteger keyCode );
NSString * SRReadableStringForCocoaModifierFlagsAndKeyCode( NSUInteger flags, NSInteger keyCode );
NSString *SRCharacterForKeyCodeAndCarbonFlags(NSInteger keyCode, NSUInteger carbonFlags);
NSString *SRCharacterForKeyCodeAndCocoaFlags(NSInteger keyCode, NSUInteger cocoaFlags);

#pragma mark Converting between Cocoa and Carbon modifier flags

NSUInteger SRCarbonToCocoaFlags( NSUInteger carbonFlags );
NSUInteger SRCocoaToCarbonFlags( NSUInteger cocoaFlags );

#pragma mark -
#pragma mark Animation pace function

CGFloat SRAnimationEaseInOut(CGFloat t);

#pragma mark -
#pragma mark Inlines

FOUNDATION_STATIC_INLINE KeyCombo SRMakeKeyCombo(NSInteger code, NSUInteger flags) {
	KeyCombo kc;
	kc.code = code;
	kc.flags = flags;
	return kc;
}

FOUNDATION_STATIC_INLINE BOOL SRIsSpecialKey(NSInteger keyCode) {
	return (keyCode == kSRKeysF1 || keyCode == kSRKeysF2 || keyCode == kSRKeysF3 || keyCode == kSRKeysF4 || keyCode == kSRKeysF5 || keyCode == kSRKeysF6 || keyCode == kSRKeysF7 || keyCode == kSRKeysF8 || keyCode == kSRKeysF9 || keyCode == kSRKeysF10 || keyCode == kSRKeysF11 || keyCode == kSRKeysF12 || keyCode == kSRKeysF13 || keyCode == kSRKeysF14 || keyCode == kSRKeysF15 || keyCode == kSRKeysF16 || keyCode == kSRKeysSpace || keyCode == kSRKeysDeleteLeft || keyCode == kSRKeysDeleteRight || keyCode == kSRKeysPadClear || keyCode == kSRKeysLeftArrow || keyCode == kSRKeysRightArrow || keyCode == kSRKeysUpArrow || keyCode == kSRKeysDownArrow || keyCode == kSRKeysSoutheastArrow || keyCode == kSRKeysNorthwestArrow || keyCode == kSRKeysEscape || keyCode == kSRKeysPageDown || keyCode == kSRKeysPageUp || keyCode == kSRKeysReturnR2L || keyCode == kSRKeysReturn || keyCode == kSRKeysTabRight || keyCode == kSRKeysHelp);
}

#pragma mark -
#pragma mark Additions

@interface NSAlert( SRAdditions )
+ (NSAlert *) alertWithNonRecoverableError:(NSError *)error;
@end

#pragma mark -
#pragma mark Image provider

@interface SRSharedImageProvider : NSObject
+ (NSImage *)supportingImageWithName:(NSString *)name;
@end
