//
//  $Id$
//
//  MCPConstants.h
//  MCPKit
//
//  Created by Serge Cohen (serge.cohen@m4x.org) on 03/06/2001.
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

// Result type constants
enum {
    MCPTypeArray = 1,
    MCPTypeDictionary = 2,
    MCPTypeFlippedArray = 3,
    MCPTypeFlippedDictionary = 4
};
typedef NSUInteger MCPReturnType;

// Connection check constants
enum {
	MCPConnectionCheckRetry = 0,
	MCPConnectionCheckReconnect = 1,
	MCPConnectionCheckDisconnect = 2
};
typedef NSUInteger MCPConnectionCheck;

// Streaming result set constants
enum
{
	MCPStreamingNone   = 0,
	MCPStreamingFast   = 1,
	MCPStreamingLowMem = 2
};
typedef NSUInteger MCPQueryStreamingType;

// Charcater set mapping constants
typedef struct _OUR_CHARSET
{
	NSUInteger nr;
	const char *name;
	const char *collation;
	NSUInteger char_minlen;
	NSUInteger char_maxlen;
} OUR_CHARSET;

// Deafult connection option
extern const NSUInteger kMCPConnectionDefaultOption;

// Default socket (from the mysql.h used at compile time)
extern const char *kMCPConnectionDefaultSocket;

// Added to MySQL error code
extern const NSUInteger kMCPConnectionNotInited;

// The length of the truncation if required
extern const NSUInteger kLengthOfTruncationForLog;
