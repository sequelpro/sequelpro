//
//  $Id$
//
//  SPExportController.h
//  sequel-pro
//
//  Created by Ben Perry (benperry.com.au) on 21/02/09.
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

#import <Cocoa/Cocoa.h>
#import <MCPKit/MCPKit.h>

#import "SPExporterDataAccess.h"

#import "SPLogger.h"

@interface SPExportController : NSObject <SPExporterDataAccess>
{	
	// Table document
	IBOutlet id tableDocumentInstance;
	IBOutlet id tableWindow;
	
	// Tables list
	IBOutlet id tablesListInstance;
	
	// Table data
	IBOutlet id tableDataInstance;
	
	// Export window
	IBOutlet id exportWindow;
	IBOutlet id exportToolbar;
	IBOutlet id exportPathField;
	IBOutlet id	exportTableList;
	IBOutlet id exportTabBar;	
	IBOutlet id exportInputMatrix;
	IBOutlet id exportFilePerTableCheck;
	IBOutlet id exportFilePerTableNote;
	IBOutlet id exportProcessLowMemory;
	
	// Export progress sheet
	IBOutlet id exportProgressWindow;
	IBOutlet id exportProgressTitle;
	IBOutlet id exportProgressText;
	IBOutlet id exportProgressIndicator;
	
	// SQL
	IBOutlet id exportSQLIncludeStructureCheck;
	IBOutlet id exportSQLIncludeDropSyntaxCheck;
	IBOutlet id exportSQLIncludeErrorsCheck;
	
	// Excel
	IBOutlet id exportExcelSheetOrFilePerTableMatrix;
	
	// CSV
	IBOutlet id exportCSVIncludeFieldNamesCheck;
    IBOutlet id exportCSVFieldsTerminatedField;
    IBOutlet id exportCSVFieldsWrappedField;
    IBOutlet id exportCSVFieldsEscapedField;
    IBOutlet id exportCSVLinesTerminatedField;
	
	// HTML
	IBOutlet id exportHTMLIncludeStructureCheck;
	IBOutlet id exportHTMLIncludeHeadAndBodyTagsCheck;
	
	// XML
	IBOutlet id exportXMLIncludeStructureCheck;
	
	// PDF
	IBOutlet id exportPDFIncludeStructureCheck;
	
	// Token name view
	IBOutlet id tokenNameView;
	IBOutlet id tokenNameField;
	IBOutlet id tokenNameTokensField;
	IBOutlet id exampleNameLabel;
	
	// Cancellation flag
	BOOL exportCancelled;
	
	// Current database's tables
	NSMutableArray *tables;
	
	// Database connection
	MCPConnection *connection;
	
	// Concurrent operation queue
	NSOperationQueue *operationQueue;
	
	// Table/export operation mapping 
	NSMutableDictionary *tableExportMapping;
	
}

@property (readwrite, assign) BOOL exportCancelled;
@property (readwrite, assign) MCPConnection *connection;

// IB action methods
- (void)export;
- (IBAction)closeSheet:(id)sender;
- (IBAction)switchTab:(id)sender;
- (IBAction)switchInput:(id)sender;
- (IBAction)cancelExport:(id)sender;
- (IBAction)changeExportOutputPath:(id)sender;

@end
