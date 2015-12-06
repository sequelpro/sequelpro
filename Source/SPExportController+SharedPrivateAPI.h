//
//  SPExportController+SharedPrivateAPI.h
//  sequel-pro
//
//  Created by Max Lohrmann on 03.02.15.
//  Copyright (c) 2015 Max Lohrmann. All rights reserved.
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

#import "SPExportController.h"
#import "SPExportHandlerInstance.h"

@interface SPExportController (SharedPrivateAPI)
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (void)openExportErrorsSheetWithString:(NSString *)errors;
- (void)displayExportFinishedGrowlNotification:(NSString *)exportFilename;
- (void)_hideExportProgress;
- (void)_updateExportAdvancedOptionsLabel;
- (void)_switchTab;
- (void)_reopenExportSheet;

/**
 * Tries to set the export input to a given value or falls back to a default if not valid
 * @param input The source to use
 * @return YES if the source was accepted, NO otherwise
 * @pre _switchTab needs to have been run before this method to decide valid inputs
 */
- (BOOL)setExportSourceIfPossible:(SPExportSource)input;

@end

#pragma mark -

@interface _SPExportListItem : NSObject <SPExportSchemaObject> {
	BOOL isGroupRow;
	SPTableType type;
	NSString *name;
	id addonData;
}

@property (readwrite, nonatomic) BOOL isGroupRow;
@property (readwrite, nonatomic) SPTableType type;
@property (readwrite, nonatomic, copy) NSString *name;
@property (readwrite, nonatomic, retain) id addonData;

@end

static inline _SPExportListItem *MakeExportListItem(SPTableType type,NSString *name) {
	_SPExportListItem *item = [[_SPExportListItem alloc] init];
	[item setName:name];
	[item setType:type];
	[item setIsGroupRow:NO];
	return [item autorelease];
}

#pragma mark -

/**
 * converts a ([obj state] == NSOnState) to @YES / @NO
 * (because doing @([obj state] == NSOnState) will result in an integer 0/1)
 */
static inline NSNumber *IsOn(id obj)
{
	return (([obj state] == NSOnState)? @YES : @NO);
}

/**
 * Sets the state of obj to NSOnState or NSOffState based on the value of ref
 */
static inline void SetOnOff(NSNumber *ref,id obj)
{
	[obj setState:([ref boolValue] ? NSOnState : NSOffState)];
}