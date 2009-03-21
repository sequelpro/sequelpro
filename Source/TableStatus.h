//
//  TableContent.h
//  sequel-pro
//
//  Created by Jason Hallford (jason.hallford@byu.edu) on Th July 08 2004.
//  sequel-pro Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
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

@interface TableStatus : NSObject
{
	IBOutlet id tableDataInstance;

	IBOutlet id commentsBox;
	IBOutlet id rowsNumber;
	IBOutlet id rowsFormat;
	IBOutlet id rowsAvgLength;
	IBOutlet id rowsAutoIncrement;
	IBOutlet id sizeData;
	IBOutlet id sizeFree;
	IBOutlet id sizeIndex;
	IBOutlet id sizeMaxData;
	IBOutlet id tableCreatedAt;
	IBOutlet id tableName;
	IBOutlet id tableType;
	IBOutlet id tableUpdatedAt;
	
	CMMCPConnection *mySQLConnection;
	CMMCPResult *tableStatusResult;
	
	NSString *selectedTable;
	NSDictionary* statusFields;
}

// Table methods
- (void)loadTable:(NSString *)aTable;
- (IBAction)reloadTable:(id)sender;

// Additional methods
- (void)setConnection:(CMMCPConnection *)theConnection;
- (void)awakeFromNib;

// Initialization
- (id)init;
@end
