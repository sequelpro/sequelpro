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

#import "SPConstants.h"

@class MCPConnection, BWAnchoredButtonBar;

/**
 * @class SPExportController SPExportController.m
 *
 * @author Stuart Connolly http://stuconnolly.com/
 *
 * Export controller.
 */
@interface SPExportController : NSWindowController
{	
	// Controllers
	IBOutlet id tableDocumentInstance;
	IBOutlet id tableContentInstance;
	IBOutlet id customQueryInstance;
	IBOutlet id tablesListInstance;
	IBOutlet id tableDataInstance;
	
	// Connection window
	IBOutlet NSWindow *tableWindow;
	
	// Export window
	IBOutlet NSButton *exportButton;
	IBOutlet NSToolbar *exportToolbar;
	IBOutlet NSTextField *exportPathField;
	IBOutlet NSTableView *exportTableList;
	IBOutlet NSTabView *exportTabBar;	
	IBOutlet NSMatrix *exportInputMatrix;
	IBOutlet NSButton *exportFilePerTableCheck;
	IBOutlet NSTextField *exportFilePerTableNote;
	IBOutlet NSButton *exportSelectAllTablesButton;
	IBOutlet NSButton *exportDeselectAllTablesButton;
	IBOutlet NSButton *exportRefreshTablesButton;
	IBOutlet NSScrollView *exportTablelistScrollView;
	
	// Errors sheet
	IBOutlet NSWindow *errorsWindow;
	IBOutlet NSTextView *errorsTextView;
	
	// Advanced options view
	IBOutlet NSButton *exportAdvancedOptionsViewButton;
	IBOutlet NSView *exportAdvancedOptionsView;
	IBOutlet NSButton *exportAdvancedOptionsViewLabelButton;
	IBOutlet NSButton *exportUseUTF8BOMButton;
	IBOutlet NSButton *exportCompressOutputFile;
	IBOutlet NSButton *exportProcessLowMemoryButton;
	IBOutlet NSTextField *exportCSVNULLValuesAsTextField;
	
	IBOutlet BWAnchoredButtonBar *exportTableListButtonBar;
	
	// Export progress sheet
	IBOutlet NSWindow *exportProgressWindow;
	IBOutlet NSTextField *exportProgressTitle;
	IBOutlet NSTextField *exportProgressText;
	IBOutlet NSProgressIndicator *exportProgressIndicator;
	
	// Custom filename view
	IBOutlet NSView *exportCustomFilenameView;
	IBOutlet NSButton *exportCustomFilenameButton;
	IBOutlet NSTokenField *exportCustomFilenameTokenField;
	IBOutlet NSTokenField *exportCustomFilenameTokensField;
	IBOutlet NSTextField *exportCustomFilenameExampleTextField;
	
	// SQL
	IBOutlet NSButton *exportSQLIncludeStructureCheck;
	IBOutlet NSButton *exportSQLIncludeDropSyntaxCheck;
	IBOutlet NSButton *exportSQLIncludeContentCheck;
	IBOutlet NSButton *exportSQLIncludeErrorsCheck;
	IBOutlet NSButton *exportSQLBLOBFieldsAsHexCheck;
	
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
	
	// PDF
	IBOutlet NSButton *exportPDFIncludeStructureCheck;
	
	/**
	 * Cancellation flag
	 */
	BOOL exportCancelled;
	
	/** 
	 * Multi-file export flag
	 */
	BOOL exportToMultipleFiles;
	
	/**
	 * Create custom filename flag
	 */
	BOOL createCustomFilename;
	
	/**
	 * Number of tables being exported
	 */
	 NSUInteger exportTableCount;
	
	/** 
	 * Index of the current table being exported
	 */
	NSUInteger currentTableExportIndex;
	
	/**
	 * Export type label
	 */
	NSString *exportTypeLabel;
	
	/** 
	 * Export filename
	 */
	NSString *exportFilename;
	
	/**
	 * Current database's tables
	 */
	NSMutableArray *tables;
	
	/** 
	 * Database connection
	 */
	MCPConnection *connection;
	
	/**
	 * Concurrent operation queue
	 */
	NSOperationQueue *operationQueue;
	
	/** 
	 * Exporters
	 */
	NSMutableArray *exporters;
	
	/**
	 * Global export file handle
	 */
	NSFileHandle *exportFileHandle;
	
	/**
	 * Export type
	 */
	SPExportType exportType;
	
	/**
	 * Export source
	 */
	SPExportSource exportSource;
	
	/**
	 * Available filename tokens
	 */
	NSString *availableFilenameTokens;
	
	/**
	 * Display advanced view flag
	 */
	BOOL showAdvancedView;
	
	/**
	 * User defaults
	 */
	NSUserDefaults *prefs;
	
	/**
	 * Current toolbar item
	 */
	NSToolbarItem *currentToolbarItem;
	
	/**
	 * Previous connection encoding
	 */
	NSString *sqlPreviousConnectionEncoding;
	
	/**
	 * Previous connection encoding was via Latin1
	 */
	BOOL sqlPreviousConnectionEncodingViaLatin1;

	NSInteger heightOffset;
	NSUInteger windowMinWidth;
	NSUInteger windowMinHeigth;
}

/**
 * @property exportCancelled Export cancellation flag
 */
@property(readwrite, assign) BOOL exportCancelled;

/**
 * @property exportToMultipleFiles Export to multiple files flag
 */
@property(readwrite, assign) BOOL exportToMultipleFiles;

/**
 * @property connection Database connection
 */
@property(readwrite, assign) MCPConnection *connection;

- (void)export;
- (void)exportTables:(NSArray *)table asFormat:(SPExportType)format;
- (void)openExportErrorsSheetWithString:(NSString *)errors;
- (void)displayExportFinishedGrowlNotification;
- (NSString *)expandCustomFilenameFormatFromString:(NSString *)format usingTableName:(NSString *)table;

// IB action methods
- (IBAction)closeSheet:(id)sender;
- (IBAction)switchTab:(id)sender;
- (IBAction)switchInput:(id)sender;
- (IBAction)cancelExport:(id)sender;
- (IBAction)changeExportOutputPath:(id)sender;
- (IBAction)refreshTableList:(id)sender;
- (IBAction)selectDeselectAllTables:(id)sender;
- (IBAction)toggleCustomFilenameFormat:(id)sender;
- (IBAction)toggleAdvancedExportOptionsView:(id)sender;

- (IBAction)toggleSQLIncludeStructure:(id)sender;
- (IBAction)toggleSQLIncludeContent:(id)sender;
- (IBAction)toggleSQLIncludeDropSyntax:(id)sender;

@end
