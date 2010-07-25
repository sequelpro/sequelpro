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

#import <Cocoa/Cocoa.h>
#import <MCPKit/MCPKit.h>

@class SPFieldMapperController, SPFileHandle;

@interface SPDataImport : NSObject 
{
	IBOutlet id tableDocumentInstance;
	IBOutlet id tablesListInstance;
	IBOutlet id tableSourceInstance;
	IBOutlet id tableContentInstance;
	IBOutlet id tableDataInstance;
	IBOutlet id customQueryInstance;

	IBOutlet id importCSVView;
	IBOutlet id importCSVBox;
	IBOutlet id importFieldNamesSwitch;
	IBOutlet id importFieldsTerminatedField;
	IBOutlet id importFieldsEnclosedField;
	IBOutlet id importFieldsEscapedField;
	IBOutlet id importLinesTerminatedField;
	IBOutlet id importFieldMapperSheetWindow;

	IBOutlet NSPopUpButton *importFormatPopup;
	IBOutlet NSPopUpButton *importEncodingPopup;
	
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

	MCPConnection *mySQLConnection;

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
	NSInteger fieldMapperSheetStatus;
	NSInteger numberOfImportDataColumns;
	BOOL fieldMappingArrayHasGlobalVariables;
	BOOL csvImportMethodHasTail;
	BOOL insertRemainingRowsAfterUpdate;
	BOOL importMethodIsUpdate;

	NSUInteger exportMode;
	NSUserDefaults *prefs;
	BOOL progressCancelled;
	BOOL _mainNibLoaded;

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
- (void)setConnection:(MCPConnection *)theConnection;
- (void)showErrorSheetWithMessage:(NSString*)message;

// Import delegate notifications
- (void)panelSelectionDidChange:(id)sender;

@end
