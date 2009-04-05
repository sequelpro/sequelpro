//
//  $Id$
//
//  MCPConnection.h
//  MCPKit
//
//  Created by Serge Cohen (serge.cohen@m4x.org) on 08/12/2001.
//  Copyright (c) 2001 Serge Cohen. All rights reserved.
//
//  Forked by the Sequel Pro team (sequelpro.com), April 2009
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
//  More info at <http://mysql-cocoa.sourceforge.net/>
//  More info at <http://code.google.com/p/sequel-pro/>

#import <Foundation/Foundation.h>
#import "mysql.h"
#import "MCPConstants.h"

@class MCPResult;

// Deafult connection option
extern const unsigned int	kMCPConnectionDefaultOption;

// Default socket (from the mysql.h used at compile time)
extern const char		*kMCPConnectionDefaultSocket;

// Added to mysql error code
extern const unsigned int 	kMCPConnectionNotInited;

// The length of the truncation if required:
extern const unsigned int	kLengthOfTruncationForLog;

@interface MCPConnection : NSObject {
@protected
   MYSQL						*mConnection;	/*"The inited MySQL connection."*/
	BOOL						mConnected;	/*"Reflect the fact that the connection is already in place or not."*/
	NSStringEncoding		mEncoding;	/*"The encoding used by MySQL server, to ISO-1 default."*/
	NSTimeZone				*mTimeZone;  /*"The time zone of the session."*/
	unsigned int			mConnectionFlags; /*"The flags to be used for the connection to the database."*/
}
/*"
Getting default of MySQL
"*/
+ (NSDictionary *) getMySQLLocales;
+ (NSStringEncoding) encodingForMySQLEncoding:(const char *) mysqlEncoding;
+ (NSStringEncoding) defaultMySQLEncoding;

/*"
Class maintenance
"*/
+ (void) initialize;
+ (void) setLogQueries:(BOOL) iLogFlag;
+ (void) setTruncateLongFieldInLogs:(BOOL) iTruncFlag;
+ (BOOL) truncateLongField;

/*"
Initialisation
"*/
- (id) init;
// Port to 0 to use the default port
- (id) initToHost:(NSString *) host withLogin:(NSString *) login password:(NSString *) pass usingPort:(int) port;
- (id) initToSocket:(NSString *) socket withLogin:(NSString *) login password:(NSString *) pass;

- (BOOL) setConnectionOption:(int) option toValue:(BOOL) value;
// Port to 0 to use the default port
- (BOOL) connectWithLogin:(NSString *) login password:(NSString *) pass host:(NSString *) host port:(int) port socket:(NSString *) socket;

- (BOOL) selectDB:(NSString *) dbName;

/*"
Errors information
"*/

- (NSString *) getLastErrorMessage;
- (unsigned int) getLastErrorID;
- (BOOL) isConnected;
- (BOOL) checkConnection;

/*"
Queries
"*/

- (NSString *) prepareBinaryData:(NSData *) theData;
- (NSString *) prepareString:(NSString *) theString;
- (NSString *) quoteObject:(id) theObject;

- (MCPResult *) queryString:(NSString *) query;

- (my_ulonglong) affectedRows;
- (my_ulonglong) insertId;


/*"
Getting description of the database structure
"*/
- (MCPResult *) listDBs;
- (MCPResult *) listDBsLike:(NSString *) dbsName;
- (MCPResult *) listTables;
- (MCPResult *) listTablesLike:(NSString *) tablesName;
// Next method uses SHOW TABLES FROM db to be sure that the db is not changed during this call.
- (MCPResult *) listTablesFromDB:(NSString *) dbName like:(NSString *) tablesName;
- (MCPResult *) listFieldsFromTable:(NSString *) tableName;
- (MCPResult *) listFieldsFromTable:(NSString *) tableName like:(NSString *) fieldsName;

/*"
Server information and control
"*/

- (NSString *) clientInfo;
- (NSString *) hostInfo;
- (NSString *) serverInfo;
- (NSNumber *) protoInfo;
- (MCPResult *) listProcesses;
- (BOOL) killProcess:(unsigned long) pid;

//- (BOOL)createDBWithName:(NSString *)dbName;
//- (BOOL)dropDBWithName:(NSString *)dbName;

/*"
Disconnection
"*/
- (void) disconnect;
- (void) dealloc;

/*"
String encoding concerns (C string type to NSString).
It's unlikely that users of the framework needs to use these methods which are used internally
"*/
- (void) setEncoding:(NSStringEncoding) theEncoding;
- (NSStringEncoding) encoding;

- (const char *) cStringFromString:(NSString *) theString;
- (NSString *) stringWithCString:(const char *) theCString;

/*"
Text data convertion to string
"*/
- (NSString *) stringWithText:(NSData *) theTextData;

/*" Time Zone handling ."*/
- (void) setTimeZone:(NSTimeZone *) iTimeZone;
- (NSTimeZone *) timeZone;

@end
