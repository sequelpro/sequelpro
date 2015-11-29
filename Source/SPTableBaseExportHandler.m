//
//  SPTableBaseExportHandler.m
//  sequel-pro
//
//  Created by Max Lohrmann on 25.11.15.
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

#import "SPTableBaseExportHandler_Protected.h"
#import "SPExportController.h"

static NSString *ContentColumnKey = @"content";

static inline void EnsureAddonDict(id<SPExportSchemaObject> obj) {
	if(![obj addonData]) [obj setAddonData:[NSMutableDictionary dictionary]]; //initialize dictionary if not already set
}

@implementation SPTableBaseExportHandler

@synthesize tableColumns = _tableColumns;

- (instancetype)initWithFactory:(id <SPExportHandlerFactory>)factory
{
	if ((self = [super initWithFactory:factory])) {
		//most exporters will only have a single column that contains the "include in export" checkbox
		[self setTableColumns:@[ContentColumnKey]];
	}

	return self;
}

- (void)willBecomeActive
{
	// we have to watch for that notification to update our isValidForExport state
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(_schemaObjectsChanged:)
	                                             name:SPExportControllerSchemaObjectsChangedNotification
	                                           object:[self controller]];
}

- (void)_schemaObjectsChanged:(NSNotification *)notification
{
	[self updateValidForExport];
}


- (void)configureTableColumn:(NSTableColumn *)col
{
	if([[col identifier] isEqualToString:ContentColumnKey]) {
		[col setHeaderToolTip:NSLocalizedString(@"Include content",@"export : item list : C column : tooltip")];
		[[col headerCell] setStringValue:NSLocalizedString(@"C","export : item list : C column title (C=content)")]; // 10.10+ has setTitle:
		[col setWidth:15];
		[col setMinWidth:15];
		[col setMaxWidth:15];
		[col setEditable:YES];
		[col setResizingMask:NSTableColumnAutoresizingMask];

		NSButtonCell *dc = [[NSButtonCell alloc] init];
		[dc setButtonType:NSSwitchButton];
		[dc setAllowsMixedState:NO];

		[col setDataCell:[dc autorelease]];

		return;
	}

	[NSException raise:NSInternalInconsistencyException
	            format:@"%s: Can't ask me about unknown table column with identifier=%@!",__PRETTY_FUNCTION__,[col identifier]];
}

- (id)objectValueForTableColumn:(NSTableColumn *)aTableColumn schemaObject:(id<SPExportSchemaObject>)obj
{
	if([[aTableColumn identifier] isEqualToString:ContentColumnKey]) {
		NSNumber *state;
		if((state = [[obj addonData] objectForKey:ContentColumnKey])) return state;
		// if we don't know a key we can just assume it is "unchecked"
		return @NO;
	}

	[NSException raise:NSInternalInconsistencyException
	            format:@"%s: Can't ask me about unknown table column with identifier=%@!",__PRETTY_FUNCTION__,[aTableColumn identifier]];
}


- (void)setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn schemaObject:(id<SPExportSchemaObject>)obj
{
	if([[aTableColumn identifier] isEqualToString:ContentColumnKey]) {
		EnsureAddonDict(obj);

		[[obj addonData] setObject:anObject forKey:ContentColumnKey];
		[self updateCanBeImported];
		[self updateValidForExport];
		return;
	}

	[NSException raise:NSInternalInconsistencyException
	            format:@"%s: Can't ask me about unknown table column with identifier=%@!",__PRETTY_FUNCTION__,[aTableColumn identifier]];
}

- (id)specificSettingsForSchemaObject:(id <SPExportSchemaObject>)obj
{
	// we can only say whether an object should be included
	return ([[[obj addonData] objectForKey:ContentColumnKey] boolValue])? @YES : @NO;
}

- (void)applySpecificSettings:(id)settings forSchemaObject:(id <SPExportSchemaObject>)obj
{
	EnsureAddonDict(obj);
	// the setting should be an NSNumber * containing a BOOL
	[[obj addonData] setObject:@([(NSNumber *)settings boolValue]) forKey:ContentColumnKey];
	[self updateCanBeImported];
	[self updateValidForExport];
}

- (BOOL)wouldIncludeSchemaObject:(id<SPExportSchemaObject>)obj
{
	// at our level the only decision to include something is based on whether the user checked it.
	return ([[[obj addonData] objectForKey:ContentColumnKey] boolValue]);
}

- (void)updateCanBeImported
{
	// don't change anything. this is the resposibility of the child classes
}

- (void)updateIncludeStateForAllSchemaObjects:(BOOL)newState
{
	// ok, then
	for(id<SPExportSchemaObject> obj in [[self controller] allSchemaObjects]) {
		EnsureAddonDict(obj);
		[[obj addonData] setObject:@(newState) forKey:ContentColumnKey];
	}
	[self updateCanBeImported];
	[self updateValidForExport];
}

- (void)updateIncludeState:(BOOL)newState forSchemaObject:(id <SPExportSchemaObject>)object
{
	EnsureAddonDict(object);
	[[object addonData] setObject:@(newState) forKey:ContentColumnKey];

	[self updateCanBeImported];
	[self updateValidForExport];
}


- (void)updateValidForExport
{
	// as a default, we'll just check whether at least one object is selected
	BOOL enable = NO;
	
	for(id<SPExportSchemaObject> obj in [[self controller] allSchemaObjects]) {
		if([[[obj addonData] objectForKey:ContentColumnKey] boolValue]) {
			enable = YES;
			break;
		}
	}
	
	[self setIsValidForExport:enable];
}

- (void)setIncludedSchemaObjects:(NSArray *)objectNames
{
	for(id<SPExportSchemaObject> obj in [[self controller] allSchemaObjects]) {
		EnsureAddonDict(obj);
		[[obj addonData] setObject:@([objectNames containsObject:[obj name]]) forKey:ContentColumnKey];
	}
	[self updateCanBeImported];
	[self updateValidForExport];
}

@end
