//
//  SPRuleFilterController.m
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

#import "SPRuleFilterController.h"
#import "SPQueryController.h"
#import "SPDatabaseDocument.h"
#import "RegexKitLite.h"
#import "SPContentFilterManager.h"
#import "SPFunctions.h"
#import "SPTableFilterParser.h"

typedef NS_ENUM(NSInteger, RuleNodeType) {
	RuleNodeTypeColumn,
	RuleNodeTypeString,
	RuleNodeTypeOperator,
	RuleNodeTypeArgument,
	RuleNodeTypeConnector,
	RuleNodeTypeEnable,
};

NSString * const SPRuleFilterHeightChangedNotification = @"SPRuleFilterHeightChanged";

/**
 * The type of filter rule that the current item represents.
 */
const NSString * const SerFilterClass = @"filterClass";
/**
 * The current rule is a group row (an "AND" or "OR" expression with children)
 */
const NSString * const SerFilterClassGroup = @"groupNode";
/**
 * The current rule is a filter expression
 */
const NSString * const SerFilterClassExpression = @"expressionNode";
/**
 * Group Nodes only:
 * Indicates whether the group is a conjunction.
 * If YES, the children will be combined using "AND", otherwise using "OR".
 */
const NSString * const SerFilterGroupIsConjunction = @"isConjunction";
/**
 * Group Nodes only:
 * An array of child filter rules (which again can be group or expression rules)
 */
const NSString * const SerFilterGroupChildren = @"children";
/**
 * Expression Nodes only:
 * The name of the column to filter in (left side expression)
 *
 * Legacy names:
 *   @"filterField", fieldField
 */
const NSString * const SerFilterExprColumn = @"column";
/**
 * Expression Nodes only:
 * The data type grouping of the column for applicable filters
 */
const NSString * const SerFilterExprType = @"filterType";
/**
 * Expression Nodes only:
 * The title of the filter operator to apply
 *
 * Legacy names:
 *   @"filterComparison", compareField
 */
const NSString * const SerFilterExprComparison = @"filterComparison";
/**
 * Expression Nodes only:
 * The values to apply the filter with (an array of 0 or more elements)
 *
 * Legacy names:
 *   @"filterValue", argumentField
 *   @"firstBetweenField", @"secondBetweenField", firstBetweenField, secondBetweenField
 */
const NSString * const SerFilterExprValues = @"filterValues";
/**
 * Expression Nodes only:
 * the filter definition dictionary (as in ContentFilters.plist)
 * for the filter represented by SerFilterExprComparison.
 *
 * This item is not designed to be serialized to disk
 */
const NSString * const SerFilterExprDefinition = @"_filterDefinition";
/**
 * Expression Nodes only:
 * Is the filter expression enabled for filtering?
 */
const NSString * const SerFilterExprEnabled = @"enabled";

#pragma mark -

@interface RuleNode : NSObject {
	RuleNodeType type;
}
@property(assign, nonatomic) RuleNodeType type;
/**
 * This method checks if another node can take the place of self in a filter row.
 * The RuleNode implementation checks only that both nodes are of the same type.
 */
- (BOOL)isViableReplacementFor:(RuleNode *)other;
@end

@interface ColumnNode : RuleNode {
	NSString *name;
	NSString *typegrouping;
	NSArray *operatorCache;
	NSUInteger opCacheVersion;
}
@property(copy, nonatomic) NSString *name;
@property(copy, nonatomic) NSString *typegrouping;
@property(retain, nonatomic) NSArray *operatorCache;
@property(assign, nonatomic) NSUInteger opCacheVersion;
@end

@interface StringNode : RuleNode {
	NSString *value;
}
@property(copy, nonatomic) NSString *value;
@end

@interface OpNode : RuleNode {
	// Note: The main purpose of this field is to have @"=" for column A and @"=" for column B to return NO in -isEqual:
	//       because otherwise NSRuleEditor will get confused and blow up.
	ColumnNode *parentColumn;
	NSDictionary *settings;
	NSDictionary *filter;
}
@property (assign, nonatomic) ColumnNode *parentColumn;
@property (retain, nonatomic) NSDictionary *settings;
@property (retain, nonatomic) NSDictionary *filter;
/**
 * This method is only a shortcut to `-[[node filter] objectForKey:@"MenuLabel"]`
 */
- (NSString *)name;
@end

@interface ArgNode : RuleNode {
	NSDictionary *filter;
	NSUInteger argIndex;
	NSString *initialValue;
}
@property (copy, nonatomic) NSString *initialValue;
@property (retain, nonatomic) NSDictionary *filter;
@property (assign, nonatomic) NSUInteger argIndex;
@end

@interface ConnectorNode : RuleNode {
	NSDictionary *filter;
	NSUInteger labelIndex;
}
@property (retain, nonatomic) NSDictionary *filter;
@property (assign, nonatomic) NSUInteger labelIndex;
@end

@interface EnableNode : RuleNode {
	BOOL initialState;
	BOOL allowsMixedState;
}
@property (assign, nonatomic) BOOL initialState;
@property (assign, nonatomic) BOOL allowsMixedState;
@end

#pragma mark -

/**
 * TODO:
 * This class shouldn't even exist to begin with.
 * Its sad story begins with this call in `-[SPRuleFilterController dealloc]`:
 *
 *   [filterRuleEditor unbind:@"rows"];
 *
 * `-dealloc` may not be the best method to undo what we did in `-awakeFromNib`, but it's the only thing we have.
 * Also we have to unbind this object, or we may receive zombie calls later on because the binding is unretained.
 * Which brings us to another huge mistake Apple made in the implementation of -unbind. The call looks like this:
 *
 *   - [NSRulEditor unbind:]
 *     - [NSRuleEditor _rootRowsArray]
 *       - [NSRuleEditor->_boundArrayOwner mutableArrayValueForKeyPath:NSRuleEditor->_boundArrayKeyPath]
 *
 * -mutableArrayValueForKeyPath: is the culprit here since it does not return the object itself ("model") but
 * instead returns an autoreleased proxy object which retains the parent object of the key.
 *
 * That explains why we can't put "model" into SPRuleFilterController:
 * The `-[NSRuleEditor unbind:]` would cause a call to `-[SPRuleFilterController retain]` from within
 * `-[SPRuleFilterController dealloc]` (which is pointless since there is no way out from -dealloc).
 * This wouldn't be a problem if the proxy object was released again while dealloc is still on the stack, but
 * since it is autoreleased we end up with a zombie call again.
 *
 * ModelContainer is a dummy intermediate to prevent this, since it is still valid when we enter -dealloc and
 * trigger -unbind and thus can handle the -retain by the proxy object.
 */
@interface ModelContainer : NSObject
{
	NSMutableArray *model;
}
// This is the binding used by NSRuleEditor for the current state
@property (retain, nonatomic) NSMutableArray *model;
@end

#pragma mark -

@interface SPRuleFilterController () <NSRuleEditorDelegate, NSTextFieldDelegate>

@property (readwrite, assign, nonatomic) CGFloat preferredHeight;

- (NSArray *)_compareTypesForColumn:(ColumnNode *)colNode;
- (IBAction)_textFieldAction:(id)sender;
- (IBAction)_editFiltersAction:(id)sender;
- (void)_contentFiltersHaveBeenUpdated:(NSNotification *)notification;
+ (NSDictionary *)_flattenSerializedFilter:(NSDictionary *)in;
static BOOL SerIsGroup(NSDictionary *dict);
- (NSDictionary *)_serializedFilterIncludingFilterDefinition:(BOOL)includeDefinition withDisabled:(BOOL)includeDisabled;
+ (void)_writeFilterTree:(NSDictionary *)in toString:(NSMutableString *)out wrapInParenthesis:(BOOL)wrap binary:(BOOL)isBINARY error:(NSError **)err;
- (NSMutableDictionary *)_restoreSerializedFilter:(NSDictionary *)serialized;
static void _addIfNotNil(NSMutableArray *array, id toAdd);
- (ColumnNode *)_columnForName:(NSString *)name;
- (OpNode *)_operatorNamed:(NSString *)title forColumn:(ColumnNode *)col;
- (BOOL)_focusOnFieldInSubtree:(NSDictionary *)dict;
- (void)_resize;
- (void)openContentFilterManagerForFilterType:(NSString *)filterType;
- (IBAction)filterTable:(id)sender;
- (IBAction)resetFilter:(id)sender;
- (IBAction)_menuItemInRuleEditorClicked:(id)sender;
- (void)_pretendPlayRuleEditorForCriteria:(NSMutableArray *)criteria
                            displayValues:(NSMutableArray *)displayValues
                                    inRow:(NSInteger)row
              tryingToPreserveOldCriteria:(NSArray *)oldCriteria
                            displayValues:(NSArray *)oldDisplayValues;
- (void)_ensureValidOperatorCache:(ColumnNode *)col;
static BOOL _arrayContainsInViewHierarchy(NSArray *haystack, id needle);
- (IBAction)addFilter:(id)sender;
- (void)_updateButtonStates;
- (void)_doChangeToRuleEditorData:(void (^)(void))duringBlock;
- (IBAction)_checkboxClicked:(id)sender;
- (void)_updateCheckedStateUpwardsFromCompoundRow:(NSInteger)row;
- (void)_updateCheckedStateForRow:(NSInteger)row to:(NSCellStateValue)newState;
- (void)_updateCheckedStateDownwardsFromCompoundRow:(NSInteger)row to:(NSCellStateValue)newState;
- (NSCellStateValue)_recalculateCheckboxStatesFromRow:(NSInteger)row;
- (NSCellStateValue)_checkboxStateForRow:(NSInteger)row;
@end

@implementation SPRuleFilterController

@synthesize preferredHeight = preferredHeight;
@synthesize target = target;
@synthesize action = action;

- (instancetype)init
{
	if((self = [super init])) {
		columns = [[NSMutableArray alloc] init];
		_modelContainer = [[ModelContainer alloc] init];
		preferredHeight = 0.0;
		target = nil;
		action = NULL;
		opNodeCacheVersion = 1;
		isDoingChangeCausedOutsideOfRuleEditor = NO;
		previousRowCount = 0;

		// Init default filters for Content Browser
		contentFilters = [[NSMutableDictionary alloc] init];
		numberOfDefaultFilters = [[NSMutableDictionary alloc] init];

		NSError *readError = nil;
		NSString *filePath = [NSBundle pathForResource:@"ContentFilters.plist" ofType:nil inDirectory:[[NSBundle mainBundle] bundlePath]];
		NSData *defaultFilterData = [NSData dataWithContentsOfFile:filePath
		                                                   options:NSMappedRead
		                                                     error:&readError];

		if(defaultFilterData && !readError) {
			NSDictionary *defaultFilterDict = [NSPropertyListSerialization propertyListWithData:defaultFilterData
			                                                                            options:NSPropertyListMutableContainersAndLeaves
			                                                                             format:NULL
			                                                                              error:&readError];

			if(defaultFilterDict && !readError) {
				[contentFilters setDictionary:defaultFilterDict];
			}
		}

		if (readError) {
			NSLog(@"Error while reading 'ContentFilters.plist':\n%@", readError);
			NSBeep();
		}
		else {
			[numberOfDefaultFilters setObject:[NSNumber numberWithInteger:[[contentFilters objectForKey:@"number"] count]] forKey:@"number"];
			[numberOfDefaultFilters setObject:[NSNumber numberWithInteger:[[contentFilters objectForKey:@"date"] count]] forKey:@"date"];
			[numberOfDefaultFilters setObject:[NSNumber numberWithInteger:[[contentFilters objectForKey:@"string"] count]] forKey:@"string"];
			[numberOfDefaultFilters setObject:[NSNumber numberWithInteger:[[contentFilters objectForKey:@"spatial"] count]] forKey:@"spatial"];
		}
	}
	return self;
}

- (void)awakeFromNib
{
	// move the add filter button over the filter button (since only one of them can be visible at a time)
	NSRect filterRect = [filterButton frame];
	NSRect addFilterRect = [addFilterButton frame];
	CGFloat widthContainer = [[filterButton superview] frame].size.width;
	CGFloat deltaR = widthContainer - (filterRect.origin.x + filterRect.size.width);
	addFilterRect.origin.x = widthContainer - deltaR - addFilterRect.size.width;
	addFilterRect.origin.y = filterRect.origin.y;
	addFilterRect.size.height = filterRect.size.height;
	[addFilterButton setFrame:addFilterRect];

	[self _doChangeToRuleEditorData:^{
		[filterRuleEditor bind:@"rows" toObject:_modelContainer withKeyPath:@"model" options:nil];
	}];

	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(_contentFiltersHaveBeenUpdated:)
	                                             name:SPContentFiltersHaveBeenUpdatedNotification
	                                           object:nil];
}

- (void)focusFirstInputField
{
	for(NSDictionary *rootItem in [_modelContainer model]) {
		if([self _focusOnFieldInSubtree:rootItem]) return;
	}
}

- (BOOL)_focusOnFieldInSubtree:(NSDictionary *)dict
{
	//if we are a simple row we might have an input field ourself, otherwise search among our children
	if([[dict objectForKey:@"rowType"] unsignedIntegerValue] == NSRuleEditorRowTypeSimple) {
		for(id obj in [dict objectForKey:@"displayValues"]) {
			if([obj isKindOfClass:[NSTextField class]]) {
				[[(NSTextField *)obj window] makeFirstResponder:obj];
				return YES;
			}
		}
	}
	else {
		for(NSDictionary *child in [dict objectForKey:@"subrows"]) {
			if([self _focusOnFieldInSubtree:child]) return YES;
		}
	}
	return NO;
}

- (void)setColumns:(NSArray *)dataColumns;
{
	[self _doChangeToRuleEditorData:^{
		// we have to access the model in the same way the rule editor does for it to realize the changes
		[[_modelContainer mutableArrayValueForKey:@"model"] removeAllObjects];

		[columns removeAllObjects];

		//without a table there is nothing to filter
		if(dataColumns) {
			//sort column names if enabled
			NSArray *columnDefinitions = dataColumns;
			if ([[NSUserDefaults standardUserDefaults] boolForKey:SPAlphabeticalTableSorting]) {
				NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES];
				columnDefinitions = [columnDefinitions sortedArrayUsingDescriptors:@[sortDescriptor]];
			}

			// get the columns
			for (NSDictionary *colDef in columnDefinitions) {
				ColumnNode *node = [[ColumnNode alloc] init];
				[node setName:[colDef objectForKey:@"name"]];
				[node setTypegrouping:[colDef objectForKey:@"typegrouping"]];
				[columns addObject:node];
				[node release];
			}
		}

		// make the rule editor reload the criteria
		[filterRuleEditor reloadCriteria];
	}];

	// disable UI if no criteria exist (enable otherwise)
	[self setEnabled:YES];
}

- (NSInteger)ruleEditor:(NSRuleEditor *)editor numberOfChildrenForCriterion:(nullable id)criterion withRowType:(NSRuleEditorRowType)rowType
{
	// nil criterion is always the first element in a row
	if(rowType == NSRuleEditorRowTypeCompound) {
		if(!criterion) {
			return 1; //enable checkbox
		}
		RuleNodeType type = [(RuleNode *)criterion type];
		// compound rows are only for "AND"/"OR" groups
		if(type == RuleNodeTypeEnable) {
			return 2;
		}
	}
	else if(rowType == NSRuleEditorRowTypeSimple) {
		if(!criterion) {
			return 1; // enable checkbox
		}
		RuleNodeType type = [(RuleNode *)criterion type];
		// the children of the enable checkbox are the columns
		if(type == RuleNodeTypeEnable) {
			return [columns count];
		}
		// the children of the columns are their operators
		else if(type == RuleNodeTypeColumn) {
			ColumnNode *node = (ColumnNode *)criterion;
			[self _ensureValidOperatorCache:node];
			return [[node operatorCache] count];
		}
		// the first child of an operator is the first argument (if it has one)
		else if(type == RuleNodeTypeOperator) {
			OpNode *node = (OpNode *)criterion;
			NSInteger numOfArgs = [[[node filter] objectForKey:@"NumberOfArguments"] integerValue];
			return (numOfArgs > 0) ? 1 : 0;
		}
		// the child of an argument can only be the conjunction label if more arguments follow
		else if(type == RuleNodeTypeArgument) {
			ArgNode *node = (ArgNode *)criterion;
			NSUInteger numOfArgs = [[[node filter] objectForKey:@"NumberOfArguments"] unsignedIntegerValue];
			return (numOfArgs > [node argIndex]+1) ? 1 : 0;
		}
		// the child of a conjunction is the next argument, if we have one
		else if(type == RuleNodeTypeConnector) {
			ConnectorNode *node = (ConnectorNode *)criterion;
			NSUInteger numOfArgs = [[[node filter] objectForKey:@"NumberOfArguments"] unsignedIntegerValue];
			return (numOfArgs > [node labelIndex]+1) ? 1 : 0;
		}
	}
	return 0;
}

- (id)ruleEditor:(NSRuleEditor *)editor child:(NSInteger)index forCriterion:(nullable id)criterion withRowType:(NSRuleEditorRowType)rowType
{
	// nil criterion is always the first element in a row
	if(rowType == NSRuleEditorRowTypeCompound) {
		if(!criterion) {
			EnableNode *node = [[EnableNode alloc] init];
			[node setAllowsMixedState:YES];
			return [node autorelease];
		}
		RuleNodeType type = [(RuleNode *) criterion type];
		// compound rows are only for "AND"/"OR" groups
		if(type == RuleNodeTypeEnable) {
			StringNode *node = [[StringNode alloc] init];
			switch(index) {
				case 0: [node setValue:@"AND"]; break;
				case 1: [node setValue:@"OR"]; break;
			}
			return [node autorelease];
		}
	}
	else if(rowType == NSRuleEditorRowTypeSimple) {
		// this is the enable checkbox
		if(!criterion) {
			return [[[EnableNode alloc] init] autorelease];
		}
		RuleNodeType type = [(RuleNode *) criterion type];
		// this is the column field
		if (type == RuleNodeTypeEnable) {
			return [columns objectAtIndex:index];
		}
		// the children of the columns are their operators
		if (type == RuleNodeTypeColumn) {
			return [[criterion operatorCache] objectAtIndex:index];
		}
		// the first child of an operator is the first argument
		else if(type == RuleNodeTypeOperator) {
			NSDictionary *filter = [(OpNode *)criterion filter];
			if([[filter objectForKey:@"NumberOfArguments"] integerValue]) {
				ArgNode *arg = [[ArgNode alloc] init];
				[arg setFilter:filter];
				[arg setArgIndex:0];
				return [arg autorelease];
			}
		}
		// the child of an argument can only be the conjunction label if more arguments follow
		else if(type == RuleNodeTypeArgument) {
			NSDictionary *filter = [(ArgNode *)criterion filter];
			NSUInteger argIndex = [(ArgNode *)criterion argIndex];
			if([[filter objectForKey:@"NumberOfArguments"] unsignedIntegerValue] > argIndex +1) {
				ConnectorNode *node = [[ConnectorNode alloc] init];
				[node setFilter:filter];
				[node setLabelIndex:argIndex]; // label 0 follows argument 0
				return [node autorelease];
			}
		}
		// the child of a conjunction is the next argument, if we have one
		else if(type == RuleNodeTypeConnector) {
			ConnectorNode *node = (ConnectorNode *)criterion;
			NSUInteger numOfArgs = [[[node filter] objectForKey:@"NumberOfArguments"] unsignedIntegerValue];
			if(numOfArgs > [node labelIndex]+1) {
				ArgNode *arg = [[ArgNode alloc] init];
				[arg setFilter:[node filter]];
				[arg setArgIndex:([node labelIndex]+1)];
				return [arg autorelease];
			}
		}
	}
	return nil;
}

- (id)ruleEditor:(NSRuleEditor *)editor displayValueForCriterion:(id)criterion inRow:(NSInteger)row
{
	switch([(RuleNode *)criterion type]) {
		case RuleNodeTypeString: return [(StringNode *)criterion value];
		case RuleNodeTypeEnable: {
			EnableNode *node = (EnableNode *)criterion;
			NSButton *check = [[NSButton alloc] init];
			[check setTitle:NSLocalizedString(@"Enable Filter", @"table Content : rule filter editor : row : enable filter expression checkbox")];
			[check setToolTip:NSLocalizedString(@"When unchecked this filter expression will not be applied", @"table Content : rule filter editor : row : enable filter expression checkbox : tooltip")];
			// see +checkboxWithTitle:target:action: in 10.12+
			[check setButtonType:NSSwitchButton];
			[check setBezelStyle:NSBezelStyleRegularSquare];
			[check setBordered:NO];
			[check setImagePosition:NSImageOnly];
			[check sizeToFit];
			[check setAllowsMixedState:[node allowsMixedState]];
			[check setState:([node initialState] ? NSOnState : NSOffState)];
			[check setTarget:self];
			[check setAction:@selector(_checkboxClicked:)];
			return [check autorelease];
		}
		case RuleNodeTypeColumn: {
			/*
			 * We could also return a string here, but we want a hook into the selection process so we can preserve
			 * the other values in a row when a user changes the column (also see the comment below)
			 */
			NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[(ColumnNode *)criterion name] action:NULL keyEquivalent:@""];
			[item setRepresentedObject:@{
				@"node": criterion,
			}];
			[item setTarget:self];
			[item setAction:@selector(_menuItemInRuleEditorClicked:)];
			return [item autorelease];
		}
		case RuleNodeTypeOperator: {
			OpNode *node = (OpNode *)criterion;
			NSMenuItem *item;
			if ([[[node settings] objectForKey:@"isSeparator"] boolValue]) {
				item = [NSMenuItem separatorItem];
			}
			else {
				/* NOTE:
				 * Apple's doc on NSRuleEditor says that returning NSMenuItems is supported.
				 * However there seems to be a major discrepancy between what Apple considers "supported" and what any
				 * sane person would consider supported.
				 *
				 * Basically one would expect NSMenuItems to be handled in the same way a number of NSString children of a
				 * row's element will be handled, but that was not Apples intention. By supported they actually mean
				 * "Your app won't crash immediately if you return an NSMenuItem here" - but that's about it.
				 * Even selecting such an NSMenuItem will already cause an exception on 10.6 and be treated as a NOOP on
				 * later OSes.
				 * So if we return NSMenuItems we have to implement the full logic of the NSRuleEditor for updating and
				 * displaying the row ourselves, starting with handling the target/action of the NSMenuItems!
				 */
				item = [[NSMenuItem alloc] initWithTitle:[[node settings] objectForKey:@"title"] action:NULL keyEquivalent:@""];
				[item setToolTip:[[node settings] objectForKey:@"tooltip"]];
				[item setTag:[[[node settings] objectForKey:@"tag"] integerValue]];
				[item setRepresentedObject:@{
					@"node": node,
					// this one is needed by the "Edit filters…" item for context
					@"filterType": SPBoxNil([[node settings] objectForKey:@"filterType"]),
				}];
				[item setTarget:self];
				[item setAction:@selector(_menuItemInRuleEditorClicked:)];
				[item autorelease];
			}
			return item;
		}
		case RuleNodeTypeArgument: {
			//an argument is a textfield
			ArgNode *node = (ArgNode *)criterion;
			NSTextField *textField = [[NSTextField alloc] init];
			[[textField cell] setSendsActionOnEndEditing:YES];
			[[textField cell] setUsesSingleLineMode:YES];
			[textField setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
			[textField sizeToFit];
			[textField setTarget:self];
			[textField setAction:@selector(_textFieldAction:)];
			[textField setDelegate:self]; // see -control:textView:doCommandBySelector:
			[textField setToolTip:NSLocalizedString(@"Enter the value to apply the filter condition with.\nPress ↩ to apply the filter or ⇧⌫ to remove this rule.", @"table content : rule filter editor : text input field : tooltip")];
			if([node initialValue]) [textField setStringValue:[node initialValue]];
			NSRect frame = [textField frame];
			//adjust width, to make the field wider
			frame.size.width = 500; //TODO determine a good width (possibly from the field type size) - how to access the rule editors bounds?
			[textField setFrame:frame];
			return [textField autorelease];
		}
		case RuleNodeTypeConnector: {
			// a simple string for once
			ConnectorNode *node = (ConnectorNode *)criterion;
			NSArray* labels = [[node filter] objectForKey:@"ConjunctionLabels"];
			return (labels && [labels count] == 1)? [labels objectAtIndex:0] : @"";
		}
	}
	
	return nil;
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
	// if the user presses shift+backspace or shift+delete we'll try to remove the whole rule
	NSEvent *event = [NSApp currentEvent];
	if(
		( commandSelector == @selector(deleteBackward:) || commandSelector == @selector(deleteForward:) ) &&
		[event type] == NSKeyDown &&
		([event modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask) == NSEventModifierFlagShift
	) {
		NSInteger row = [filterRuleEditor rowForDisplayValue:control];

		if(row != NSNotFound) {
			// we'll do the actual processing async, because we are currently in the stack of the object which will be dropped by this action.
			// so we want the delegate method to have finished first, just to be safe
			SPMainLoopAsync(^{
				// if we are about to remove the only row in existance, treat it as a reset instead
				if([[_modelContainer model] count] == 1) {
					[self resetFilter:nil];
				}
				else {
					[self _doChangeToRuleEditorData:^{
						[filterRuleEditor removeRowAtIndex:row];
					}];
					[self filterTable:nil]; // trigger a new filtering for convenience. I don't know if that is always the preferred approach...
				}
			});
			return YES;
		}
	}

	return NO;
}

- (IBAction)_checkboxClicked:(id)sender
{
	NSInteger row = [filterRuleEditor rowForDisplayValue:sender];
	NSCellStateValue newState = [(NSButton *)sender state];

	// to have -setState: accept mixed state we have to -setAllowsMixedState:YES in which case the user, too, can cycle all three states m(
	if(newState == NSMixedState) {
		[sender setNextState];
		newState = [sender state];
	}

	if(row >= 0 && (newState == NSOnState || newState == NSOffState)) {
		// if we are a compound row, go downwards to update our children
		if([filterRuleEditor rowTypeForRow:row] == NSRuleEditorRowTypeCompound) {
			[self _updateCheckedStateDownwardsFromCompoundRow:row to:newState];
		}
		// then go upwards to update the checkbox state of our parent
		[self _updateCheckedStateUpwardsFromCompoundRow:[filterRuleEditor parentRowForRow:row]];
	}
}

/**
 * This method will recursively update the checkbox state of all children rows of the given row index with `newState`.
 * `row` itself will not be changed!
 *
 * @param row
 *   The row index of a compound row for which to update the children states (can be -1)
 * @param newState
 *   The new state to set for all children rows
 */
- (void)_updateCheckedStateDownwardsFromCompoundRow:(NSInteger)row to:(NSCellStateValue)newState
{
	NSIndexSet *subrows = [filterRuleEditor subrowIndexesForRow:row];
	[subrows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
		[self _updateCheckedStateForRow:idx to:newState];
		// go deeper for compound rows
		if([filterRuleEditor rowTypeForRow:idx] == NSRuleEditorRowTypeCompound) {
			[self _updateCheckedStateDownwardsFromCompoundRow:idx to:newState];
		}
	}];
}

/**
 * This method will update the checkbox state of the row specified by the given index.
 * No other rows will be affected by this call.
 *
 * @param row
 *   The row index to update (must be >= 0)
 * @param newState
 *   The new checkbox state to set
 */
- (void)_updateCheckedStateForRow:(NSInteger)row to:(NSCellStateValue)newState
{
	NSArray *displayValues = [filterRuleEditor displayValuesForRow:row];
	RuleNode *firstCriterion = [[filterRuleEditor criteriaForRow:row] objectAtIndex:0];
	if([firstCriterion type] == RuleNodeTypeEnable) {
		NSButton *button = [displayValues objectAtIndex:0];
		[button setState:newState];
	}
}

/**
 * This method will recursively update the checkbox state of the given row and all of its parent rows
 * to match the aggregate state of all simple rows in the affected subtree.
 *
 * The rule editor row tree will be walked upwards using `-parentRowForRow:` until a top-level row is encountered
 * (parent=-1).
 *
 * NOTE: This method assumes that all compound child rows of `row` already have a consistent checkbox state!
 *
 * @param row
 *   The row index of a compound row (can be `-1`)
 */
- (void)_updateCheckedStateUpwardsFromCompoundRow:(NSInteger)row
{
	// stop condition for recursion
	if(row < 0) return;

	__block NSCellStateValue newState = NSOnState;
	__block NSUInteger countOff = 0;
	NSIndexSet *subrows = [filterRuleEditor subrowIndexesForRow:row];
	[subrows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
		NSCellStateValue subState = [self _checkboxStateForRow:idx];
		// mixed is easy: if at least one child is mixed, the parent is mixed, too
		if(subState == NSMixedState) {
			newState = NSMixedState;
			*stop = YES;
			return;
		}
		else if(subState == NSOffState) {
			countOff++;
		}
	}];
	if(countOff) {
		// off only happens if all children are off
		newState = (countOff == [subrows count]) ? NSOffState : NSMixedState;
	}

	//update ourselves
	[self _updateCheckedStateForRow:row to:newState];

	// notify our own parent of the change
	[self _updateCheckedStateUpwardsFromCompoundRow:[filterRuleEditor parentRowForRow:row]];
}

/**
 * This method recursively walks the rule editor tree starting with the children of `row`,
 * updates the state of any compound row along the way (except `row` itself!) to be consistent with its child rows and
 * returns the compound checkbox state of all children.
 *
 * @param row
 *   The row index of a compound row (can be `-1` to start walking with all top-level rows)
 * @return
 *   The resulting state for the given row according to all children (recursive).
 *   This will be:
 *   - `NSOnState` if the row either has no children or all children are also checked
 *   - `NSMixedState` if at least one child row is also in mixed state or some (but not all) of the child rows are unchecked
 *   - `NSOffState` if there are child rows and all of them are unchecked
 */
- (NSCellStateValue)_recalculateCheckboxStatesFromRow:(NSInteger)row
{
	NSIndexSet *subrows = [filterRuleEditor subrowIndexesForRow:row];

	__block NSCellStateValue newState = NSOnState;
	__block NSUInteger countOff = 0;
	[subrows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
		NSCellStateValue subState;
		if([filterRuleEditor rowTypeForRow:idx] == NSRuleEditorRowTypeCompound) {
			subState = [self _recalculateCheckboxStatesFromRow:idx];
			// if the current row is a compound row, update its state from its children
			[self _updateCheckedStateForRow:idx to:subState];
		}
		else {
			subState = [self _checkboxStateForRow:idx];
		}
		if(subState == NSMixedState) {
			newState = NSMixedState;
		}
		else if(subState == NSOffState) {
			countOff++;
		}
	}];
	if(countOff) {
		// off only happens if all children are off
		newState = (countOff == [subrows count]) ? NSOffState : NSMixedState;
	}

	return newState;
}

/**
 * Get the current checkbox state for a row
 *
 * NOTE: This method can be used on simple and compound rows, but it will not check that the compound state is actually
 * consistent with its children before returning it.
 *
 * @param row
 *   The row index to return the checkbox state of (must be >= 0)
 * @return
 *   The checkbox state.
 *   Defaults to `NSOnState` if no checkbox is found in the row.
 */
- (NSCellStateValue)_checkboxStateForRow:(NSInteger)row
{
	NSArray *displayValues = [filterRuleEditor displayValuesForRow:row];
	RuleNode *firstCriterion = [[filterRuleEditor criteriaForRow:row] objectAtIndex:0];
	if([firstCriterion type] == RuleNodeTypeEnable) {
		NSButton *subButton = [displayValues objectAtIndex:0];
		return [subButton state];
	}

	SPLog(@"row=%ld: row does not have enable node as first child!? (type=%ld)", row, (NSInteger)[firstCriterion type]);
	return NSOnState;
}

- (IBAction)_textFieldAction:(id)sender
{
	// if the action was caused by pressing return or enter, trigger filtering
	NSEvent *event = [NSApp currentEvent];
	if(event && [event type] == NSKeyDown && ([event keyCode] == 36 || [event keyCode] == 76)) {
		[self filterTable:nil];
	}
}

- (IBAction)_menuItemInRuleEditorClicked:(id)sender
{
	if(!sender) return; // NSRuleEditor will throw on nil

	NSInteger row = [filterRuleEditor rowForDisplayValue:sender];

	if(row == NSNotFound) return; // unknown display values

	RuleNode *criterion = [[(NSMenuItem *)sender representedObject] objectForKey:@"node"];

	if([criterion type] == RuleNodeTypeOperator) {
		OpNode *node = (OpNode *)criterion;
		// if the row has an explicit handler, pass on the action and do nothing
		id _target = [[node settings] objectForKey:@"target"];
		SEL _action = (SEL)[(NSValue *)[[node settings] objectForKey:@"action"] pointerValue];
		if(_target && _action) {
			[_target performSelector:_action withObject:sender];
			return;
		}
	}

	/* now comes the painful part, where we'd have to find out where exactly in the row this
	 * displayValue should appear.
	 *
	 * Annoyingly we can't tell the rule editor to just replace a single element. We actually
	 * have to recalculate the whole row starting with the element we replaced - a task the
	 * rule editor would normally do for us when using NSStrings!
	 */
	NSMutableArray *criteria = [[filterRuleEditor criteriaForRow:row] mutableCopy];
	NSMutableArray *displayValues = [[filterRuleEditor displayValuesForRow:row] mutableCopy];

	// find the position of the previous node
	NSUInteger nodeIndex = NSNotFound;
	NSUInteger i = 0;
	for(RuleNode *obj in criteria) {
		if([obj isViableReplacementFor:criterion]) {
			nodeIndex = i;
			break;
		}
		i++;
	}

	if(nodeIndex < [criteria count]) {
		// yet another uglyness: if one of the displayValues is an input and currently the first responder
		// we have to manually restore that for the new input we create for UX reasons.
		// However an NSTextField is seldom a first responder, usually it's an invisible subview of the text field...
		id firstResponder = [[filterRuleEditor window] firstResponder];
		BOOL hasFirstResponderInRow = _arrayContainsInViewHierarchy(displayValues, firstResponder);

		//remove previous node and everything that follows and append new node
		NSRange stripRange = NSMakeRange(nodeIndex, ([criteria count] - nodeIndex));

		//preserve the old criteria and displayValues, so we can restore the values of input fields if appropriate
		NSArray *oldCriteria = [criteria copy];
		NSArray *oldDisplayValues = [displayValues copy];

		[criteria removeObjectsInRange:stripRange];
		[criteria addObject:criterion];

		//remove the display value for the old op node and everything that followed
		[displayValues removeObjectsInRange:stripRange];

		//now we'll fill in everything again
		[self _pretendPlayRuleEditorForCriteria:criteria
		                          displayValues:displayValues
		                                  inRow:row
		            tryingToPreserveOldCriteria:[oldCriteria subarrayWithRange:stripRange]
		                          displayValues:[oldDisplayValues subarrayWithRange:stripRange]];

		[oldCriteria release];
		[oldDisplayValues release];

		//and update the row to its new state
		[self _doChangeToRuleEditorData:^{
			[filterRuleEditor setCriteria:criteria andDisplayValues:displayValues forRowAtIndex:row];
		}];

		if(hasFirstResponderInRow) {
			// make the next possible object after the opnode the new next responder (since the previous one is gone now)
			for (NSUInteger j = nodeIndex + 1; j < [displayValues count]; ++j) {
				id obj = [displayValues objectAtIndex:j];
				if([obj respondsToSelector:@selector(acceptsFirstResponder)] && [obj acceptsFirstResponder]) {
					[[filterRuleEditor window] makeFirstResponder:obj];
					break;
				}
			}
		}
	}

	[criteria release];
	[displayValues release];
}

BOOL _arrayContainsInViewHierarchy(NSArray *haystack, id needle)
{
	//first, try it the easy way
	if([haystack indexOfObjectIdenticalTo:needle] != NSNotFound) return YES;

	// otherwise, if needle is a view, check if it appears as a desencdant of some other view in haystack
	Class NSViewClass = [NSView class];
	if([needle isKindOfClass:NSViewClass]) {
		for(id obj in haystack) {
			if([obj isKindOfClass:NSViewClass] && [needle isDescendantOf:obj]) return YES;
		}
	}

	return NO;
}

/**
 * This method recursively fills up the passed-in criteria and displayValues arrays with objects in the way the
 * NSRuleEditor would, so they can be used with the -setCriteria:andDisplayValues:forRowAtIndex: call.
 * 
 * Assumptions made:
 * - row is a valid row within the bounds of the rule editor
 * - criteria contains at least one object
 * - displayValues contains exactly one less object than criteria
 * - the first object in oldCriteria is what the last object in criteria replaced
 * - all objects in oldDisplayValues correspond to the objects at the same index in oldCriteria
 */
- (void)_pretendPlayRuleEditorForCriteria:(NSMutableArray *)criteria
                            displayValues:(NSMutableArray *)displayValues
                                    inRow:(NSInteger)row
              tryingToPreserveOldCriteria:(NSArray *)oldCriteria
                            displayValues:(NSArray *)oldDisplayValues
{
	RuleNode *curCriterion = [criteria lastObject];

	//first fill in the display value for the current criterion
	id display = [self ruleEditor:filterRuleEditor displayValueForCriterion:curCriterion inRow:row];
	if(!display) return; // abort if unset

	// try to restore the value from the previous displayValue for input fields
	RuleNode *oldCriterion = [oldCriteria objectOrNilAtIndex:0];
	if([curCriterion type] == RuleNodeTypeArgument && oldCriterion && [curCriterion type] == [oldCriterion type]) {
		NSTextField *oldField = [oldDisplayValues objectOrNilAtIndex:0];
		if(oldField) [display setStringValue:[oldField stringValue]];
	}
	[displayValues addObject:display];

	// now let's check if we have to go deeper
	NSRuleEditorRowType rowType = [filterRuleEditor rowTypeForRow:row];
	if(![self ruleEditor:filterRuleEditor numberOfChildrenForCriterion:curCriterion withRowType:rowType]) return;

	// we only care for the first child, though
	id nextCriterion = [self ruleEditor:filterRuleEditor child:0 forCriterion:curCriterion withRowType:rowType];
	if(nextCriterion) {
		NSArray *nextOldCriteria      = ([oldCriteria count] > 1 ? [oldCriteria subarrayWithRange:NSMakeRange(1, [oldCriteria count] - 1)] : [NSArray array]);
		NSArray *nextOldDisplayValues = ([oldDisplayValues count] > 1 ? [oldDisplayValues subarrayWithRange:NSMakeRange(1, [oldDisplayValues count] - 1)] : [NSArray array]);

		// if the user changed the column, try to retain the previously selected operation
		RuleNode *nextOldCriterion = [nextOldCriteria objectOrNilAtIndex:0];
		if(nextOldCriterion && [nextOldCriterion type] == RuleNodeTypeOperator && [curCriterion type] == RuleNodeTypeColumn) {
			NSString *opName = [(OpNode *)nextOldCriterion name];
			OpNode *op = [self _operatorNamed:opName forColumn:(ColumnNode *)curCriterion];
			if(op) nextCriterion = op;
		}
		[criteria addObject:nextCriterion];

		[self _pretendPlayRuleEditorForCriteria:criteria
		                          displayValues:displayValues
		                                  inRow:row
		            tryingToPreserveOldCriteria:nextOldCriteria
		                          displayValues:nextOldDisplayValues];
	}
}

- (IBAction)filterTable:(id)sender
{
	if(target && action) [target performSelector:action withObject:self];
}

- (IBAction)resetFilter:(id)sender
{
	[self _doChangeToRuleEditorData:^{
		[[_modelContainer mutableArrayValueForKey:@"model"] removeAllObjects];
	}];
	if(target && action) [target performSelector:action withObject:nil];
}

- (IBAction)addFilter:(id)sender
{
	[self addFilterExpression];
}

- (void)_resize
{
	// The situation with the sizing is a bit f'ed up:
	// - When -ruleEditorRowsDidChange: is invoked the NSRuleEditor has not yet updated its required frame size
	// - We can't use KVO on -frame either, because SPTableContent will update the container size which
	//   ultimately also updates the NSRuleEditor's frame, causing a loop
	// - Calling -sizeToFit works, but only when the NSRuleEditor is growing. It won't shrink
	//   after removing rows.
	// - -intrinsicContentSize is what we want, but that method is 10.7+, so on 10.6 let's do the
	//   easiest workaround (note that both -intrinsicContentSize and -sizeToFit internally use -[NSRuleEditor _minimumFrameHeight])
	CGFloat wantsHeight;
	if([filterRuleEditor respondsToSelector:@selector(intrinsicContentSize)]) {
		NSSize sz = [filterRuleEditor intrinsicContentSize];
		wantsHeight = sz.height;
	}
	else {
		wantsHeight = [filterRuleEditor rowHeight] * [filterRuleEditor numberOfRows];
	}
	if(wantsHeight != preferredHeight) {
		[self setPreferredHeight:wantsHeight];
		[[NSNotificationCenter defaultCenter] postNotificationName:SPRuleFilterHeightChangedNotification object:self];
	}
}

- (void)ruleEditorRowsDidChange:(NSNotification *)notification 
{
	//TODO find a better way to trigger resize
	// We can't do this here, because it will cause rows to jump around when removing them (the add case works fine, though)
	[self performSelector:@selector(_resize) withObject:nil afterDelay:0.2];
	//[self _resize];
	[self _updateButtonStates];

	// if a row has been added, we need to update the checkboxes to match again
	[self _recalculateCheckboxStatesFromRow:-1];

	// if the user removed the last row in the editor by pressing "-" (and only then) we immediately want to trigger a filter reset.
	// There are two problems with that:
	// - The rule editor is very liberal in the use of this notification. Receiving it does not mean the number of rows actually did change
	// - There is no direct way to know whether the action was triggered by the user, so we can only try to exclude all other causes of changes
	NSInteger newRowCount = [filterRuleEditor numberOfRows];
	if(!isDoingChangeCausedOutsideOfRuleEditor && previousRowCount > 0 && newRowCount == 0) {
		if(target && action) [target performSelector:action withObject:nil];
	}
	previousRowCount = newRowCount;
}

- (void)_updateButtonStates
{
	BOOL empty = [self isEmpty];
	[addFilterButton setHidden:!empty];
	[filterButton setHidden:empty];

	[resetButton setEnabled:(enabled && !empty)];
	[filterButton setEnabled:(enabled && !empty)];
	[filterRuleEditor setEnabled:enabled];
	[addFilterButton setEnabled:(enabled && empty)];
}

- (void)dealloc
{
	[self _doChangeToRuleEditorData:^{
		[filterRuleEditor unbind:@"rows"];
	}];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	// WARNING: THIS MUST COME AFTER -unbind:! See the class comment on ModelContainer for the reasoning
	SPClear(_modelContainer);
	SPClear(columns);
	SPClear(contentFilters);
	SPClear(numberOfDefaultFilters);
	[super dealloc];
}

/**
 * Sets the compare types for the filter and the appropriate formatter for the textField
 */
- (NSArray *)_compareTypesForColumn:(ColumnNode *)colNode
{
	if(contentFilters == nil
		|| ![contentFilters objectForKey:@"number"]
		|| ![contentFilters objectForKey:@"string"]
		|| ![contentFilters objectForKey:@"date"]) {
		NSLog(@"Error while setting filter types.");
		NSBeep();
		return @[];
	}

	NSString *fieldTypeGrouping;
	if([colNode typegrouping]) {
		fieldTypeGrouping = [NSString stringWithString:[colNode typegrouping]];
	}
	else {
		return @[];
	}

	NSMutableArray *compareItems = [NSMutableArray array];
	
	NSString *compareType;
	
	if ( [fieldTypeGrouping isEqualToString:@"date"] ) {
		compareType = @"date";

		/*
		 if ([fieldType isEqualToString:@"timestamp"]) {
		 [argumentField setFormatter:[[NSDateFormatter alloc]
		 initWithDateFormat:@"%Y-%m-%d %H:%M:%S" allowNaturalLanguage:YES]];
		 }
		 if ([fieldType isEqualToString:@"datetime"]) {
		 [argumentField setFormatter:[[NSDateFormatter alloc] initWithDateFormat:@"%Y-%m-%d %H:%M:%S" allowNaturalLanguage:YES]];
		 }
		 if ([fieldType isEqualToString:@"date"]) {
		 [argumentField setFormatter:[[NSDateFormatter alloc] initWithDateFormat:@"%Y-%m-%d" allowNaturalLanguage:YES]];
		 }
		 if ([fieldType isEqualToString:@"time"]) {
		 [argumentField setFormatter:[[NSDateFormatter alloc] initWithDateFormat:@"%H:%M:%S" allowNaturalLanguage:YES]];
		 }
		 if ([fieldType isEqualToString:@"year"]) {
		 [argumentField setFormatter:[[NSDateFormatter alloc] initWithDateFormat:@"%Y" allowNaturalLanguage:YES]];
		 }
		 */

		// TODO: A bug in the framework previously meant enum fields had to be treated as string fields for the purposes
		// of comparison - this can now be split out to support additional comparison fucntionality if desired.
	} 
	else if ([fieldTypeGrouping isEqualToString:@"string"]   || [fieldTypeGrouping isEqualToString:@"binary"]
		|| [fieldTypeGrouping isEqualToString:@"textdata"] || [fieldTypeGrouping isEqualToString:@"blobdata"]
		|| [fieldTypeGrouping isEqualToString:@"enum"]) {

		compareType = @"string";
		// [argumentField setFormatter:nil];

	} 
	else if ([fieldTypeGrouping isEqualToString:@"bit"] || [fieldTypeGrouping isEqualToString:@"integer"]
		|| [fieldTypeGrouping isEqualToString:@"float"]) {
		compareType = @"number";
		// [argumentField setFormatter:numberFormatter];

	} 
	else if ([fieldTypeGrouping isEqualToString:@"geometry"]) {
		compareType = @"spatial";

	} 
	else  {
		compareType = @"";
		NSBeep();
		NSLog(@"ERROR: unknown type for comparision: in %@", fieldTypeGrouping);
	}

	// Add IS NULL and IS NOT NULL as they should always be available
	// [compareField addItemWithTitle:@"IS NULL"];
	// [compareField addItemWithTitle:@"IS NOT NULL"];

	// Remove user-defined filters first
	if([numberOfDefaultFilters objectForKey:compareType]) {
		NSUInteger cycles = [[contentFilters objectForKey:compareType] count] - [[numberOfDefaultFilters objectForKey:compareType] integerValue];
		while(cycles > 0) {
			[[contentFilters objectForKey:compareType] removeLastObject];
			cycles--;
		}
	}
	
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

#ifndef SP_CODA /* content filters */
	// Load global user-defined content filters
	if([prefs objectForKey:SPContentFilters]
		&& [contentFilters objectForKey:compareType]
		&& [[prefs objectForKey:SPContentFilters] objectForKey:compareType])
	{
		[[contentFilters objectForKey:compareType] addObjectsFromArray:[[prefs objectForKey:SPContentFilters] objectForKey:compareType]];
	}

	// Load doc-based user-defined content filters
	if([[SPQueryController sharedQueryController] contentFilterForFileURL:[tableDocumentInstance fileURL]]) {
		id filters = [[SPQueryController sharedQueryController] contentFilterForFileURL:[tableDocumentInstance fileURL]];
		if([filters objectForKey:compareType])
			[[contentFilters objectForKey:compareType] addObjectsFromArray:[filters objectForKey:compareType]];
	}
#endif

	NSUInteger i = 0;
	if([contentFilters objectForKey:compareType]) {
		for (id filter in [contentFilters objectForKey:compareType]) {
			// Create the tooltip
			NSString *tooltip;
			if ([filter objectForKey:@"Tooltip"])
				tooltip = [filter objectForKey:@"Tooltip"];
			else {
				NSMutableString *tip = [[NSMutableString alloc] init];
				if ([filter objectForKey:@"Clause"] && [(NSString *) [filter objectForKey:@"Clause"] length]) {
					[tip setString:[[filter objectForKey:@"Clause"] stringByReplacingOccurrencesOfRegex:@"(?<!\\\\)(\\$\\{.*?\\})" withString:@"[arg]"]];
					if ([tip isMatchedByRegex:@"(?<!\\\\)\\$BINARY"]) {
						[tip replaceOccurrencesOfRegex:@"(?<!\\\\)\\$BINARY" withString:@""];
						[tip appendString:NSLocalizedString(@"\n\nPress ⇧ for binary search (case-sensitive).", @"\n\npress shift for binary search tooltip message")];
					}
					[tip flushCachedRegexData];
					[tip replaceOccurrencesOfRegex:@"(?<!\\\\)\\$CURRENT_FIELD" withString:[[colNode name] backtickQuotedString]];
					[tip flushCachedRegexData];
					tooltip = [NSString stringWithString:tip];
				} else {
					tooltip = @"";
				}
				[tip release];
			}

			OpNode *node = [[OpNode alloc] init];
			[node setParentColumn:colNode];
			[node setSettings:@{
				@"title": ([filter objectForKey:@"MenuLabel"] ? [filter objectForKey:@"MenuLabel"] : @"not specified"),
				@"tooltip": tooltip,
				@"tag": @(i),
				@"filterType": compareType,
			}];
			[node setFilter:filter];
			[compareItems addObject:node];
			[node release];
			i++;
		}
	}

	{
		OpNode *node = [[OpNode alloc] init];
		[node setParentColumn:colNode];
		[node setSettings:@{
			@"isSeparator": @YES,
		}];
		[compareItems addObject:node];
		[node release];
	}

	{
		OpNode *node = [[OpNode alloc] init];
		[node setParentColumn:colNode];
		[node setSettings:@{
			@"title": NSLocalizedString(@"Edit Filters…", @"edit filter"),
			@"tooltip": NSLocalizedString(@"Edit user-defined Filters…", @"edit user-defined filter"),
			@"tag": @(i),
			@"target": self,
			@"action": [NSValue valueWithPointer:@selector(_editFiltersAction:)],
			@"filterType": compareType,
		}];
		[compareItems addObject:node];
		[node release];
	}

	return compareItems;
}

- (IBAction)_editFiltersAction:(id)sender
{
	if([sender isKindOfClass:[NSMenuItem class]]) {
		NSMenuItem *menuItem = (NSMenuItem *)sender;
		NSString *filterType = [(NSDictionary *)[menuItem representedObject] objectForKey:@"filterType"];
		if([filterType unboxNull]) [self openContentFilterManagerForFilterType:filterType];
	}
}

- (void)openContentFilterManagerForFilterType:(NSString *)filterType
{
	// init query favorites controller
#ifndef SP_CODA
	[[NSUserDefaults standardUserDefaults] synchronize];
#endif
	if(contentFilterManager) [contentFilterManager release];
	contentFilterManager = [[SPContentFilterManager alloc] initWithDatabaseDocument:tableDocumentInstance forFilterType:filterType];

	// Open query favorite manager
	[NSApp beginSheet:[contentFilterManager window]
	   modalForWindow:[tableDocumentInstance parentWindow]
	    modalDelegate:contentFilterManager
	   didEndSelector:nil
	      contextInfo:nil];
}

- (void)_contentFiltersHaveBeenUpdated:(NSNotification *)notification
{
	// invalidate our OpNode caches
	opNodeCacheVersion++;
	[self _doChangeToRuleEditorData:^{
		//tell the rule editor to reload its criteria
		[filterRuleEditor reloadCriteria];
	}];
}

- (void)_ensureValidOperatorCache:(ColumnNode *)col
{
	if(![col operatorCache] || [col opCacheVersion] != opNodeCacheVersion) {
		NSArray *ops = [self _compareTypesForColumn:col];
		[col setOperatorCache:ops];
		[col setOpCacheVersion:opNodeCacheVersion];
	}
}

- (BOOL)isEmpty
{
	return ([[_modelContainer model] count] == 0);
}

- (void)addFilterExpression
{
	// reject this if no table columns exist: would cause invalid state (empty filter rows)
	if(![columns count]) return;

	[self _doChangeToRuleEditorData:^{
		[filterRuleEditor insertRowAtIndex:0 withType:NSRuleEditorRowTypeSimple asSubrowOfRow:-1 animate:NO];
	}];
}

- (NSRuleEditor *)view
{
	return filterRuleEditor;
}

- (BOOL)isEnabled
{
	return enabled;
}

- (void)setEnabled:(BOOL)_enabled
{
	enabled = _enabled && [columns count] != 0;
	[self _updateButtonStates];
}

- (NSString *)sqlWhereExpressionWithBinary:(BOOL)isBINARY error:(NSError **)err
{
	NSMutableString *filterString = [[NSMutableString alloc] init];
	NSError *innerError = nil;

	@autoreleasepool {
		//get the serialized filter and try to optimise it
		NSDictionary *filterTree = [[self class] _flattenSerializedFilter:[self _serializedFilterIncludingFilterDefinition:YES withDisabled:NO]];

		// build it recursively
		[[self class] _writeFilterTree:filterTree toString:filterString wrapInParenthesis:NO binary:isBINARY error:&innerError];

		[innerError retain]; // carry the error (if any) outside of the scope of the autoreleasepool
	}

	if(innerError) {
		[filterString release];
		if(err) *err = [innerError autorelease];
		return nil;
	}

	if(err) *err = nil;

	NSString *out = [filterString copy];
	[filterString release];

	return [out autorelease];
}

- (NSDictionary *)serializedFilter
{
	return [self _serializedFilterIncludingFilterDefinition:NO withDisabled:YES];
}

- (NSDictionary *)_serializedFilterIncludingFilterDefinition:(BOOL)includeDefinition withDisabled:(BOOL)includeDisabled
{
	NSMutableArray *rootItems = [NSMutableArray arrayWithCapacity:[[_modelContainer model] count]];
	for(NSDictionary *item in [_modelContainer model]) {
		NSDictionary *sub = [self _serializeSubtree:item includingDefinition:includeDefinition withDisabled:includeDisabled];
		_addIfNotNil(rootItems, sub);
	}
	//the root serialized filter can either be an AND of multiple root items or a single root item
	if([rootItems count] == 1) {
		return [rootItems objectAtIndex:0];
	}
	else {
		return @{
			SerFilterClass: SerFilterClassGroup,
			SerFilterGroupIsConjunction: @YES,
			SerFilterGroupChildren: rootItems,
		};
	}
}

- (NSDictionary *)_serializeSubtree:(NSDictionary *)item includingDefinition:(BOOL)includeDefinition withDisabled:(BOOL)includeDisabled
{
	NSRuleEditorRowType rowType = (NSRuleEditorRowType)[[item objectForKey:@"rowType"] unsignedIntegerValue];
	// check if we have an AND or OR compound row
	if(rowType == NSRuleEditorRowTypeCompound) {
		// process all children
		NSArray *subrows = [item objectForKey:@"subrows"];
		NSMutableArray *children = [[NSMutableArray alloc] initWithCapacity:[subrows count]];
		for(NSDictionary *subitem in subrows) {
			NSDictionary *sub = [self _serializeSubtree:subitem includingDefinition:includeDefinition withDisabled:includeDisabled];
			_addIfNotNil(children, sub);
		}
		NSDictionary *out = nil;
		// if we are empty return nil instead (can happen if all children are disabled)
		if([children count]) {
			StringNode *node = [[item objectForKey:@"criteria"] objectAtIndex:1]; //enable state is the result of the children's enable state - not serialized
			BOOL isConjunction = [@"AND" isEqualToString:[node value]];
			out = @{
				SerFilterClass: SerFilterClassGroup,
				SerFilterGroupIsConjunction: @(isConjunction),
				SerFilterGroupChildren: children,
			};
		}
		[children release];
		return out;
	}
	else {
		NSArray *criteria = [item objectForKey:@"criteria"];
		NSArray *displayValues = [item objectForKey:@"displayValues"];
		// 3 == checkbox + column + operator
		if([criteria count] < 3 || [criteria count] != [displayValues count]) {
			return nil;
		}
		BOOL isEnabled = ([(NSButton *)[displayValues objectAtIndex:0] state] == NSOnState);
		if(!isEnabled && !includeDisabled) {
			return nil;
		}
		ColumnNode *col = [criteria objectAtIndex:1];
		OpNode *op = [criteria objectAtIndex:2];
		NSMutableArray *filterValues = [[NSMutableArray alloc] initWithCapacity:2];
		for (NSUInteger i = 3; i < [criteria count]; ++i) { // see above for first three
			if([(RuleNode *)[criteria objectAtIndex:i] type] != RuleNodeTypeArgument) continue;
			// if we found an argument, the displayValue will be an NSTextField we can ask for the value
			NSString *value = [(NSTextField *)[displayValues objectAtIndex:i] stringValue];
			[filterValues addObject:value];
		}
		NSDictionary *out = @{
			SerFilterClass: SerFilterClassExpression,
			SerFilterExprColumn: [col name],
			SerFilterExprType: [[op settings] objectForKey:@"filterType"],
			SerFilterExprComparison: [op name],
			SerFilterExprValues: filterValues,
			SerFilterExprEnabled: @(isEnabled),
		};
		if(includeDefinition) {
			out = [NSMutableDictionary dictionaryWithDictionary:out];
			[(NSMutableDictionary *)out setObject:[op filter] forKey:SerFilterExprDefinition];
		}
		[filterValues release];
		return out;
	}
}

void _addIfNotNil(NSMutableArray *array, id toAdd)
{
	if(toAdd != nil) [array addObject:toAdd];
}

- (void)restoreSerializedFilters:(NSDictionary *)serialized
{
	if(!serialized) return;

	NSMutableArray *newModel = [[NSMutableArray alloc] init];
	@autoreleasepool {
		// if the root object is an AND group directly restore its contents, otherwise restore the object
		if(SerIsGroup(serialized) && [[serialized objectForKey:SerFilterGroupIsConjunction] boolValue]) {
			for(NSDictionary *child in [serialized objectForKey:SerFilterGroupChildren]) {
				_addIfNotNil(newModel, [self _restoreSerializedFilter:child]);
			}
		}
		else {
			_addIfNotNil(newModel, [self _restoreSerializedFilter:serialized]);
		}
	}

	[self _doChangeToRuleEditorData:^{
		// we have to access the model in the same way the rule editor does for it to realize the changes
		NSMutableArray *proxy = [_modelContainer mutableArrayValueForKey:@"model"];
		[proxy setArray:newModel];
	}];

	//finally update all checkboxes
	[self _recalculateCheckboxStatesFromRow:-1];

	[newModel release];
}

- (NSMutableDictionary *)_restoreSerializedFilter:(NSDictionary *)serialized
{
	NSMutableDictionary *obj = [[NSMutableDictionary alloc] initWithCapacity:4];

	if(SerIsGroup(serialized)) {
		[obj setObject:@(NSRuleEditorRowTypeCompound) forKey:@"rowType"];

		//the checkbox state is not important here. that will be updated at the end
		EnableNode *checkbox = [[EnableNode alloc] init];
		[checkbox setAllowsMixedState:YES];

		StringNode *criterion = [[StringNode alloc] init];
		[criterion setValue:([[serialized objectForKey:SerFilterGroupIsConjunction] boolValue] ? @"AND" : @"OR")];
		// those have to be mutable arrays for the rule editor to work
		NSMutableArray *criteria = [NSMutableArray arrayWithArray:@[checkbox,criterion]];
		[obj setObject:criteria forKey:@"criteria"];
		[checkbox release];

		id checkDisplayValue = [self ruleEditor:filterRuleEditor displayValueForCriterion:checkbox inRow:-1];
		id displayValue = [self ruleEditor:filterRuleEditor displayValueForCriterion:criterion inRow:-1];
		NSMutableArray *displayValues = [NSMutableArray arrayWithArray:@[checkDisplayValue,displayValue]];
		[obj setObject:displayValues forKey:@"displayValues"];
		[criterion release];

		NSArray *children = [serialized objectForKey:SerFilterGroupChildren];
		NSMutableArray *subrows = [[NSMutableArray alloc] initWithCapacity:[children count]];
		for(NSDictionary *child in children) {
			_addIfNotNil(subrows, [self _restoreSerializedFilter:child]);
		}
		[obj setObject:subrows forKey:@"subrows"];
		[subrows release];
	}
	else {
		[obj setObject:@(NSRuleEditorRowTypeSimple) forKey:@"rowType"];
		//simple rows can't have child rows
		[obj setObject:[NSMutableArray array] forKey:@"subrows"];

		// 6 == enable checkbox + column + op + first arg + connector + second arg
		NSMutableArray *criteria = [NSMutableArray arrayWithCapacity:6];

		//first look up the column, bail if it doesn't exist anymore or types changed
		NSString *columnName = [serialized objectForKey:SerFilterExprColumn];
		ColumnNode *col = [self _columnForName:columnName];
		if(!col) {
			SPLog(@"cannot deserialize unknown column: %@", columnName);
			goto fail;
		}

		// add enable checkbox
		NSNumber *enabledValue = [serialized objectForKey:SerFilterExprEnabled];
		EnableNode *enabler = [[EnableNode alloc] init];
		// for backwards compatibility. this key was added later
		//                        vvvvvvvvvvvvv
		[enabler setInitialState:(!enabledValue || [enabledValue boolValue])];
		[criteria addObject:[enabler autorelease]];

		// add column
		[criteria addObject:col];

		//next try to find the given operator
		NSString *operatorName = [serialized objectForKey:SerFilterExprComparison];
		OpNode *op = [self _operatorNamed:operatorName forColumn:col];
		if(!op) {
			SPLog(@"cannot deserialize unknown operator: %@",operatorName);
			goto fail;
		}
		[criteria addObject:op];

		// we still have to check if the current column type is the same as when we serialized because an operator
		// with the same name can still act differently for different types
		NSString *curFilterType = [[op settings] objectForKey:@"filterType"];
		NSString *serFilterType = [serialized objectForKey:SerFilterExprType]; // this is optional
		if(serFilterType && ![curFilterType isEqualToString:serFilterType]) {
			SPLog(@"mismatch in filter types for operator %@: current=%@, serialized=%@",op,curFilterType,serFilterType);
			goto fail;
		}

		//now we have to create the argument node(s)
		NSUInteger numOfArgs = [[[op filter] objectForKey:@"NumberOfArguments"] unsignedIntegerValue];
		//fail if the current op requires more arguments than we have stored values for
		NSArray *values = [serialized objectForKey:SerFilterExprValues];
		if(numOfArgs > [values count]) {
			SPLog(@"filter operator %@ requires %ld arguments, but only have %ld stored values!",op,numOfArgs,[values count]);
			goto fail;
		}
		
		// otherwise add them
		for (NSUInteger i = 0; i < numOfArgs; ++i) {
			// insert connector node between args?
			if(i > 0) {
				ConnectorNode *node = [[ConnectorNode alloc] init];
				[node setFilter:[op filter]];
				[node setLabelIndex:(i-1)]; // label 0 follows argument 0
				[criteria addObject:node];
				[node release];
			}
			ArgNode *arg = [[ArgNode alloc] init];
			[arg setArgIndex:i];
			[arg setFilter:[op filter]];
			[arg setInitialValue:[values objectAtIndex:i]];
			[criteria addObject:arg];
			[arg release];
		}
		
		[obj setObject:criteria forKey:@"criteria"];
		
		//the last thing that remains is creating the displayValues for all criteria
		NSMutableArray *displayValues = [NSMutableArray arrayWithCapacity:[criteria count]];
		for(id criterion in criteria) {
			id dispValue = [self ruleEditor:filterRuleEditor displayValueForCriterion:criterion inRow:-1];
			if(!dispValue) {
				SPLog(@"got nil displayValue for criterion %@ on deserialization!",criterion);
				goto fail;
			}
			[displayValues addObject:dispValue];
		}
		[obj setObject:displayValues forKey:@"displayValues"];
	}

	return [obj autorelease];

fail:
	[obj release];
	return nil;
}

+ (NSDictionary *)makeSerializedFilterForColumn:(NSString *)colName operator:(NSString *)opName values:(NSArray *)values
{
	return @{
		SerFilterClass:          SerFilterClassExpression,
		SerFilterExprColumn:     colName,
		SerFilterExprComparison: opName,
		SerFilterExprValues:     values,
		SerFilterExprEnabled:    @YES,
	};
}

- (ColumnNode *)_columnForName:(NSString *)name
{
	if([name length]) {
		for (ColumnNode *col in columns) {
			if ([name isEqualToString:[col name]]) return col;
		}
	}
	return nil;
}

- (OpNode *)_operatorNamed:(NSString *)title forColumn:(ColumnNode *)col
{
	if([title length]) {
		// check if we have the operator cache, otherwise build it
		[self _ensureValidOperatorCache:col];
		// try to find it in the operator cache
		for(OpNode *node in [col operatorCache]) {
			if([[node name] isEqualToString:title]) return node;
		}
	}
	return nil;
}

BOOL SerIsGroup(NSDictionary *dict)
{
	return [SerFilterClassGroup isEqual:[dict objectForKey:SerFilterClass]];
}

/**
 * This method looks at the given serialized filter in a recursive manner and
 * when it encounters
 * - a group node with only a single child or
 * - a child that is a group node of the same kind as the parent one
 * it will pull the child(ren) up
 *
 * So for example:
 *   AND(expr1)                  => expr1
 *   AND(expr1,AND(expr2,expr3)) => AND(expr1,expr2,expr3)
 *
 * The input dict is not modified, the returned dict will be equal to the input
 * dict or have parts of it removed or replaced with new dicts.
 */
+ (NSDictionary *)_flattenSerializedFilter:(NSDictionary *)in
{
	// return non-group-nodes as is
	if(!SerIsGroup(in)) return in;

	NSNumber *inIsConjunction = [in objectForKey:SerFilterGroupIsConjunction];

	// first give all children the chance to flatten (depth first)
	NSArray *children = [in objectForKey:SerFilterGroupChildren];
	NSMutableArray *flatChildren = [NSMutableArray arrayWithCapacity:[children count]];
	NSUInteger changed = 0;
	for(NSDictionary *child in children) {
		NSDictionary *flattened = [self _flattenSerializedFilter:child];
		//take a closer look at the (possibly changed) child - is it a group node of the same kind as us?
		if(SerIsGroup(flattened) && [inIsConjunction isEqual:[flattened objectForKey:SerFilterGroupIsConjunction]]) {
			[flatChildren addObjectsFromArray:[flattened objectForKey:SerFilterGroupChildren]];
			changed++;
			continue;
		}
		else if(flattened != child) {
			changed++;
		}
		[flatChildren addObject:flattened];
	}
	// if there is only a single child, return it (flattening)
	if([flatChildren count] == 1) return [flatChildren objectAtIndex:0];
	// if none of the children changed return the original input
	if(!changed) return in;
	// last variant: some of our children changed, but we remain
	return @{
		SerFilterClass: SerFilterClassGroup,
		SerFilterGroupIsConjunction: inIsConjunction,
		SerFilterGroupChildren: flatChildren
	};
}

+ (void)_writeFilterTree:(NSDictionary *)in toString:(NSMutableString *)out wrapInParenthesis:(BOOL)wrap binary:(BOOL)isBINARY error:(NSError **)err
{
	NSError *myErr = nil;
	
	if(wrap) [out appendString:@"("];
	
	if(SerIsGroup(in)) {
		BOOL isConjunction = [[in objectForKey:SerFilterGroupIsConjunction] boolValue];
		NSString *connector = isConjunction ? @"AND" : @"OR";
		BOOL first = YES;
		NSArray *children = [in objectForKey:SerFilterGroupChildren];
		for(NSDictionary *child in children) {
			if(!first) [out appendFormat:@" %@ ",connector];
			else first = NO;
			// if the child is a group node but of a different kind we want to wrap it in order to prevent operator precedence confusion
			// expression children will always be wrapped for clarity, except if there is only a single one and we are already wrapped
			BOOL wrapChild = YES;
			if(SerIsGroup(child)) {
				BOOL childIsConjunction = [[child objectForKey:SerFilterGroupIsConjunction] boolValue];
				if(isConjunction == childIsConjunction) wrapChild = NO;
			}
			else {
				if(wrap && [children count] == 1) wrapChild = NO;
			}
			[self _writeFilterTree:child toString:out wrapInParenthesis:wrapChild binary:isBINARY error:&myErr];
			if(myErr) {
				if(err) *err = myErr;
				return;
			}
		}
	}
	else {
		// finally - build a SQL filter expression
		NSDictionary *filter = [in objectForKey:SerFilterExprDefinition];
		if(!filter) {
			if(err) *err = [NSError errorWithDomain:SPErrorDomain code:0 userInfo:@{
				NSLocalizedDescriptionKey: NSLocalizedString(@"Fatal error while retrieving content filter. No filter definition found.", @"filter to sql conversion : internal error : 0"),
			}];
			return;
		}

		if(![filter objectForKey:@"NumberOfArguments"]) {
			if(err) *err = [NSError errorWithDomain:SPErrorDomain code:1 userInfo:@{
				NSLocalizedDescriptionKey: NSLocalizedString(@"Error while retrieving filter clause. No “NumberOfArguments” key found.", @"filter to sql conversion : internal error : invalid filter definition (1)"),
			}];
			return;
		}

		if(![filter objectForKey:@"Clause"] || ![(NSString *)[filter objectForKey:@"Clause"] length]) {
			if(err) *err = [NSError errorWithDomain:SPErrorDomain code:2 userInfo:@{
				NSLocalizedDescriptionKey: NSLocalizedString(@"Content Filter clause is empty.", @"filter to sql conversion : internal error : invalid filter definition (2)"),
			}];
			return;
		}

		NSArray *values = [in objectForKey:SerFilterExprValues];

		SPTableFilterParser *parser = [[SPTableFilterParser alloc] initWithFilterClause:[filter objectForKey:@"Clause"]
		                                                              numberOfArguments:[[filter objectForKey:@"NumberOfArguments"] integerValue]];
		[parser setArgument:[values objectOrNilAtIndex:0]];
		[parser setFirstBetweenArgument:[values objectOrNilAtIndex:0]];
		[parser setSecondBetweenArgument:[values objectOrNilAtIndex:1]];
		[parser setSuppressLeadingTablePlaceholder:[[filter objectForKey:@"SuppressLeadingFieldPlaceholder"] boolValue]];
		[parser setCaseSensitive:isBINARY];
		[parser setCurrentField:[in objectForKey:SerFilterExprColumn]];

		NSString *sql = [parser filterString];
		// SPTableFilterParser will return nil if it doesn't like the arguments and NSMutableString doesn't like nil
		if(!sql) {
			if(err) *err = [NSError errorWithDomain:SPErrorDomain code:3 userInfo:@{
				NSLocalizedDescriptionKey: NSLocalizedString(@"No valid SQL expression could be generated. Perhaps the filter definition is invalid.", @"filter to sql conversion : internal error : SPTableFilterParser failed"),
			}];
			[parser release];
			return;
		}
		[out appendString:sql];

		[parser release];
	}
	
	if(wrap) [out appendString:@")"];
}

- (void)_doChangeToRuleEditorData:(void (^)(void))duringBlock
{
	@try {
		isDoingChangeCausedOutsideOfRuleEditor = YES;
		duringBlock();
	}
	@finally {
		isDoingChangeCausedOutsideOfRuleEditor = NO;
	}
}

@end

#pragma mark -

@implementation RuleNode

@synthesize type = type;

- (NSUInteger)hash {
	return type;
}

- (BOOL)isEqual:(id)other {
	if (other == self) return YES;
	if (other && [[other class] isEqual:[self class]] && [(RuleNode *)other type] == type) return YES;

	return NO;
}

- (BOOL)isViableReplacementFor:(RuleNode *)other
{
	return [other type] == type;
}

@end

@implementation ColumnNode

@synthesize name = name;
@synthesize typegrouping = typegrouping;
@synthesize operatorCache = operatorCache;
@synthesize opCacheVersion = opCacheVersion;

- (instancetype)init
{
	if((self = [super init])) {
		type = RuleNodeTypeColumn;
		opCacheVersion = 0;
	}
	return self;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"ColumnNode<%@@%p>",[self name],self];
}

- (NSUInteger)hash {
	return ([name hash] ^ [typegrouping hash] ^ [super hash]);
}

- (BOOL)isEqual:(id)other {
	if (other == self) return YES;
	if (other && [[other class] isEqual:[self class]] && [name isEqualToString:[other name]] && [typegrouping isEqualToString:[other typegrouping]]) return YES;

	return NO;
}

@end

@implementation StringNode

@synthesize value = value;

- (instancetype)init
{
	if((self = [super init])) {
		type = RuleNodeTypeString;
	}
	return self;
}

- (NSUInteger)hash {
	return ([value hash] ^ [super hash]);
}

- (BOOL)isEqual:(id)other {
	if (other == self) return YES;
	if (other && [[other class] isEqual:[self class]] && [value isEqualToString:[(StringNode *)other value]]) return YES;

	return NO;
}

@end

@implementation OpNode

@synthesize parentColumn = parentColumn;
@synthesize settings = settings;
@synthesize filter = filter;

- (instancetype)init
{
	if((self = [super init])) {
		type = RuleNodeTypeOperator;
	}
	return self;
}

- (void)dealloc
{
	[self setFilter:nil];
	[self setSettings:nil];
	[super dealloc];
}

- (NSUInteger)hash {
	return (([parentColumn hash] << 16) ^ [settings hash] ^ [super hash]);
}

- (BOOL)isEqual:(id)other {
	if (other == self) return YES;
	if (other && [[other class] isEqual:[self class]] && [settings isEqualToDictionary:[(OpNode *)other settings]] && [parentColumn isEqual:[other parentColumn]]) return YES;

	return NO;
}

- (BOOL)isViableReplacementFor:(RuleNode *)other {
	return [super isViableReplacementFor:other] && [parentColumn isEqual:[(OpNode *)other parentColumn]];
}

- (NSString *)name
{
	return [filter objectForKey:@"MenuLabel"];
}

@end

@implementation ArgNode

@synthesize filter = filter;
@synthesize argIndex = argIndex;
@synthesize initialValue = initialValue;

- (instancetype)init
{
	if((self = [super init])) {
		type = RuleNodeTypeArgument;
	}
	return self;
}

- (void)dealloc
{
	[self setInitialValue:nil];
	[self setFilter:nil];
	[super dealloc];
}

- (NSUInteger)hash {
	// initialValue does not count towards hash because two Args are not different if only the initialValue differs
	return ((argIndex << 16) ^ [filter hash] ^ [super hash]);
}

- (BOOL)isEqual:(id)other {
	// initialValue does not count towards isEqual: because two Args are not different if only the initialValue differs
	if (other == self) return YES;
	if (other && [[other class] isEqual:[self class]] && [filter isEqualToDictionary:[(ArgNode *)other filter]] && argIndex == [(ArgNode *)other argIndex]) return YES;

	return NO;
}

- (BOOL)isViableReplacementFor:(RuleNode *)other {
	return [super isViableReplacementFor:other] && [(ArgNode *)other argIndex] == argIndex;
}

@end

@implementation ConnectorNode

@synthesize filter = filter;
@synthesize labelIndex = labelIndex;

- (instancetype)init
{
	if((self = [super init])) {
		type = RuleNodeTypeConnector;
	}
	return self;
}

- (void)dealloc
{
	[self setFilter:nil];
	[super dealloc];
}

- (NSUInteger)hash {
	return ((labelIndex << 16) ^ [filter hash] ^ [super hash]);
}

- (BOOL)isEqual:(id)other {
	if (other == self) return YES;
	if (other && [[other class] isEqual:[self class]] && [filter isEqualToDictionary:[(ConnectorNode *)other filter]] && labelIndex == [(ConnectorNode *)other labelIndex]) return YES;

	return NO;
}

@end

@implementation EnableNode

@synthesize initialState = initialState;
@synthesize allowsMixedState = allowsMixedState;

- (instancetype)init {
	self = [super init];
	if (self) {
		type = RuleNodeTypeEnable;
		initialState = YES;
		allowsMixedState = NO;
	}
	return self;
}

- (NSUInteger)hash {
	return (([super hash] << 2) | (initialState << 1) | allowsMixedState);
}

- (BOOL)isEqual:(id)other {
	if (other == self) return YES;
	if (other && [[other class] isEqual:[self class]] && [self initialState] == [(EnableNode *)other initialState] && [self allowsMixedState] == [(EnableNode *)other allowsMixedState]) return YES;

	return NO;
}

@end

#pragma mark -

@implementation ModelContainer

@synthesize model = model;

- (instancetype)init
{
	if (self = [super init]) {
		model = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[self setModel:nil];
	[super dealloc];
}

// KVO

- (void)insertObject:(id)obj inModelAtIndex:(NSUInteger)idx
{
	[model insertObject:obj atIndex:idx];
}

- (void)removeObjectFromModelAtIndex:(NSUInteger)idx
{
	[model removeObjectAtIndex:idx];
}

- (void)insertModel:(NSArray *)array atIndexes:(NSIndexSet *)indexes
{
	[model insertObjects:array atIndexes:indexes];
}

- (void)removeModelAtIndexes:(NSIndexSet *)indexes
{
	[model removeObjectsAtIndexes:indexes];
}

@end
