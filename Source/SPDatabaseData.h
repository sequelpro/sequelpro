//
//  $Id$
//
//  SPDatabaseData.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on May 20, 2009
//  Copyright (c) 2009 Stuart Connolly. All rights reserved.
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

@class SPServerSupport;

/**
 * @class SPDatabaseData SPDatabaseData.h
 *
 * @author Stuart Connolly http://stuconnolly.com/
 *
 * This class provides various convenience methods for obtaining data associated with the current database, 
 * if available. This includes available encodings, collations, etc.
 */
@interface SPDatabaseData : NSObject 
{
	NSString *characterSetEncoding;
	
	NSMutableArray *collations;
	NSMutableArray *characterSetCollations;
	NSMutableArray *storageEngines;
	NSMutableArray *characterSetEncodings;
	NSMutableDictionary *cachedCollationsByEncoding;
	
	MCPConnection *connection;
	SPServerSupport *serverSupport;	
}

/**
 * @property connection The current database connection
 */
@property (readwrite, assign) MCPConnection *connection;

/**
 * @property serverSupport The connection's associated SPServerSupport instance
 */
@property (readwrite, assign) SPServerSupport *serverSupport;

- (void)resetAllData;

- (NSArray *)getDatabaseCollations;
- (NSArray *)getDatabaseCollationsForEncoding:(NSString *)encoding;
- (NSArray *)getDatabaseStorageEngines;
- (NSArray *)getDatabaseCharacterSetEncodings;

@end
