//
//  SPExportControllerDelegate.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on October 23, 2010.
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
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

#import "SPExportControllerDelegate.h"
#import "SPExportFilenameUtilities.h"
#import "SPExportFileNameTokenObject.h"

static inline BOOL IS_TOKEN(id x);
static inline BOOL IS_STRING(id x);

// Defined to suppress warnings
@interface SPExportController (SPExportControllerPrivateAPI)

- (void)_toggleExportButtonOnBackgroundThread;
- (void)_toggleSQLExportTableNameTokenAvailability;
- (void)_updateExportFormatInformation;
- (void)_switchTab;
- (NSArray *)_updateTokensForMixedContent:(NSArray *)tokens;
- (void)_tokenizeCustomFilenameTokenField;

@end

@implementation SPExportController (SPExportControllerDelegate)

#pragma mark -
#pragma mark Table view datasource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView;
{
	return [tables count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{		
	return NSArrayObjectAtIndex([tables objectAtIndex:rowIndex], [exportTableList columnWithIdentifier:[tableColumn identifier]]);
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{	
	[[tables objectAtIndex:rowIndex] replaceObjectAtIndex:[exportTableList columnWithIdentifier:[tableColumn identifier]] withObject:anObject];
	
	[self updateAvailableExportFilenameTokens];
	[self _toggleExportButtonOnBackgroundThread];
	[self _updateExportFormatInformation];
}

#pragma mark -
#pragma mark Table view delegate methods

- (BOOL)tableView:(NSTableView *)tableView shouldTrackCell:(NSCell *)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	return (tableView == exportTableList);
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	[cell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
}

#pragma mark -
#pragma mark Tabview delegate methods

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	[tabViewItem setView:exporterView];
	
	[self _switchTab];
}

#pragma mark -
#pragma mark Token field delegate methods

/**
 * Use the default token style for matched tokens, plain text for all other text.
 */
- (NSTokenStyle)tokenField:(NSTokenField *)tokenField styleForRepresentedObject:(id)representedObject
{
	if (IS_TOKEN(representedObject)) return NSDefaultTokenStyle;

	return NSPlainTextTokenStyle;
}

- (BOOL)tokenField:(NSTokenField *)tokenField writeRepresentedObjects:(NSArray *)objects toPasteboard:(NSPasteboard *)pboard
{
	NSMutableArray *mixed = [NSMutableArray arrayWithCapacity:[objects count]];
	NSMutableString *flatted = [NSMutableString string];
	
	for(id item in objects) {
		if(IS_TOKEN(item)) {
			[mixed addObject:@{@"tokenId": [item tokenId]}];
			[flatted appendFormat:@"{%@}",[item tokenId]];
		}
		else if(IS_STRING(item)) {
			[mixed addObject:item];
			[flatted appendString:item];
		}
		else {
			[NSException raise:NSInternalInconsistencyException format:@"tokenField %@ contains unexpected object %@",tokenField,item];
		}
	}
	
	[pboard setString:flatted forType:NSPasteboardTypeString];
	[pboard setPropertyList:mixed forType:SPExportCustomFileNameTokenPlistType];
	return YES;
}

- (NSArray *)tokenField:(NSTokenField *)tokenField readFromPasteboard:(NSPasteboard *)pboard
{
	NSArray *items = [pboard propertyListForType:SPExportCustomFileNameTokenPlistType];
	// if we have our preferred object type use it
	if(items) {
		NSMutableArray *res = [NSMutableArray arrayWithCapacity:[items count]];
		for (id item in items) {
			if (IS_STRING(item)) {
				[res addObject:item];
			}
			else if([item isKindOfClass:[NSDictionary class]]) {
				NSString *name = [item objectForKey:@"tokenId"];
				if(name) {
					SPExportFileNameTokenObject *tok = [SPExportFileNameTokenObject tokenWithId:name];
					[res addObject:tok];
				}
			}
			else {
				[NSException raise:NSInternalInconsistencyException format:@"pasteboard %@ contains unexpected object %@",pboard,item];
			}
		}
		return res;
	}
	// if the string came from another app, paste it literal, tokenfield will take care of any conversions
	NSString *raw = [pboard stringForType:NSPasteboardTypeString];
	if(raw) {
		return @[[raw stringByReplacingCharactersInSet:[NSCharacterSet newlineCharacterSet]	withString:@" "]];
	}
	
	return nil;
}

/**
 * Take the default suggestion of new tokens - all untokenized text, as no tokenizing character is set - and
 * split/recombine strings that contain tokens. This preserves all supplied characters and allows tokens to be typed.
 */
- (NSArray *)tokenField:(NSTokenField *)tokenField shouldAddObjects:(NSArray *)tokens atIndex:(NSUInteger)index
{
	return [self _updateTokensForMixedContent:tokens];
}

- (NSString *)tokenField:(NSTokenField *)tokenField displayStringForRepresentedObject:(id)representedObject
{
	if (IS_TOKEN(representedObject)) {
		return [localizedTokenNames objectForKey:[(SPExportFileNameTokenObject *)representedObject tokenId]];
	}

	return representedObject;
}

/**
 * Return the editing string untouched - implementing this method prevents whitespace trimming.
 */
- (id)tokenField:(NSTokenField *)tokenField representedObjectForEditingString:(NSString *)editingString
{
	return editingString;
}

/**
 * During text entry into the token field, update the displayed filename and also
 * trigger tokenization after a short delay.
 */
- (void)controlTextDidChange:(NSNotification *)notification
{
	// this method can either be called by typing, or by copy&paste.
	// In the latter case tokenization will already be done by now.
	if ([notification object] == exportCustomFilenameTokenField) {
		[self updateDisplayedExportFilename];
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_tokenizeCustomFilenameTokenField) object:nil];
		// do not queue a call if the key causing this change was the return key.
		// This is to prevent a loop with _tokenizeCustomFilenameTokenField.
		if([[NSApp currentEvent] type] != NSKeyDown || [[NSApp currentEvent] keyCode] != 0x24) {
			[self performSelector:@selector(_tokenizeCustomFilenameTokenField) withObject:nil afterDelay:0.5];
		}
	}
}

#pragma mark -
#pragma mark Combo box delegate methods

- (void)comboBoxSelectionDidChange:(NSNotification *)notification
{
	if ([notification object] == exportCSVFieldsTerminatedField) {
		[self updateDisplayedExportFilename];
	}
}

#pragma mark -

/**
 * Takes a mixed array of strings and tokens and converts
 * any valid tokens inside the strings into real tokens
 */
- (NSArray *)_updateTokensForMixedContent:(NSArray *)tokens
{
	//if two consecutive tokens are strings, merge them
	NSMutableArray *mergedTokens = [NSMutableArray array];
	for (id inputToken in tokens)
	{
		if(IS_TOKEN(inputToken)) {
			[mergedTokens addObject:inputToken];
		}
		else if(IS_STRING(inputToken)) {
			id prev = [mergedTokens lastObject];
			if(IS_STRING(prev)) {
				[mergedTokens removeLastObject];
				[mergedTokens addObject:[prev stringByAppendingString:inputToken]];
			}
			else {
				[mergedTokens addObject:inputToken];
			}
		}
	}
	
	// create a mapping dict of tokenId => token
	NSMutableDictionary *replacement = [NSMutableDictionary dictionary];
	for (SPExportFileNameTokenObject *realToken in [exportCustomFilenameTokenPool objectValue]) {
		NSString *serializedName = [NSString stringWithFormat:@"{%@}",[realToken tokenId]];
		[replacement setObject:realToken forKey:serializedName];
	}
	
	//now we can look for real tokens to convert inside the strings
	NSMutableArray *processedTokens = [NSMutableArray array];
	for (id token in mergedTokens) {
		if(IS_TOKEN(token)) {
			[processedTokens addObject:token];
			continue;
		}
		
		NSString *remainder = token;
		while(true) {
			NSRange openCurl = [remainder rangeOfString:@"{"];
			if(openCurl.location == NSNotFound) {
				break;
			}
			NSString *before = [remainder substringToIndex:openCurl.location];
			if([before length]) {
				[processedTokens addObject:before];
			}
			remainder = [remainder substringFromIndex:openCurl.location];
			NSRange closeCurl = [remainder rangeOfString:@"}"];
			if(closeCurl.location == NSNotFound) {
				break; //we've hit an unterminated token
			}
			NSString *tokenString = [remainder substringToIndex:closeCurl.location+1];
			SPExportFileNameTokenObject *tokenObject = [replacement objectForKey:tokenString];
			if(tokenObject) {
				[processedTokens addObject:tokenObject];
			}
			else {
				[processedTokens addObject:tokenString]; // no token with this name, add it as string
			}
			remainder = [remainder substringFromIndex:closeCurl.location+1];
		}
		if([remainder length]) {
			[processedTokens addObject:remainder];
		}
	}
	
	return processedTokens;
}

- (void)_tokenizeCustomFilenameTokenField
{
	// if we are currently inside or at the end of a string segment we can
	// call for tokenization to happen by simulating a return press
	
	if ([exportCustomFilenameTokenField currentEditor] == nil) return;
	
	NSRange selectedRange = [[exportCustomFilenameTokenField currentEditor] selectedRange];
	
	if (selectedRange.location == NSNotFound) return;
	if (selectedRange.location == 0) return; // the beginning of the field is not valid for tokenization
	if (selectedRange.length > 0) return;
	
	NSUInteger start = 0;
	for(id obj in [exportCustomFilenameTokenField objectValue]) {
		NSUInteger length;
		BOOL isText = NO;
		if(IS_STRING(obj)) {
			length = [obj length];
			isText = YES;
		}
		else if(IS_TOKEN(obj)) {
			length = 1; // tokens are seen as one char by the textview
		}
		else {
			[NSException raise:NSInternalInconsistencyException format:@"Unknown object type in token field: %@",obj];
		}
		NSUInteger end = start+length;
		if(selectedRange.location >= start && selectedRange.location <= end) {
			if(!isText) return; // cursor is at the end of a token
			break;
		}
		start += length;
	}
	
	// All conditions met - synthesize the return key to trigger tokenization.
	NSEvent *tokenizingEvent = [NSEvent keyEventWithType:NSKeyDown
												location:NSMakePoint(0,0)
										   modifierFlags:0
											   timestamp:0
											windowNumber:[[exportCustomFilenameTokenField window] windowNumber]
												 context:[NSGraphicsContext currentContext]
											  characters:nil
							 charactersIgnoringModifiers:nil
											   isARepeat:NO
												 keyCode:0x24];
	
	[NSApp postEvent:tokenizingEvent atStart:NO];
}

@end

#pragma mark -

BOOL IS_TOKEN(id x)
{
	return [x isKindOfClass:[SPExportFileNameTokenObject class]];
}

BOOL IS_STRING(id x)
{
	return [x isKindOfClass:[NSString class]];
}

