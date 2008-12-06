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
#import <MCPKit_bundled/MCPKit_bundled.h>
#import "CMMCPConnection.h"
#import "CMMCPResult.h"


@interface TableDump : NSObject {

	IBOutlet id tableDocumentInstance;
	IBOutlet id tablesListInstance;
	IBOutlet id tableSourceInstance;
	IBOutlet id tableContentInstance;
	IBOutlet id customQueryInstance;

    IBOutlet id tableWindow;
	IBOutlet id tableListView;
	
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
	
	IBOutlet id importCSVView;
	IBOutlet id importFormatPopup;
	IBOutlet id importCSVBox;
    IBOutlet id importFieldNamesSwitch;
    IBOutlet id importFieldsTerminatedField;
    IBOutlet id importFieldsEnclosedField;
    IBOutlet id importFieldsEscapedField;
    IBOutlet id importLinesTerminatedField;
	
    IBOutlet id addDropTableSwitch;
    IBOutlet id addCreateTableSwitch;
    IBOutlet id addTableContentSwitch;
    IBOutlet id addErrorsSwitch;
    IBOutlet id errorsSheet;
    IBOutlet id errorsView;
    IBOutlet id singleProgressSheet;
    IBOutlet id singleProgressBar;
    IBOutlet id singleProgressText;
	
    IBOutlet id fieldMappingSheet;
	IBOutlet id fieldMappingPopup;
    IBOutlet id fieldMappingTableView;
    
	IBOutlet id rowUpButton;
    IBOutlet id rowDownButton;
	IBOutlet id recordCountLabel;

	CMMCPConnection *mySQLConnection;

	NSMutableArray *tables;
	NSArray *importArray;
	NSMutableArray *fieldMappingArray;
	int currentRow;
	NSString *savePath;
	NSString *openPath;
	NSUserDefaults *prefs;
}

//IBAction methods
- (IBAction)reloadTables:(id)sender;
- (IBAction)selectTables:(id)sender;
- (IBAction)closeSheet:(id)sender;
- (IBAction)stepRow:(id)sender;
//- (IBAction)chooseDumpType:(id)sender;

//export methods
//- (IBAction)saveDump:(id)sender;
- (void)exportFile:(int)tag;
- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(NSString *)contextInfo;

//import methods
//- (IBAction)openDump:(id)sender;
- (void)importFile;
- (IBAction)changeFormat:(id)sender;
- (IBAction)changeTable:(id)sender;
- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(NSString *)contextInfo;
- (void)setupFieldMappingArray;

//format methods
- (NSString *)dumpForSelectedTables;
- (NSString *)csvForArray:(NSArray *)array useFirstLine:(BOOL)firstLine terminatedBy:(NSString *)terminated
	enclosedBy:(NSString *)enclosed escapedBy:(NSString *)escaped lineEnds:(NSString *)lineEnds silently:(BOOL)silently;
- (NSArray *)arrayForCSV:(NSString *)csv terminatedBy:(NSString *)terminated
	enclosedBy:(NSString *)enclosed escapedBy:(NSString *)escaped lineEnds:(NSString *)lineEnds;
- (NSString *)xmlForArray:(NSArray *)array tableName:(NSString *)table withHeader:(BOOL)header silently:(BOOL)silently;
- (NSString *)stringForSelectedTablesWithType:(NSString *)type;
- (NSString *)htmlEscapeString:(NSString *)string;
- (NSArray *)arrayForString:(NSString *)string enclosed:(NSString *)enclosed
	escaped:(NSString *)escaped terminated:(NSString *)terminated;
- (NSArray *)splitQueries:(NSString *)query;

//additional methods
- (void)setConnection:(CMMCPConnection *)theConnection;

//tableView datasource methods
- (int)numberOfRowsInTableView:(NSTableView *)aTableView;
- (id)tableView:(NSTableView *)aTableView
			objectValueForTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex;
- (void)tableView:(NSTableView *)aTableView
			setObjectValue:(id)anObject
			forTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex;

//last but not least
- (id)init;
- (void)dealloc;

@end
