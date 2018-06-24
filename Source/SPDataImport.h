//
//  SPDataImport.h
//  sequel-pro
//
//  Created by Lorenz Textor (lorenz@textor.ch) on Wed May 1, 2002.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
//  Copyright (c) 2012 Sequel Pro Team. All rights reserved.
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

@class SPMySQLConnection;
@class SPFieldMapperController;
@class SPFileHandle;
@class SPDatabaseDocument;
@class SPCustomQuery;
@class SPTableData;
@class SPTableStructure;
@class SPTablesList;

typedef enum {
	SPFieldMapperInProgress = 1,
	SPFieldMapperCompleted = 2,
	SPFieldMapperCancelled = 3
} SPFieldMapperSheetStatus;

@interface SPDataImport : NSObject <NSOpenSavePanelDelegate>
{
#warning Outlets belong to multiple xib files!
	IBOutlet SPDatabaseDocument *tableDocumentInstance;
	IBOutlet SPTablesList *tablesListInstance;
	IBOutlet SPTableStructure *tableSourceInstance;
	IBOutlet SPTableData *tableDataInstance;
	IBOutlet SPCustomQuery *customQueryInstance;

	IBOutlet id importView;
	IBOutlet id importTabView;
	IBOutlet NSButton *importFieldNamesSwitch;
	IBOutlet id importFieldsTerminatedField;
	IBOutlet id importFieldsEnclosedField;
	IBOutlet id importFieldsEscapedField;
	IBOutlet id importLinesTerminatedField;

	IBOutlet NSPopUpButton *importFormatPopup;
	IBOutlet NSPopUpButton *importEncodingPopup;

	IBOutlet NSPopUpButton *importSQLErrorHandlingPopup;
	
	IBOutlet id importFromClipboardSheet;
	IBOutlet id importFromClipboardAccessoryView;
	
	IBOutlet NSTextView *importFromClipboardTextView;
	
	IBOutlet NSWindow *errorsSheet;
	IBOutlet NSTextView *errorsView;

	IBOutlet NSPanel *singleProgressSheet;
	IBOutlet NSProgressIndicator *singleProgressBar;
	IBOutlet NSTextField *singleProgressTitle;
	IBOutlet NSTextField *singleProgressText;

	SPMySQLConnection *mySQLConnection;

	NSMutableArray *nibObjectsToRelease;

	// Field Mapper Controller
	NSArray *fieldMappingImportArray;
	BOOL fieldMappingImportArrayIsPreview;
	NSArray *fieldMappingTableColumnNames;
	NSArray *fieldMappingArray;
	NSArray *fieldMappingGlobalValueArray;
	NSArray *fieldMappingTableDefaultValues;
	NSArray *fieldMapperOperator;
	NSString *selectedTableTarget;
	NSString *selectedImportMethod;
	NSString *lastFilename;
	NSString *csvImportHeaderString;
	NSString *csvImportTailString;
	SPFieldMapperSheetStatus fieldMapperSheetStatus;
	NSInteger numberOfImportDataColumns;
	BOOL fieldMappingArrayHasGlobalVariables;
	BOOL csvImportMethodHasTail;
	BOOL insertRemainingRowsAfterUpdate;
	BOOL importMethodIsUpdate;
	BOOL importIntoNewTable;

	NSUserDefaults *prefs;

	BOOL progressCancelled;
	BOOL mainNibLoaded;

	NSMutableArray *geometryFields;
	NSMutableIndexSet *geometryFieldsMapIndex;
	NSMutableArray *bitFields;
	NSMutableIndexSet *bitFieldsMapIndex;
	NSMutableArray *nullableNumericFields;
	NSMutableIndexSet *nullableNumericFieldsMapIndex;
}

// IBAction methods
- (IBAction)closeSheet:(id)sender;
- (IBAction)cancelProgressBar:(id)sender;
- (IBAction)changeFormat:(id)sender;

// Import methods
- (void)importFile;
- (void)importFromClipboard;
- (void)importSQLFile:(NSString *)filename;
- (void)importOverwriteWarningSheetDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(NSString *)importFileName;
- (void)startSQLImportProcessWithFile:(NSString *)filename;
- (void)importCSVFile:(NSString *)filename;
- (BOOL)buildFieldMappingArrayWithData:(NSArray *)importData isPreview:(BOOL)dataIsPreviewData ofSoureFile:(NSString*)filename;

- (NSString *)mappedValueStringForRowArray:(NSArray *)csvRowArray;
- (NSString *)mappedUpdateSetStatementStringForRowArray:(NSArray *)csvRowArray;

// Additional methods
- (void)setConnection:(SPMySQLConnection *)theConnection;
- (void)showErrorSheetWithMessage:(NSString*)message;

// Import delegate notifications
- (void)panelSelectionDidChange:(id)sender;

@end
