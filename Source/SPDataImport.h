//
//  $Id$
//
//  SPDataImport.h
//  sequel-pro
//
//  Created by lorenz textor (lorenz@textor.ch) on Wed May 01 2002.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
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

@class SPMySQLConnection;

typedef enum {
	SPFieldMapperInProgress = 1,
	SPFieldMapperCompleted = 2,
	SPFieldMapperCancelled = 3
} SPFieldMapperSheetStatus;

@class SPFieldMapperController, SPFileHandle;

@interface SPDataImport : NSObject 
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
	SPFieldMapperController *fieldMapperController;
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

	NSDictionary *targetTableDetails;
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
- (void)importFileSheetDidEnd:(id)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo;
- (void)importFromClipboard;
- (void)importFromClipboardSheetDidEnd:(id)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo;
- (void)importSQLFile:(NSString *)filename;
- (void)startSQLImportProcessWithFile:(NSString *)filename;
- (void)importCSVFile:(NSString *)filename;
- (IBAction)changeFormat:(id)sender;
- (BOOL)buildFieldMappingArrayWithData:(NSArray *)importData isPreview:(BOOL)dataIsPreviewData ofSoureFile:(NSString*)filename;
- (void)fieldMapperDidEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (NSString *)mappedValueStringForRowArray:(NSArray *)csvRowArray;
- (NSString *)mappedUpdateSetStatementStringForRowArray:(NSArray *)csvRowArray;

// Additional methods
- (void)setConnection:(SPMySQLConnection *)theConnection;
- (void)showErrorSheetWithMessage:(NSString*)message;

// Import delegate notifications
- (void)panelSelectionDidChange:(id)sender;

@end
