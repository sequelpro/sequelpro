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
@class SPExportFile;

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
	// NOTE: Those outlets are connected when we are instantiated from DBView!

	// Controllers
	IBOutlet SPDatabaseDocument *tableDocumentInstance;
	IBOutlet SPTableContent *tableContentInstance;
	IBOutlet SPCustomQuery *customQueryInstance;
	IBOutlet SPTablesList *tablesListInstance;
	IBOutlet SPTableData *tableDataInstance;

	// NOTE: All outlets below are connected when our own xib is loaded.

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
	dispatch_once_t mainNibLoaded;
	
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

	NSInteger heightOffset1;
	NSInteger heightOffset2;
	NSUInteger windowMinWidth;
	NSUInteger windowMinHeigth;
	
	NSDictionary *localizedTokenNames;

	NSMutableDictionary *exportHandlers;
	id<SPExportHandlerInstance> currentExportHandler;
	NSMutableArray *exportObjectList;
	NSMutableArray *hiddenTabViewStorage;
}

/**
 * The current user setting for export source
 */
@property (readonly, nonatomic) SPExportSource exportSource;

/**
 * The current export handler that is responsible for implementing a certain export format
 */
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

- (NSString *)exportPath;

- (void)addExportHandlersToMenu:(NSMenu *)parent forSource:(SPExportSource)source;

#pragma mark - Methods to be used by export handlers

/**
 * Get an array of NSString *s with the names of all known objects of this type.
 * If the list changes the controller will post a SPExportControllerSchemaObjectsChangedNotification.
 * The list will ONLY include objects that the current export handler also supports.
 * Will be empty if the source is not SPTableExport.
 */
- (NSArray *)schemaObjectsForType:(SPTableType)type;

/**
 * Find the schema object which has a given name.
 * @param name The name of the schema object
 * @return The schema object or nil.
 *
 * Note that only schema objects which are supported by the current export handler are searched.
 * Receiving nil does not imply that an object does not exist, only that such an object will not be
 * exported with the current settings.
 *
 * This will always return nil if source is not SPTableExport.
 */
- (id<SPExportSchemaObject>)schemaObjectNamed:(NSString *)name;

/**
 * Get all schema objects supported by the current export handler.
 * @return A list of objects. Will be empty if source != SPTableExport.
 */
- (NSArray *)allSchemaObjects;

/**
 * Create and return a new export output file
 * @param tableName The value for the {table} token object. Can be nil.
 * @return A export file at the path chosen by the user.
 */
- (SPExportFile *)exportFileForTableName:(NSString *)tableName;

- (SPDatabaseDocument *)tableDocumentInstance;
- (SPTableData *)tableDataInstance;

- (void)setExportProgressTitle:(NSString *)title;
- (void)setExportProgressDetail:(NSString *)detail;
- (void)setExportProgress:(double)value;
- (void)setExportProgressIndeterminate:(BOOL)indeterminate;

@end
