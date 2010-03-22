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

#import "SPConstants.h"

@interface SPExportController : NSObject
{	
	// Controllers
	id tableDocumentInstance;
	id tableContentInstance;
	id customQueryInstance;
	id tableDataInstance;
	
	// Connection window
	IBOutlet NSWindow *tableWindow;
	
	// Export window
	IBOutlet NSWindow *exportWindow;
	IBOutlet NSToolbar *exportToolbar;
	IBOutlet NSTextField *exportPathField;
	IBOutlet NSTableView *exportTableList;
	IBOutlet NSTabView *exportTabBar;	
	IBOutlet NSMatrix *exportInputMatrix;
	IBOutlet NSButton *exportFilePerTableCheck;
	IBOutlet NSTextField *exportFilePerTableNote;
	IBOutlet NSButton *exportUseUTF8BOM;
	IBOutlet NSButton *exportProcessLowMemory;
	IBOutlet NSButton *exportSelectAllTablesButton;
	IBOutlet NSButton *exportDeselectAllTablesButton;
	IBOutlet NSButton *exportRefreshTablesButton;
	
	// Export progress sheet
	IBOutlet NSWindow *exportProgressWindow;
	IBOutlet NSTextField *exportProgressTitle;
	IBOutlet NSTextField *exportProgressText;
	IBOutlet NSProgressIndicator *exportProgressIndicator;
	
	// SQL
	IBOutlet NSButton *exportSQLIncludeStructureCheck;
	IBOutlet NSButton *exportSQLIncludeDropSyntaxCheck;
	IBOutlet NSButton *exportSQLIncludeCreateSyntaxCheck;
	IBOutlet NSButton *exportSQLIncludeErrorsCheck;
	
	// Excel
	IBOutlet NSMatrix *exportExcelSheetOrFilePerTableMatrix;
	
	// CSV
	IBOutlet NSButton *exportCSVIncludeFieldNamesCheck;
    IBOutlet NSComboBox *exportCSVFieldsTerminatedField;
    IBOutlet NSComboBox *exportCSVFieldsWrappedField;
    IBOutlet NSComboBox *exportCSVFieldsEscapedField;
    IBOutlet NSComboBox *exportCSVLinesTerminatedField;
	
	// HTML
	IBOutlet NSButton *exportHTMLIncludeStructureCheck;
	IBOutlet NSButton *exportHTMLIncludeHeadAndBodyTagsCheck;
	
	// XML
	IBOutlet NSButton *exportXMLIncludeStructureCheck;
	
	// PDF
	IBOutlet NSButton *exportPDFIncludeStructureCheck;
	
	// Token name view
	IBOutlet id tokenNameView;
	IBOutlet id tokenNameField;
	IBOutlet id tokenNameTokensField;
	IBOutlet id exampleNameLabel;
	
	// Cancellation flag
	BOOL exportCancelled;
	
	// Multi-file export flag
	BOOL exportToMultipleFiles;
	
	// Number of tables being exported
	NSUInteger exportTableCount;
	
	// Index of the current table being exported
	NSUInteger currentTableExportIndex;
	
	// Export type label
	NSString *exportTypeLabel;
	
	// Current database's tables
	NSMutableArray *tables;
	
	// Database connection
	MCPConnection *connection;
	
	// Concurrent operation queue
	NSOperationQueue *operationQueue;
	
	// Exporters 
	NSMutableArray *exporters;
	
	// Global export file handle
	NSFileHandle *exportFileHandle;
	
	// Export options
	SPExportType exportType;
	SPExportSource exportSource;
}

@property (assign) id tableDocumentInstance;
@property (assign) id tableContentInstance;
@property (assign) id customQueryInstance;
@property (assign) id tableDataInstance;

@property (readwrite, assign) BOOL exportCancelled;
@property (readwrite, assign) BOOL exportToMultipleFiles;
@property (readwrite, assign) MCPConnection *connection;

// IB action methods
- (void)export;
- (IBAction)closeSheet:(id)sender;
- (IBAction)switchTab:(id)sender;
- (IBAction)switchInput:(id)sender;
- (IBAction)cancelExport:(id)sender;
- (IBAction)changeExportOutputPath:(id)sender;
- (IBAction)refreshTableList:(id)sender;
- (IBAction)selectDeselectAllTables:(id)sender;

@end
