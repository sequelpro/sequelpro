//
//  SPTableTriggers.h
//  sequel-pro
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


@interface SPTableTriggers : NSObject {
	IBOutlet id tableDocumentInstance;
	IBOutlet id tablesListInstance;
	IBOutlet id tableDataInstance;
	
	IBOutlet id tableList;
	IBOutlet id tableWindow;
	
	IBOutlet NSButton    *addTriggerButton;
	IBOutlet NSButton    *removeTriggerButton;	
	IBOutlet NSButton    *refreshTriggersButton;
	IBOutlet NSTextField *labelTextField;		
	IBOutlet NSTableView *triggersTableView;
	IBOutlet NSPanel     *addTriggerPanel;
	
	IBOutlet NSBox         *addTriggerTableBox;
	IBOutlet NSPopUpButton *columnPopUpButton;
	IBOutlet NSPopUpButton *refTablePopUpButton;
	IBOutlet NSPopUpButton *refColumnPopUpButton;
	IBOutlet NSPopUpButton *onUpdatePopUpButton;
	IBOutlet NSPopUpButton *onDeletePopUpButton;
	IBOutlet NSButton      *confirmAddTriggerButton;
	
	MCPConnection *connection;
	
	NSMutableArray *triggerData;
}

@property (readwrite, assign) MCPConnection *connection;

// IB action methods
- (IBAction)addTrigger:(id)sender;
- (IBAction)removeTrigger:(id)sender;
- (IBAction)closeRelationSheet:(id)sender;
- (IBAction)confirmAddRelation:(id)sender;
- (IBAction)selectTableColumn:(id)sender;
- (IBAction)selectReferenceTable:(id)sender;
- (IBAction)refreshTriggers:(id)sender;

// Task interaction
- (void)startDocumentTaskForTab:(NSNotification *)aNotification;
- (void)endDocumentTaskForTab:(NSNotification *)aNotification;

@end
