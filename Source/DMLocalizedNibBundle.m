//  DMLocalizedNibBundle.m
//
//  Created by William Jon Shipley on 2/13/05.
//  Copyright © 2005-2009 Golden % Braeburn, LLC. All rights reserved except as below:
//  This code is provided as-is, with no warranties or anything. You may use it in your projects as you wish, but you must leave this comment block (credits and copyright) intact. That's the only restriction -- Golden % Braeburn otherwise grants you a fully-paid, worldwide, transferrable license to use this code as you see fit, including but not limited to making derivative works.


#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>


@interface NSBundle (DMLocalizedNibBundle)
+ (BOOL)deliciousLocalizingLoadNibFile:(NSString *)fileName externalNameTable:(NSDictionary *)context withZone:(NSZone *)zone;
@end

@interface NSBundle ()
+ (void)_localizeStringsInObject:(id)object table:(NSString *)table;
+ (NSString *)_localizedStringForString:(NSString *)string table:(NSString *)table;
// localize particular attributes in objects
+ (void)_localizeTitleOfObject:(id)object table:(NSString *)table;
+ (void)_localizeAlternateTitleOfObject:(id)object table:(NSString *)table;
+ (void)_localizeStringValueOfObject:(id)object table:(NSString *)table;
+ (void)_localizePlaceholderStringOfObject:(id)object table:(NSString *)table;
+ (void)_localizeToolTipOfObject:(id)object table:(NSString *)table;
+ (void)_localizeLabelOfObject:(id)object table:(NSString *)table;
@end

static NSMutableArray *deliciousBindingKeys = nil;

@implementation NSBundle (DMLocalizedNibBundle)

#pragma mark NSObject

+ (void)load;
{
    NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
    if (self == [NSBundle class]) {
        method_exchangeImplementations(class_getClassMethod(self, @selector(loadNibFile:externalNameTable:withZone:)), class_getClassMethod(self, @selector(deliciousLocalizingLoadNibFile:externalNameTable:withZone:)));
        deliciousBindingKeys = [[NSMutableArray alloc] initWithObjects:
                                    NSMultipleValuesPlaceholderBindingOption,
                                    NSNoSelectionPlaceholderBindingOption,
                                    NSNotApplicablePlaceholderBindingOption,
                                    NSNullPlaceholderBindingOption,
                                    nil];
    }
    [autoreleasePool release];
}


#pragma mark API

+ (BOOL)deliciousLocalizingLoadNibFile:(NSString *)fileName externalNameTable:(NSDictionary *)context withZone:(NSZone *)zone;
{
    NSString *localizedStringsTableName = [[fileName lastPathComponent] stringByDeletingPathExtension];
    NSString *localizedStringsTablePath = [[NSBundle mainBundle] pathForResource:localizedStringsTableName ofType:@"strings"];
    if (localizedStringsTablePath && ![[[localizedStringsTablePath stringByDeletingLastPathComponent] lastPathComponent] isEqualToString:@"English.lproj"]) {
        
        NSNib *nib = [[NSNib alloc] initWithContentsOfURL:[NSURL fileURLWithPath:fileName]];
        NSMutableArray *topLevelObjectsArray = [context objectForKey:NSNibTopLevelObjects];
        if (!topLevelObjectsArray) {
            topLevelObjectsArray = [NSMutableArray array];
            context = [NSMutableDictionary dictionaryWithDictionary:context];
            [(NSMutableDictionary *)context setObject:topLevelObjectsArray forKey:NSNibTopLevelObjects];
        }
        BOOL success = [nib instantiateNibWithExternalNameTable:context];
        [self _localizeStringsInObject:topLevelObjectsArray table:localizedStringsTableName];
        
        [nib release];
        return success;
        
    } else {
        return [self deliciousLocalizingLoadNibFile:fileName externalNameTable:context withZone:zone];
    }
}



#pragma mark Private API

+ (void)_localizeStringsInObject:(id)object table:(NSString *)table;
{
    if ([object isKindOfClass:[NSArray class]]) {
        NSArray *array = object;
        
        for (id nibItem in array)
            [self _localizeStringsInObject:nibItem table:table];

    } else if ([object isKindOfClass:[NSCell class]]) {
        NSCell *cell = object;
        
        if ([cell isKindOfClass:[NSActionCell class]]) {
            NSActionCell *actionCell = (NSActionCell *)cell;
            
            if ([actionCell isKindOfClass:[NSButtonCell class]]) {
                NSButtonCell *buttonCell = (NSButtonCell *)actionCell;
                if ([buttonCell imagePosition] != NSImageOnly) {
                    [self _localizeTitleOfObject:buttonCell table:table];
                    [self _localizeStringValueOfObject:buttonCell table:table];
                    [self _localizeAlternateTitleOfObject:buttonCell table:table];
                }
                
            } else if ([actionCell isKindOfClass:[NSTextFieldCell class]]) {
                NSTextFieldCell *textFieldCell = (NSTextFieldCell *)actionCell;
                // Following line is redundant with other code, localizes twice.
                // [self _localizeTitleOfObject:textFieldCell table:table];
                [self _localizeStringValueOfObject:textFieldCell table:table];
                [self _localizePlaceholderStringOfObject:textFieldCell table:table];

            } else if ([actionCell type] == NSTextCellType) {
                [self _localizeTitleOfObject:actionCell table:table];
                [self _localizeStringValueOfObject:actionCell table:table];
            }
        }
        
    } else if ([object isKindOfClass:[NSMenu class]]) {
        NSMenu *menu = object;
        [self _localizeTitleOfObject:menu table:table];
        
        [self _localizeStringsInObject:[menu itemArray] table:table];
        
    } else if ([object isKindOfClass:[NSMenuItem class]]) {
        NSMenuItem *menuItem = object;
        [self _localizeTitleOfObject:menuItem table:table];
        [self _localizeToolTipOfObject:menuItem table:table];
        
        [self _localizeStringsInObject:[menuItem submenu] table:table];
        
    } else if ([object isKindOfClass:[NSView class]]) {
        NSView *view = object;
        [self _localizeToolTipOfObject:view table:table];

        if ([view isKindOfClass:[NSBox class]]) {
            NSBox *box = (NSBox *)view;
            [self _localizeTitleOfObject:box table:table];
            
        } else if ([view isKindOfClass:[NSControl class]]) {
            NSControl *control = (NSControl *)view;

            if ([view isKindOfClass:[NSButton class]]) {
                NSButton *button = (NSButton *)control;
                
                if ([button isKindOfClass:[NSPopUpButton class]]) {
                    NSPopUpButton *popUpButton = (NSPopUpButton *)button;
                    NSMenu *menu = [popUpButton menu];
                    
                    [self _localizeStringsInObject:[menu itemArray] table:table];
                } else
                    [self _localizeStringsInObject:[button cell] table:table];

                
            } else if ([view isKindOfClass:[NSMatrix class]]) {
                NSMatrix *matrix = (NSMatrix *)control;
                
                NSArray *cells = [matrix cells];
                [self _localizeStringsInObject:cells table:table];
                
                for (NSCell *cell in cells) {
                    
                    NSString *localizedCellToolTip = [self _localizedStringForString:[matrix toolTipForCell:cell] table:table];
                    if (localizedCellToolTip)
                        [matrix setToolTip:localizedCellToolTip forCell:cell];
                }
                
            } else if ([view isKindOfClass:[NSSegmentedControl class]]) {
                NSSegmentedControl *segmentedControl = (NSSegmentedControl *)control;
                
                NSUInteger segmentIndex, segmentCount = [segmentedControl segmentCount];
                for (segmentIndex = 0; segmentIndex < segmentCount; segmentIndex++) {
                    NSString *localizedSegmentLabel = [self _localizedStringForString:[segmentedControl labelForSegment:segmentIndex] table:table];
                    if (localizedSegmentLabel)
                        [segmentedControl setLabel:localizedSegmentLabel forSegment:segmentIndex];
                    NSString *localizedSegmentTooltip = [self _localizedStringForString:[[segmentedControl cell] toolTipForSegment:segmentIndex] table:table];
                    if (localizedSegmentTooltip)
                        [[segmentedControl cell] setToolTip:localizedSegmentTooltip forSegment:segmentIndex];
                    
                    [self _localizeStringsInObject:[segmentedControl menuForSegment:segmentIndex] table:table];
                }
                
            } else if ([view isKindOfClass:[NSTableView class]]) {
                for (NSTableColumn *column in [view tableColumns]) {
                    [self _localizeStringValueOfObject:[column headerCell] table:table];
                }
            
            } else if ([view isKindOfClass:[NSTextField class]]) {
                NSDictionary *vb;
                if (vb = [view infoForBinding:@"value"]) {
                    NSMutableDictionary *lvb = [NSMutableDictionary dictionaryWithDictionary:[vb objectForKey:NSOptionsKey]];
                    for (NSString *bindingKey in deliciousBindingKeys) {
                        if ([lvb objectForKey:bindingKey] == [NSNull null]) continue;
                        NSString *localizedBindingString = [self _localizedStringForString:[lvb objectForKey:bindingKey] table:table];
                        if (localizedBindingString)
                            [lvb setObject:localizedBindingString forKey:bindingKey];
                    }
                    [view bind:@"value" toObject:[vb objectForKey:NSObservedObjectKey] withKeyPath:[vb objectForKey:NSObservedKeyPathKey] options:lvb];
                }
                [self _localizeStringsInObject:[control cell] table:table];
                
            } else
                [self _localizeStringsInObject:[control cell] table:table];

        } else if ([view isKindOfClass:[NSTabView class]]) {
            NSTabView *tabView = (NSTabView *)view;
            for (NSTabViewItem *tabViewItem in [tabView tabViewItems]) {
                [self _localizeLabelOfObject:tabViewItem table:table];
                [self _localizeToolTipOfObject:tabViewItem table:table];
                [self _localizeStringsInObject:[tabViewItem view] table:table];
            }

        }
        
        [self _localizeStringsInObject:[view subviews] table:table];
        
    } else if ([object isKindOfClass:[NSWindow class]]) {
        NSWindow *window = object;
        [self _localizeTitleOfObject:window table:table];
        
        [self _localizeStringsInObject:[window contentView] table:table];
        
    }
}

+ (NSString *)_localizedStringForString:(NSString *)string table:(NSString *)table;
{
    if (![string length])
        return nil;
    
    static NSString *defaultValue = @"I AM THE DEFAULT VALUE";
    NSString *localizedString = [[NSBundle mainBundle] localizedStringForKey:string value:defaultValue table:table];
    if (localizedString != defaultValue) {
        return localizedString;
    } else { 
#ifdef BETA_BUILD
        NSLog(@"        not going to localize string %@", string);
        return string; // [string uppercaseString]
#else
        return string;
#endif
    }
}


#define DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(blahName, capitalizedBlahName) \
+ (void)_localize ##capitalizedBlahName ##OfObject:(id)object table:(NSString *)table; \
{ \
    NSString *localizedBlah = [self _localizedStringForString:[object blahName] table:table]; \
    if (localizedBlah) \
        [object set ##capitalizedBlahName:localizedBlah]; \
}

DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(title, Title)
DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(alternateTitle, AlternateTitle)
DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(stringValue, StringValue)
DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(placeholderString, PlaceholderString)
DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(toolTip, ToolTip)
DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(label, Label)

@end