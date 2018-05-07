//
//  SPTableContentFilterController.h
//  sequel-pro
//
//  Created by Max Lohrmann on 04.05.18.
//  Copyright (c) 2018 Max Lohrmann. All rights reserved.
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

#import <Foundation/Foundation.h>

@class SPSplitView;
@class SPTableData;
@class SPDatabaseDocument;
@class SPTablesList;
@class SPTableContent;
@class SPContentFilterManager;

NSString * const SPTableContentFilterHeightChangedNotification;

@interface SPTableContentFilterController : NSObject {
	IBOutlet NSRuleEditor *filterRuleEditor;
	IBOutlet SPTableData *tableDataInstance;
	IBOutlet SPDatabaseDocument *tableDocumentInstance;
	IBOutlet SPTablesList *tablesListInstance;
	IBOutlet NSView *tableContentViewBelow;

	NSMutableArray *columns;
	NSMutableDictionary *contentFilters;
	NSMutableDictionary *numberOfDefaultFilters;

	NSMutableArray *model;

	SPContentFilterManager *contentFilterManager;

	CGFloat preferredHeight;
	
	id target;
	SEL action;
}

/**
 * Makes the first NSTextField found in the rule editor the first responder
 */
- (void)focusFirstInputField;

- (void)updateFiltersFrom:(SPTableContent *)tableContent;

- (void)openContentFilterManagerForFilterType:(NSString *)filterType;

- (NSString *)sqlWhereExpressionWithBinary:(BOOL)isBINARY error:(NSError **)err;

- (NSDictionary *)serializedFilter;
- (void)restoreSerializedFilters:(NSDictionary *)serialized;

- (NSDictionary *)makeSerializedFilterForColumn:(NSString *)colName operator:(NSString *)opName values:(NSArray *)values;

@property (readonly, assign, nonatomic) CGFloat preferredHeight;

/**
 * Indicates whether the rule editor has no expressions
 */
- (BOOL)isEmpty;

/**
 * Adds a new row to the rule editor
 */
- (void)addFilterExpression;

/**
 * Used when the rule editor wants to trigger filtering
 */
@property (assign, nonatomic) id target;
@property (assign, nonatomic) SEL action;

@end
