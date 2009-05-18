//
//  SPTableRelations.h
//  sequel-pro
//
//  Created by J Knight on 13/05/09.
//  Copyright 2009 J Knight. All rights reserved.
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
//

#import <Cocoa/Cocoa.h>
#import <MCPKit_bundled/MCPKit_bundled.h>

@class CMMCPConnection, CMMCPResult, CMCopyTable;

@interface SPTableRelations : NSObject 
{	
	IBOutlet id tableDocumentInstance;
	IBOutlet id tablesListInstance;	
	IBOutlet id tableList;
	IBOutlet id tableWindow;
	IBOutlet id tableDataInstance;
	IBOutlet id addButton;
	IBOutlet id removeButton;	
	IBOutlet id refreshButton;
	IBOutlet id labelText;		
	IBOutlet id relationsView;
	IBOutlet id relationSheet;

	IBOutlet id tableBox;
	IBOutlet id columnSelect;
	IBOutlet id refTableSelect;
	IBOutlet id refColumnSelect;
	IBOutlet id onUpdateSelect;
	IBOutlet id onDeleteSelect;
		
	CMMCPConnection *mySQLConnection;

	NSMutableArray *relData;
}

- (void)setConnection:(CMMCPConnection *)theConnection;

// IB action methods
- (IBAction)addRow:(id)sender;
- (IBAction)removeRow:(id)sender;
- (IBAction)closeRelationSheet:(id)sender;
- (IBAction)addRelation:(id)sender;
- (IBAction)chooseRefTable:(id)sender;
- (IBAction)refresh:(id)sender;

- (void)tableChanged:(NSNotification *)notification;

@end
