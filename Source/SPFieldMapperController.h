//
//  $Id$
//
//  SPFieldMapperController.h
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on February 01, 2010
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

@interface SPFieldMapperController : NSWindowController {

	IBOutlet NSTableView *fieldMapperTableView;
	IBOutlet NSPopUpButton *tableTargetPopup;
	IBOutlet NSPathControl *fileSourcePath;
	IBOutlet NSPopUpButton *importMethodPopup;
	IBOutlet id rowUpButton;
	IBOutlet id rowDownButton;
	IBOutlet id recordCountLabel;
	IBOutlet id importFieldNamesHeaderSwitch;
	IBOutlet id importButton;
	IBOutlet NSPopUpButton *alignByPopup;
	
	id theDelegate;
	id fieldMappingImportArray;
	
	NSInteger fieldMappingCurrentRow;
	NSMutableArray *fieldMappingArray;
	NSMutableArray *fieldMappingTableColumnNames;
	// NSMutableArray *fieldMappingTableDefaultValues;
	NSMutableArray *fieldMappingTableTypes;
	NSMutableArray *fieldMappingButtonOptions;
	NSMutableArray *fieldMappingOperatorOptions;
	NSMutableArray *fieldMappingOperatorArray;
	
	NSNumber *doImport;
	NSNumber *doNotImport;
	NSNumber *isEqual;
	NSString *doImportString;
	NSString *doNotImportString;
	NSString *isEqualString;

	BOOL fieldMappingImportArrayIsPreview;
	BOOL importFieldNamesHeader;
	NSNumber *lastDisabledCSVFieldcolumn;

	MCPConnection *mySQLConnection;

	NSString *sourcePath;

	NSUserDefaults *prefs;
}

@property(retain) NSString* sourcePath;

- (id)initWithDelegate:(id)managerDelegate;

- (void)setConnection:(MCPConnection *)theConnection;
- (void)setImportDataArray:(id)theFieldMappingImportArray hasHeader:(BOOL)hasHeader isPreview:(BOOL)isPreview;

// Getter methods
- (NSString*)selectedTableTarget;
- (NSArray*)fieldMapperOperator;
- (NSString*)selectedImportMethod;
- (NSArray*)fieldMappingArray;
- (NSArray*)fieldMappingTableColumnNames;
- (BOOL)importFieldNamesHeader;

// IBAction methods
- (IBAction)changeTableTarget:(id)sender;
- (IBAction)changeImportMethod:(id)sender;
- (IBAction)changeFieldAlignment:(id)sender;
- (IBAction)stepRow:(id)sender;
- (IBAction)closeSheet:(id)sender;

// Others
- (void)setupFieldMappingArray;
- (void)updateFieldMappingButtonCell;
- (void)updateFieldMappingOperatorOptions;

@end
