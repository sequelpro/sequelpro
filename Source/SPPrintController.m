//
//  $Id$
//
//  SPPrintController.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on March 11, 2010
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
//  More info at <http://code.google.com/p/sequel-pro/>

#import "SPPrintController.h"
#import "TableContent.h"
#import "TableSource.h"
#import "CustomQuery.h"
#import "SPConstants.h"
#import "SPTableRelations.h"
#import "SPPrintAccessory.h"
#import "MGTemplateEngine.h"
#import "ICUTemplateMatcher.h"
#import "SPConnectionController.h"

@implementation TableDocument (SPPrintController)

/**
 * WebView delegate method.
 */
- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame 
{
	// Because we need the webFrame loaded (for preview), we've moved the actual printing here
	NSPrintInfo *printInfo = [self printInfo];
	
	[printInfo setHorizontalPagination:NSFitPagination];
	[printInfo setVerticalPagination:NSAutoPagination];
	[printInfo setVerticallyCentered:NO];
	[printInfo setTopMargin:30];
	[printInfo setBottomMargin:30];
	[printInfo setLeftMargin:10];
	[printInfo setRightMargin:10];
	
	NSPrintOperation *op = [NSPrintOperation printOperationWithView:[[[printWebView mainFrame] frameView] documentView] printInfo:printInfo];
	
	// Add the ability to select the orientation to print panel
	NSPrintPanel *printPanel = [op printPanel];
	
	[printPanel setOptions:[printPanel options] + NSPrintPanelShowsOrientation + NSPrintPanelShowsScaling + NSPrintPanelShowsPaperSize];
	
	SPPrintAccessory *printAccessory = [[SPPrintAccessory alloc] initWithNibName:@"PrintAccessory" bundle:nil];
	
	[printAccessory setPrintView:printWebView];
	[printPanel addAccessoryController:printAccessory];
		
	[[NSPageLayout pageLayout] addAccessoryController:printAccessory];
    [printAccessory release];
	
	[op setPrintPanel:printPanel];
	
    [op runOperationModalForWindow:tableWindow
						  delegate:self
					didRunSelector:nil
					   contextInfo:nil];
	
}

/**
 * Loads the print document interface. The actual printing is done in the doneLoading delegate.
 */
- (IBAction)printDocument:(id)sender
{
	[[printWebView mainFrame] loadHTMLString:[self generateHTMLforPrinting] baseURL:nil];
}


/**
 * Generates the HTML for the current view that is being printed.
 */
- (NSString *)generateHTMLforPrinting
{
	// Set up template engine with your chosen matcher
	MGTemplateEngine *engine = [MGTemplateEngine templateEngine];
	
	[engine setMatcher:[ICUTemplateMatcher matcherWithTemplateEngine:engine]];
	
	NSString *versionForPrint = [NSString stringWithFormat:@"%@ %@ (build %@)",
								 [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"],
								 [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"],
								 [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]
								 ];
	
	NSMutableDictionary *connection = [[NSMutableDictionary alloc] init];
	
	if ([[self user] length]) {
		[connection setValue:[self user] forKey:@"username"];
	}	
	
	if ([[self table] length]) {
		[connection setValue:[self table] forKey:@"table"];
	}
	
	
	if ([connectionController port] && [[connectionController port] length]) {
		[connection setValue:[connectionController port] forKey:@"port"];
	}
	
	[connection setValue:[self host] forKey:@"hostname"];
	[connection setValue:selectedDatabase forKey:@"database"];
	[connection setValue:versionForPrint forKey:@"version"];
	
	NSString *title = @"";
	NSArray *rows, *indexes, *indexColumns = nil;
	NSArray *columns = [self columnNames];
	
	NSMutableDictionary *printData = [NSMutableDictionary dictionary];
	
	// Table source view
	if ([tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == 0) {
		
		NSDictionary *tableSource = [tableSourceInstance tableSourceForPrinting];
		
		if ([[tableSource objectForKey:@"structure"] count] > 1) {
			
			title = @"Table Structure";
			
			rows = [[NSArray alloc] initWithArray:
					[[tableSource objectForKey:@"structure"] objectsAtIndexes:
					 [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, [[tableSource objectForKey:@"structure"] count] - 1)]
					 ]
					];
		
			indexes = [[NSArray alloc] initWithArray:
				   [[tableSource objectForKey:@"indexes"] objectsAtIndexes:
					[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, [[tableSource objectForKey:@"indexes"] count] - 1)]
					]
				   ];
		
			indexColumns = [[tableSource objectForKey:@"indexes"] objectAtIndex:0];
			
			[printData setObject:indexes forKey:@"indexes"];
			[printData setObject:indexColumns forKey:@"indexColumns"];
		}
	}
	// Table content view
	else if ([tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == 1) {
		if ([[tableContentInstance currentResult] count] > 1) {
			
			title = @"Table Content";
			
			rows = [[NSArray alloc] initWithArray:
					[[tableContentInstance currentDataResult] objectsAtIndexes:
					 [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, [[tableContentInstance currentResult] count] - 1)]
					 ]
					];
		
			[connection setValue:[tableContentInstance usedQuery] forKey:@"query"];
		}
	}
	// Custom query view
	else if ([tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == 2) {
		if ([[customQueryInstance currentResult] count] > 1) {
			
			title = @"Query Result";
			
			rows = [[NSArray alloc] initWithArray:
					[[customQueryInstance currentResult] objectsAtIndexes:
					 [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, [[customQueryInstance currentResult] count] - 1)]
					 ]
					];
		
			[connection setValue:[customQueryInstance usedQuery] forKey:@"query"];
		}
	}
	// Table relations view
	else if ([tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == 4) {
		if ([[tableRelationsInstance relationDataForPrinting] count] > 1) {
			
			title = @"Table Relations";
			
			NSArray *data = [tableRelationsInstance relationDataForPrinting];
			
			rows = [[NSArray alloc] initWithArray:
					[data objectsAtIndexes:
					 [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, ([data count] - 1))]
					 ]
					];
		}
	}
		
	[engine setObject:connection forKey:@"c"];
	
	[printData setObject:title forKey:@"title"];
	[printData setObject:columns forKey:@"columns"];
	[printData setObject:rows forKey:@"rows"]; 
	[printData setObject:([prefs boolForKey:SPUseMonospacedFonts]) ? SPDefaultMonospacedFontName : @"Lucida Grande" forKey:@"font"];
	
    [connection release];
	
    if (rows) [rows release];
	
	// Process the template and display the results.
	NSString *result = [engine processTemplateInFileAtPath:[[NSBundle mainBundle] pathForResource:SPHTMLPrintTemplate ofType:@"html"] withVariables:printData];
	
	return result;
}

/**
 * Returns an array of columns for whichever view is being printed.
 */
- (NSArray *)columnNames
{
	NSArray *columns = nil;
	
	// Table source view
	if ([tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == 0
		&& [[tableSourceInstance tableSourceForPrinting] count] > 0 ) {
		
		columns = [[NSArray alloc] initWithArray:[[[tableSourceInstance tableSourceForPrinting] objectForKey:@"structure"] objectAtIndex:0] copyItems:YES];
	}
	// Table content view
	else if ([tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == 1
			 && [[tableContentInstance currentResult] count] > 0 ) {
		
		columns = [[NSArray alloc] initWithArray:[[tableContentInstance currentResult] objectAtIndex:0] copyItems:YES];
	}
	// Custom query view
	else if ([tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == 2
			 && [[customQueryInstance currentResult] count] > 0 ) {
		
		columns = [[NSArray alloc] initWithArray:[[customQueryInstance currentResult] objectAtIndex:0] copyItems:YES];
	}
	// Table relations view
	else if ([tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == 4
			 && [[tableRelationsInstance relationDataForPrinting] count] > 0 ) {
				
		columns = [[NSArray alloc] initWithArray:[[tableRelationsInstance relationDataForPrinting] objectAtIndex:0] copyItems:YES];
	}
	
	if (columns) [columns autorelease];
	
	return columns;
}

@end
