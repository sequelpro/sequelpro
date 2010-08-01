//
//  $Id$
//
//  MCPStreamingResult.h
//  sequel-pro
//
//  Created by Rowan Beentje on Aug 16, 2009
//  Copyright 2009 Rowan Beentje. All rights reserved.
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

#import <Foundation/Foundation.h>

#import "MCPResult.h"
#import "mysql.h"

@class MCPConnection;

typedef struct SP_MYSQL_ROWS {
	char *data;
	unsigned long *dataLengths;
	struct SP_MYSQL_ROWS *nextRow;
} LOCAL_ROW_DATA;

@interface MCPStreamingResult : MCPResult
{
	MCPConnection *parentConnection;

	MYSQL_FIELD *fieldDefinitions;
	
	BOOL fullyStreaming;
	BOOL connectionUnlocked;
	BOOL dataDownloaded;
	BOOL dataFreed;
	
	LOCAL_ROW_DATA *localDataStore;
	LOCAL_ROW_DATA *currentDataStoreEntry;
	LOCAL_ROW_DATA *localDataStoreLastEntry;
	
	unsigned long localDataRows;
	unsigned long localDataAllocated;
	unsigned long downloadedRowCount;
	unsigned long processedRowCount;
	unsigned long freedRowCount;
	
	pthread_mutex_t dataCreationLock;
	pthread_mutex_t dataFreeLock;
	
	IMP isConnectedPtr;
	SEL isConnectedSEL;
}

- (id)initWithMySQLPtr:(MYSQL *)mySQLPtr encoding:(NSStringEncoding)theEncoding timeZone:(NSTimeZone *)theTimeZone connection:(MCPConnection *)theConnection;
- (id)initWithMySQLPtr:(MYSQL *)mySQLPtr encoding:(NSStringEncoding)theEncoding timeZone:(NSTimeZone *)theTimeZone connection:(MCPConnection *)theConnection withFullStreaming:(BOOL)useFullStreaming;

// Results fetching
- (NSArray *)fetchNextRowAsArray;
- (void) cancelResultLoad;

@end