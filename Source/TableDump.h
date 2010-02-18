//
//  $Id$
//
//  TableDump.h
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
//  Or mail to <lorenz@textor.ch>

#import <Cocoa/Cocoa.h>
#import "SPFieldMapperController.h"
#import <MCPKit/MCPKit.h>

typedef enum _SPExportModes {
	SPExportingSQL = 0,
	SPExportingCSV = 1,
	SPExportingXML = 2,
	SPExportingDOT = 3
} SPExportMode;

@interface TableDump : NSObject 
{
	IBOutlet id tableDocumentInstance;
	IBOutlet id tablesListInstance;
	IBOutlet id tableSourceInstance;
	IBOutlet id tableContentInstance;
	IBOutlet id tableDataInstance;
	IBOutlet id customQueryInstance;

	IBOutlet id tableWindow;

	IBOutlet id exportDumpView;
	IBOutlet id exportCSVView;
	IBOutlet id exportMultipleCSVView;
	IBOutlet id exportMultipleXMLView;
	IBOutlet id exportDumpTableView;
	IBOutlet id exportMultipleCSVTableView;
	IBOutlet id exportMultipleXMLTableView;
	IBOutlet id exportFieldNamesSwitch;
	IBOutlet id exportFieldsTerminatedField;
	IBOutlet id exportFieldsEnclosedField;
	IBOutlet id exportFieldsEscapedField;
	IBOutlet id exportLinesTerminatedField;
	IBOutlet id exportMultipleFieldNamesSwitch;
	IBOutlet id exportMultipleFieldsTerminatedField;
	IBOutlet id exportMultipleFieldsEnclosedField;
	IBOutlet id exportMultipleFieldsEscapedField;
	IBOutlet id exportMultipleLinesTerminatedField;

	// New Export Window
	IBOutlet id exportWindow;
	IBOutlet id exportTabBar;
	IBOutlet id exportToolbar;
	IBOutlet id	exportTableList;

	IBOutlet id importCSVView;
	IBOutlet NSPopUpButton *importFormatPopup;
	IBOutlet id importCSVBox;
	IBOutlet id importFieldNamesSwitch;
	IBOutlet id importFieldsTerminatedField;
	IBOutlet id importFieldsEnclosedField;
	IBOutlet id importFieldsEscapedField;
	IBOutlet id importLinesTerminatedField;
	IBOutlet id importFieldMapperSheetWindow;

	IBOutlet id addDropTableSwitch;
	IBOutlet id addCreateTableSwitch;
	IBOutlet id addTableContentSwitch;
	IBOutlet id addErrorsSwitch;
	IBOutlet id sqlFullStreamingSwitch;
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

	NSMutableArray *tables;

	// Field Mapper Controller
	SPFieldMapperController *fieldMapperController;
	NSArray *fieldMappingImportArray;
	BOOL fieldMappingImportArrayIsPreview;
	NSArray *fieldMappingTableColumnNames;
	NSArray *fieldMappingArray;
	NSArray *fieldMappingGlobalValueArray;
	NSArray *fieldMapperOperator;
	NSString *selectedTableTarget;
	NSString *selectedImportMethod;
	NSString *lastFilename;
	NSInteger fieldMapperSheetStatus;
	BOOL fieldMappingArrayHasGlobalVariables;

	NSUInteger exportMode;
	NSUserDefaults *prefs;
	BOOL progressCancelled;

}

// IBAction methods
- (IBAction)reloadTables:(id)sender;
- (IBAction)selectTables:(id)sender;
- (IBAction)closeSheet:(id)sender;
- (IBAction)cancelProgressBar:(id)sender;

// Export methods
- (void)export;
- (void)exportFile:(NSInteger)tag;
- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo;
- (void)exportBackgroundProcess:(NSDictionary *)exportAction;

// Import methods
- (void)importFile;
- (void)importSQLFile:(NSString *)filename;
- (void)startSQLImportProcessWithFile:(NSString *)filename;
- (void)importCSVFile:(NSString *)filename;
- (IBAction)changeFormat:(id)sender;
- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo;
- (BOOL) buildFieldMappingArrayWithData:(NSArray *)importData isPreview:(BOOL)dataIsPreviewData ofSoureFile:(NSString*)filename;
- (NSString *) mappedValueStringForRowArray:(NSArray *)csvRowArray;

// Export methods
- (BOOL)dumpSelectedTablesAsSqlToFileHandle:(NSFileHandle *)fileHandle;
- (BOOL)dumpSchemaAsDotToFileHandle:(NSFileHandle *)fileHandle;
- (BOOL)writeCsvForArray:(NSArray *)array orStreamingResult:(MCPStreamingResult *)streamingResult
	toFileHandle:(NSFileHandle *)fileHandle
	outputFieldNames:(BOOL)firstLine terminatedBy:(NSString *)terminated
	enclosedBy:(NSString *)enclosed escapedBy:(NSString *)escaped
	lineEnds:(NSString *)lineEnds withNumericColumns:(NSArray *)tableColumnNumericStatus totalRows:(NSInteger)totalRows silently:(BOOL)silently;
- (BOOL)writeXmlForArray:(NSArray *)array orStreamingResult:(MCPStreamingResult *)streamingResult
	toFileHandle:(NSFileHandle *)fileHandle
	tableName:(NSString *)table withHeader:(BOOL)header totalRows:(NSInteger)totalRows silently:(BOOL)silently;
- (NSString *)htmlEscapeString:(NSString *)string;
- (NSString *)createViewPlaceholderSyntaxForView:(NSString *)viewName;

- (BOOL)exportTables:(NSArray *)selectedTables toFileHandle:(NSFileHandle *)fileHandle usingFormat:(NSString *)type usingMulti:(BOOL)multi;
- (BOOL)exportSelectedTablesToFileHandle:(NSFileHandle *)fileHandle usingFormat:(NSString *)type;

// New Export methods
- (IBAction)switchTab:(id)sender;
- (IBAction)switchInput:(id)sender;

// Additional methods
- (void)setConnection:(MCPConnection *)theConnection;
- (void)showErrorSheetWithMessage:(NSString*)message;

// Import/export delegate notifications
- (void)panelSelectionDidChange:(id)sender;

@end
