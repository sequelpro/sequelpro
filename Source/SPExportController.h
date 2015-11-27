//
//  SPExportController.h
//  sequel-pro
//
//  Created by Ben Perry (benperry.com.au) on February 12, 2009.
//  Copyright (c) 2010 Ben Perry. All rights reserved.
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

@class SPDatabaseDocument;
@class SPTableContent;
@class SPCustomQuery;
@class SPTablesList;
@class SPTableData;
@class SPMySQLConnection;
@class SPServerSupport;
@protocol SPExportHandlerInstance;
@protocol SPExportSchemaObject;

extern NSString *SPExportControllerSchemaObjectsChangedNotification;

/**
 * @class SPExportController SPExportController.h
 *
 * @author Stuart Connolly http://stuconnolly.com/
 *
 * Export controller.
 */
@interface SPExportController : NSWindowController
{	
	// Controllers
	IBOutlet SPDatabaseDocument *tableDocumentInstance;
	IBOutlet SPTableContent *tableContentInstance;
	IBOutlet SPCustomQuery *customQueryInstance;
	IBOutlet SPTablesList *tablesListInstance;
	IBOutlet SPTableData *tableDataInstance;
	
	// Export window
	IBOutlet NSView *exporterView;
	IBOutlet NSButton *exportButton;
	IBOutlet NSTextField *exportPathField;
	IBOutlet NSTableView *exportTableList;
	IBOutlet NSTabView *exportTypeTabBar;	
	IBOutlet NSPopUpButton *exportInputPopUpButton;
	IBOutlet NSButton *exportFilePerTableCheck;
	IBOutlet NSButton *exportSelectAllTablesButton;
	IBOutlet NSButton *exportDeselectAllTablesButton;
	IBOutlet NSButton *exportRefreshTablesButton;
	IBOutlet NSScrollView *exportTablelistScrollView;
	IBOutlet NSBox *exportFilenameDividerBox;
	
	// Errors sheet
	IBOutlet NSWindow *errorsWindow;
	IBOutlet NSTextView *errorsTextView;
	
	// Advanced options view
	IBOutlet NSButton *exportAdvancedOptionsViewButton;
	IBOutlet NSView *exportAdvancedOptionsView;
	IBOutlet NSButton *exportAdvancedOptionsViewLabelButton;
	IBOutlet NSButton *exportProcessLowMemoryButton;
	IBOutlet NSPopUpButton *exportOutputCompressionFormatPopupButton;
	
	IBOutlet NSBox *exportTableListButtonBar;
	
	// Export progress sheet
	IBOutlet NSWindow *exportProgressWindow;
	IBOutlet NSTextField *exportProgressTitle;
	IBOutlet NSTextField *exportProgressText;
	IBOutlet NSTextField *exportFormatInfoText;
	IBOutlet NSProgressIndicator *exportProgressIndicator;
	
	// Custom filename view
	IBOutlet NSButton *exportCustomFilenameViewButton;
	IBOutlet NSButton *exportCustomFilenameViewLabelButton;
	IBOutlet NSView *exportCustomFilenameView;
	IBOutlet NSTokenField *exportCustomFilenameTokenField;
	IBOutlet NSTokenField *exportCustomFilenameTokenPool;
	
	IBOutlet NSBox *accessoryViewContainer;

	/**
	 * Whether the awakeFromNib routine has already been run
	 */
	BOOL mainNibLoaded;
	
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
	NSMutableString *exportFilename;
	
	/**
	 * Database connection
	 */
	SPMySQLConnection *connection;
	SPServerSupport *serverSupport;
	
	/**
	 * Concurrent operation queue
	 */
	NSOperationQueue *operationQueue;
	
	/** 
	 * Exporters
	 */
	NSMutableArray *exporters;
	
	/**
	 * Array of export files.
	 */
	NSMutableArray *exportFiles;
	
	/**
	 * Export source
	 */
	SPExportSource exportSource;
	
	/**
	 * Display advanced view flag
	 */
	BOOL showAdvancedView;
	
	/**
	 * Display custom filename view flag.
	 */
	BOOL showCustomFilenameView;
	
	/**
	 * User defaults
	 */
	NSUserDefaults *prefs;

	/**
	 * Previous connection encoding
	 */
	NSString *previousConnectionEncoding;

	/**
	 * Previous connection encoding was via Latin1
	 */
	BOOL previousConnectionEncodingViaLatin1;

	/**
	 * The server's lower_case_table_names setting
	 */
	NSInteger serverLowerCaseTableNameValue;

	NSInteger heightOffset1;
	NSInteger heightOffset2;
	NSUInteger windowMinWidth;
	NSUInteger windowMinHeigth;
	
	NSDictionary *localizedTokenNames;

	NSMutableDictionary *exportHandlers;
	id<SPExportHandlerInstance> currentExportHandler;
	NSMutableArray *exportObjectList;
}

/**
 * The current user setting for export source
 */
@property (readonly, nonatomic) SPExportSource exportSource;

@property (readonly, nonatomic, retain) id<SPExportHandlerInstance> currentExportHandler;

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
@property(readwrite, assign) SPMySQLConnection *connection;
@property(readwrite, assign) SPServerSupport *serverSupport;

- (void)exportTables:(NSArray *)table asFormat:(NSString *)format usingSource:(SPExportSource)source;
- (void)openExportErrorsSheetWithString:(NSString *)errors;
- (void)displayExportFinishedGrowlNotification;

/**
 * Tries to set the export input to a given value or falls back to a default if not valid
 * @param input The source to use
 * @return YES if the source was accepted, NO otherwise
 * @pre _switchTab needs to have been run before this method to decide valid inputs
 */
- (BOOL)setExportSourceIfPossible:(SPExportSource)input;

// IB action methods
- (IBAction)export:(id)sender;
- (IBAction)closeSheet:(id)sender;
- (IBAction)switchInput:(id)sender;
- (IBAction)cancelExport:(id)sender;
- (IBAction)changeExportOutputPath:(id)sender;
- (IBAction)refreshTableList:(id)sender;
- (IBAction)selectDeselectAllTables:(id)sender;
- (IBAction)changeExportCompressionFormat:(id)sender;
- (IBAction)toggleCustomFilenameFormatView:(id)sender;
- (IBAction)toggleAdvancedExportOptionsView:(id)sender;
- (IBAction)exportCustomQueryResultAsFormat:(id)sender;

- (NSString *)exportPath;

/**
 * Get an array of NSString *s with the names of all known objects of this type.
 * If the list changes the controller will post a SPExportControllerSchemaObjectsChangedNotification
 */
- (NSArray *)schemaObjectsForType:(SPTableType)type;

- (id<SPExportSchemaObject>)schemaObjectNamed:(NSString *)name;

- (NSArray *)allSchemaObjects;

@end
