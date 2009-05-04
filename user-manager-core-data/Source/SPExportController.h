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
#import "CMMCPConnection.h"
#import "CMMCPResult.h"

@interface SPExportController : NSObject {

	// Table Document
	IBOutlet id tableDocumentInstance;
	IBOutlet id tableWindow;
	
	// Tables List
	IBOutlet id tablesListInstance;
	
	// Export Window
	IBOutlet id exportWindow;
	IBOutlet id exportToolbar;
	IBOutlet id	exportTableList;
	IBOutlet id exportTabBar;	
	IBOutlet id exportInputMatrix;
	IBOutlet id exportFilePerTableCheck;
	IBOutlet id exportFilePerTableNote;
	
	// SQL
	IBOutlet id exportSQLIncludeStructureCheck;
	IBOutlet id exportSQLIncludeDropSyntaxCheck;
	IBOutlet id exportSQLIncludeErrorsCheck;
	
	// Excel
	IBOutlet id exportExcelSheetOrFilePerTableMatrix;
	
	// CSV
	IBOutlet id exportCSVIncludeFieldNamesCheck;
    IBOutlet id exportCSVFieldsTerminatedField;
    IBOutlet id exportCSVFieldsWrappedField;
    IBOutlet id exportCSVFieldsEscapedField;
    IBOutlet id exportCSVLinesTerminatedField;
	
	// HTML
	IBOutlet id exportHTMLIncludeStructureCheck;
	IBOutlet id exportHTMLIncludeHeadAndBodyTagsCheck;
	
	// XML
	IBOutlet id exportXMLIncludeStructureCheck;
	
	// PDF
	IBOutlet id exportPDFIncludeStructureCheck;
	
	// Token Name View
	IBOutlet id tokenNameView;
	IBOutlet id tokenNameField;
	IBOutlet id tokenNameTokensField;
	IBOutlet id exampleNameLabel;
	
	// Local Variables
	CMMCPConnection *mySQLConnection;
	NSMutableArray *tables;
}

// Export Methods
- (void)export;
- (IBAction)closeSheet:(id)sender;

// Utility Methods
- (void)setConnection:(CMMCPConnection *)theConnection;
- (void)loadTables;
- (IBAction)switchTab:(id)sender;
- (IBAction)switchInput:(id)sender;

@end
