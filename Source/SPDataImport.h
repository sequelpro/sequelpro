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

typedef enum {
	SPFieldMapperInProgress = 1,
	SPFieldMapperCompleted = 2,
	SPFieldMapperCancelled = 3
} SPFieldMapperSheetStatus;

@class SPFieldMapperController, SPFileHandle;

@interface SPDataImport : NSObject <NSOpenSavePanelDelegate>
{
	IBOutlet id tableDocumentInstance;
	IBOutlet id tablesListInstance;
	IBOutlet id tableSourceInstance;
	IBOutlet id tableContentInstance;
	IBOutlet id tableDataInstance;
	IBOutlet id customQueryInstance;

	IBOutlet id importView;
	IBOutlet id importTabView;
	IBOutlet NSButton *importFieldNamesSwitch;
	IBOutlet id importFieldsTerminatedField;
	IBOutlet id importFieldsEnclosedField;
	IBOutlet id importFieldsEscapedField;
	IBOutlet id importLinesTerminatedField;
	IBOutlet id importFieldMapperSheetWindow;

	IBOutlet NSPopUpButton *importFormatPopup;
	IBOutlet NSPopUpButton *importEncodingPopup;

	IBOutlet NSPopUpButton *importSQLErrorHandlingPopup;
	
	IBOutlet id importFromClipboardSheet;
	IBOutlet id importFromClipboardAccessoryView;
	
	IBOutlet NSTextView *importFromClipboardTextView;
	
	IBOutlet id addDropTableSwitch;
	IBOutlet id addCreateTableSwitch;
	IBOutlet id addTableContentSwitch;
	IBOutlet id addErrorsSwitch;
	IBOutlet id sqlFullStreamingSwitch;
	IBOutlet id sqlCompressionSwitch;
	IBOutlet id csvFullStreamingSwitch;
	IBOutlet id multiCSVFullStreamingSwitch;
	IBOutlet id multiXMLFullStreamingSwitch;
	IBOutlet id errorsSheet;
	IBOutlet id errorsView;
	IBOutlet id singleProgressSheet;
	IBOutlet id singleProgressBar;
	IBOutlet id singleProgressTitle;
	IBOutlet id singleProgressText;

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

	NSUInteger exportMode;
	NSUserDefaults *prefs;
	BOOL progressCancelled;
	BOOL _mainNibLoaded;

	NSMutableArray *geometryFields;
	NSMutableIndexSet *geometryFieldsMapIndex;
	NSMutableArray *bitFields;
	NSMutableIndexSet *bitFieldsMapIndex;
	NSMutableArray *nullableNumericFields;
	NSMutableIndexSet *nullableNumericFieldsMapIndex;

	NSSavePanel *currentExportPanel;
}

// IBAction methods
- (IBAction)closeSheet:(id)sender;
- (IBAction)cancelProgressBar:(id)sender;

// Import methods
- (void)importFile;
- (void)importFromClipboard;
- (void)importSQLFile:(NSString *)filename;
- (void)startSQLImportProcessWithFile:(NSString *)filename;
- (void)importCSVFile:(NSString *)filename;
- (IBAction)changeFormat:(id)sender;
- (BOOL)buildFieldMappingArrayWithData:(NSArray *)importData isPreview:(BOOL)dataIsPreviewData ofSoureFile:(NSString*)filename;

- (NSString *)mappedValueStringForRowArray:(NSArray *)csvRowArray;
- (NSString *)mappedUpdateSetStatementStringForRowArray:(NSArray *)csvRowArray;

// Additional methods
- (void)setConnection:(SPMySQLConnection *)theConnection;
- (void)showErrorSheetWithMessage:(NSString*)message;

// Import delegate notifications
- (void)panelSelectionDidChange:(id)sender;

@end
