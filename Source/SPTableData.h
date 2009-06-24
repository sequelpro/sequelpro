//
//  $Id$
//
//  SPTableData.h
//  sequel-pro
//
//  Created by Rowan Beentje on 24/01/2009.
//  Copyright 2009 Arboreal. All rights reserved.
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

@interface SPTableData : NSObject 
{
	IBOutlet id tableDocumentInstance;
	IBOutlet id tableListInstance;

	NSMutableArray *columns;
	NSMutableArray *columnNames;
	NSMutableArray *constraints;
	NSMutableDictionary *status;
	
	NSString *tableEncoding;
	NSString *tableCreateSyntax;
	
	MCPConnection *mySQLConnection;
}

- (void) setConnection:(MCPConnection *)theConnection;
- (NSString *) tableEncoding;
- (NSString *) tableCreateSyntax;
- (NSArray *) columns;
- (NSDictionary *) columnWithName:(NSString *)colName;
- (NSArray *) columnNames;
- (NSDictionary *) columnAtIndex:(int)index;
- (NSArray *) getConstraints;
- (BOOL) columnIsBlobOrText:(NSString *)colName;
- (NSString *) statusValueForKey:(NSString *)aKey;
- (NSDictionary *) statusValues;
- (void) resetAllData;
- (void) resetStatusData;
- (void) resetColumnData;
- (BOOL) updateInformationForCurrentTable;
- (NSDictionary *) informationForTable:(NSString *)tableName;
- (BOOL) updateInformationForCurrentView;
- (NSDictionary *) informationForView:(NSString *)viewName;
- (BOOL) updateStatusInformationForCurrentTable;
- (NSDictionary *) parseFieldDefinitionStringParts:(NSArray *)definitionParts;

@end
