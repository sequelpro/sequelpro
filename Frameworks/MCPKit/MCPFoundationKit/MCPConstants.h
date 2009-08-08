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
typedef enum {
    MCPTypeArray = 1,
    MCPTypeDictionary = 2,
    MCPTypeFlippedArray = 3,
    MCPTypeFlippedDictionary = 4
} MCPReturnType;

// Connection check constants
typedef enum {
	MCPConnectionCheckRetry = 0,
	MCPConnectionCheckReconnect = 1,
	MCPConnectionCheckDisconnect = 2
} MCPConnectionCheck;

// Charcater set mapping constants
typedef struct _OUR_CHARSET
{
	unsigned int nr;
	const char	 *name;
	const char	 *collation;
	unsigned int char_minlen;
	unsigned int char_maxlen;
} OUR_CHARSET;

// Deafult connection option
extern const unsigned int kMCPConnectionDefaultOption;

// Default socket (from the mysql.h used at compile time)
extern const char *kMCPConnectionDefaultSocket;

// Added to MySQL error code
extern const unsigned int kMCPConnectionNotInited;

// The length of the truncation if required
extern const unsigned int kLengthOfTruncationForLog;
