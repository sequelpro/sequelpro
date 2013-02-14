//
//  $Id$
//
//  SPTableContentFilter.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on August 14, 2012.
//  Copyright (c) 2012 Stuart Connolly. All rights reserved.
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

#import "SPTableContentFilter.h"
#import "RegexKitLite.h"
#import "SPCopyTable.h"

@implementation SPTableContent (SPTableContentFilter)

#ifndef SP_CODA

/**
 * Escape passed operator for usage as filterTableDefaultOperator.
 */
- (NSString*)escapeFilterTableDefaultOperator:(NSString *)operator
{
	if (!operator) return @"";
	
	NSMutableString *newOp = [[[NSMutableString alloc] initWithCapacity:[operator length]] autorelease];
	
	[newOp setString:operator];
	[newOp replaceOccurrencesOfRegex:@"%" withString:@"%%"];
	[newOp replaceOccurrencesOfRegex:@"(?<!`)@(?!=`)" withString:@"%@"];
	
	return newOp;
}

/**
 * Update WHERE clause in filter table window.
 *
 * @param currentValue If currentValue == nil take the data from filterTableData, if currentValue == filterTableSearchAllFields
 * generate a WHERE clause to search in all given fields, if currentValue == a string take this string as table cell data of the
 * currently edited table cell
 */
- (void)updateFilterTableClause:(id)currentValue
{
	NSMutableString *clause  = [NSMutableString string];
	NSInteger numberOfRows   = [self numberOfRowsInTableView:filterTableView];
	NSInteger numberOfCols   = [[filterTableView tableColumns] count];
	NSInteger numberOfValues = 0;
	NSRange opRange, defopRange;
	
	BOOL lookInAllFields = NO;
	
	NSString *re1 = @"^\\s*(<[=>]?|>=?|!?=|≠|≤|≥)\\s*(.*?)\\s*$";
	NSString *re2 = @"^\\s*(.*)\\s+(.*?)\\s*$";
	
	NSInteger editedRow = [filterTableView editedRow];
	
	if (currentValue == filterTableSearchAllFields) {
		numberOfRows = 1;
		lookInAllFields = YES;
	}
	
	[filterTableWhereClause setString:@""];
	
	for (NSInteger i = 0; i < numberOfRows; i++) 
	{
		numberOfValues = 0;
		
		for (NSInteger anIndex = 0; anIndex < numberOfCols; anIndex++) 
		{
			NSString *filterCell;
			NSDictionary *filterCellData = [NSDictionary dictionaryWithDictionary:[filterTableData objectForKey:[NSString stringWithFormat:@"%d", anIndex]]];
			
			// Take filterTableData
			if (!currentValue) {
				filterCell = NSArrayObjectAtIndex([filterCellData objectForKey:SPTableContentFilterKey], i);
			}
			// Take last edited value to create the OR clause
			else if (lookInAllFields) {
				if (lastEditedFilterTableValue && [lastEditedFilterTableValue length]) {
					filterCell = lastEditedFilterTableValue;
				} 
				else {
					[filterTableWhereClause setString:@""];
					[filterTableWhereClause insertText:@""];
					[filterTableWhereClause scrollRangeToVisible:NSMakeRange(0, 0)];
					
					// If live search is set perform filtering
					if ([filterTableLiveSearchCheckbox state] == NSOnState) {
						[self filterTable:filterTableFilterButton];
					}
				}
			} 
			// Take value from currently edited table cell
			else if ([currentValue isKindOfClass:[NSString class]]) {
				if (i == editedRow && anIndex == [[NSArrayObjectAtIndex([filterTableView tableColumns], [filterTableView editedColumn]) identifier] integerValue]) {
					filterCell = (NSString*)currentValue;
				}
				else {
					filterCell = NSArrayObjectAtIndex([filterCellData objectForKey:SPTableContentFilterKey], i);
				}
			}
			
			if ([filterCell length]) {
				
				// Recode special operators
				filterCell = [filterCell stringByReplacingOccurrencesOfRegex:@"^\\s*≠" withString:@"!="];
				filterCell = [filterCell stringByReplacingOccurrencesOfRegex:@"^\\s*≤" withString:@"<="];
				filterCell = [filterCell stringByReplacingOccurrencesOfRegex:@"^\\s*≥" withString:@">="];
				
				if (numberOfValues) {
					[clause appendString:(lookInAllFields) ? @" OR " : @" AND "];
				}
				
				NSString *fieldName = [[filterCellData objectForKey:@"name"] backtickQuotedString];
				NSString *filterTableDefaultOperatorWithFieldName = [filterTableDefaultOperator stringByReplacingOccurrencesOfString:@"`@`" withString:fieldName];
				
				opRange = [filterCell rangeOfString:@"`@`"];
				defopRange = [filterTableDefaultOperator rangeOfString:@"`@`"];
				
				// if cell data begins with ' or " treat it as it is
				// by checking if default operator by itself contains a ' or " - if so
				// remove first and if given the last ' or "
				if ([filterCell isMatchedByRegex:@"^\\s*['\"]"]) {
					if ([filterTableDefaultOperator isMatchedByRegex:@"['\"]"]) {
						NSArray *matches = [filterCell arrayOfCaptureComponentsMatchedByRegex:@"^\\s*(['\"])(.*)\\1\\s*$"];
						
						if ([matches count] && [matches = NSArrayObjectAtIndex(matches, 0) count] == 3) {
							[clause appendFormat:[NSString stringWithFormat:@"%%@ %@", filterTableDefaultOperatorWithFieldName], fieldName, NSArrayObjectAtIndex(matches, 2)];
						} 
						else {
							matches = [filterCell arrayOfCaptureComponentsMatchedByRegex:@"^\\s*(['\"])(.*)\\s*$"];
							
							if ([matches count] && [matches = NSArrayObjectAtIndex(matches, 0) count] == 3) {
								[clause appendFormat:[NSString stringWithFormat:@"%%@ %@", filterTableDefaultOperatorWithFieldName], fieldName, NSArrayObjectAtIndex(matches, 2)];
							}
						}
					} 
					else {
						[clause appendFormat:[NSString stringWithFormat:@"%%@ %@", filterTableDefaultOperatorWithFieldName], fieldName, filterCell];
					}
				}
				// If cell contains the field name placeholder
				else if (opRange.length || defopRange.length) {
					filterCell = [filterCell stringByReplacingOccurrencesOfString:@"`@`" withString:fieldName];
					
					if (defopRange.length) {
						[clause appendFormat:filterTableDefaultOperatorWithFieldName, [filterCell stringByReplacingOccurrencesOfString:@"`@`" withString:fieldName]];
					}
					else {
						[clause appendString:[filterCell stringByReplacingOccurrencesOfString:@"`@`" withString:fieldName]];
					}
				}
				// If cell is equal to NULL
				else if ([filterCell isMatchedByRegex:@"(?i)^\\s*null\\s*$"]) {
					[clause appendFormat:@"%@ IS NULL", fieldName];
				}
				// If cell starts with an operator
				else if ([filterCell isMatchedByRegex:re1]) {
					NSArray *matches = [filterCell arrayOfCaptureComponentsMatchedByRegex:re1];
					
					if ([matches count] && [matches = NSArrayObjectAtIndex(matches, 0) count] == 3) {
						[clause appendFormat:@"%@ %@ %@", fieldName, NSArrayObjectAtIndex(matches, 1), NSArrayObjectAtIndex(matches, 2)];
					}
				}
				// If cell consists of at least two words treat the first as operator and the rest as argument
				else if ([filterCell isMatchedByRegex:re2]) {
					NSArray *matches = [filterCell arrayOfCaptureComponentsMatchedByRegex:re2];
					
					if ([matches count] && [matches = NSArrayObjectAtIndex(matches,0) count] == 3) {
						[clause appendFormat:@"%@ %@ %@", fieldName, [NSArrayObjectAtIndex(matches, 1) uppercaseString], NSArrayObjectAtIndex(matches, 2)];
					}
				}
				// Apply the default operator
				else {
					[clause appendFormat:[NSString stringWithFormat:@"%%@ %@", filterTableDefaultOperatorWithFieldName], fieldName, filterCell];
				}
				
				numberOfValues++;
			}
		}
		
		if (numberOfValues) {
			[clause appendString:@"\nOR\n"];
		}
	}
	
	// Remove last " OR " if any
	[filterTableWhereClause setString:[clause length] > 3 ? [clause substringToIndex:([clause length] - 4)] : @""];
	
	// Update syntax highlighting and uppercasing
	[filterTableWhereClause insertText:@""];
	[filterTableWhereClause scrollRangeToVisible:NSMakeRange(0, 0)];
	
	// If live search is set perform filtering
	if ([filterTableLiveSearchCheckbox state] == NSOnState) {
		[self filterTable:filterTableFilterButton];
	}
}

/**
 * Makes the content filter field have focus by making it the first responder.
 */
- (void)makeContentFilterHaveFocus
{
	NSDictionary *filter = [[contentFilters objectForKey:compareType] objectAtIndex:[[compareField selectedItem] tag]];
	
	if ([filter objectForKey:@"NumberOfArguments"]) {
		
		NSUInteger numOfArgs = [[filter objectForKey:@"NumberOfArguments"] integerValue];
		
		switch (numOfArgs) 
		{
			case 2:
				[[firstBetweenField window] makeFirstResponder:firstBetweenField];
				break;
			case 1:
				[[argumentField window] makeFirstResponder:argumentField];
				break;
			default:
				[[compareField window] makeFirstResponder:compareField];
		}
	}
}

#endif

@end
