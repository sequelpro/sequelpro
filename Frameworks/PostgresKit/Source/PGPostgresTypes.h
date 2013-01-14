//
//  $Id: PGPostgresTypes.h 3861 2012-09-24 12:23:27Z stuart02 $
//
//  PGPostgresTypes.h
//  PostgresKit
//
//  Copyright (c) 2008-2009 David Thorpe, djt@mutablelogic.com
//
//  Forked by the Sequel Pro Team on July 22, 2012.
// 
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not 
//  use this file except in compliance with the License. You may obtain a copy of 
//  the License at
// 
//  http://www.apache.org/licenses/LICENSE-2.0
// 
//  Unless required by applicable law or agreed to in writing, software 
//  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT 
//  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the 
//  License for the specific language governing permissions and limitations under
//  the License.

#import "postgres_ext.h"

// Generic PostgreSQL object ID
typedef Oid PGPostgresOid;

// See PostgreSQL source: include/catalog/pg_type.h
enum 
{
	// BOOL
	PGPostgresOidBool         = 16,  // NumberHandler              => NSNumber
	PGPostgresOidByteData     = 17,  // BinaryHandler              => NSData
	
	// Text
	PGPostgresOidName         = 19,  // StringHandler              => NSString   
	
	// Integers
	PGPostgresOidInt8         = 20,  // NumberHandler              => NSNumber
	PGPostgresOidInt2         = 21,  // NumberHandler              => NSNumber
	PGPostgresOidInt4         = 23,  // NumberHandler              => NSNumber
	
	// Text
	PGPostgresOidText         = 25,  // StringHandler              => NSString
	
	// OID
	PGPostgresOidOid          = 26,  // NumberHandler              => NSNumber
	
	// JSON
	PGPostgresOidJSON         = 114, // StringHandler              => NSString
	
	// XML
	PGPostgresOidXML          = 142, // StringHandler              => NSString
	
	// Geometric
	PGPostgresOidPoint        = 600, // Currently not supported
	PGPostgresOidLSeg         = 601, // Currently not supported
	PGPostgresOidPath         = 602, // Currently not supported
	PGPostgresOidBox          = 603, // Currently not supported
	PGPostgresOidPolygon      = 604, // Currently not supported
	
	// Network
	PGPostgresOidCidrAddr     = 650, // StringHandler              => NSString
	
	// Float
	PGPostgresOidFloat4       = 700, // NumberHandler              => NSNumber
	PGPostgresOidFloat8       = 701, // NumberHandler              => NSNumber 
	
	// ABS Time
	PGPostgresOidAbsTime      = 702, // DateHandler                => NSDate
	
	// What!
	PGPostgresOidUnknown      = 705, // StringHandler              => NSString
	
	// Geometric
	PGPostgresOidCircle       = 718, // Currently not supported
	
	// Monetary
	PGPostgresOidMoney        = 790, // NumberHandler              => NSNumber
	
	// Network
	PGPostgresOidMacAddr      = 829, // StringHandler              => NSString 
	PGPostgresOidInetAddr     = 869, // StringHandler              => NSString
	
	// Arrays
	PGPostgresOidArrayBool    = 1000, // Currently not supported
	PGPostgresOidArrayData    = 1001, // Currently not supported   
	PGPostgresOidArrayChar    = 1002, // Currently not supported
	PGPostgresOidArrayName    = 1003, // Currently not supported
	PGPostgresOidArrayInt2    = 1005, // Currently not supported
	PGPostgresOidArrayInt4    = 1007, // Currently not supported
	PGPostgresOidArrayText    = 1009, // Currently not supported
	PGPostgresOidArrayVarchar = 1015, // Currently not supported
	PGPostgresOidArrayInt8    = 1016, // Currently not supported
	PGPostgresOidArrayFloat4  = 1021, // Currently not supported
	PGPostgresOidArrayFloat8  = 1022, // Currently not supported
	PGPostgresOidArrayMacAddr = 1040, // Currently not supported
	PGPostgresOidArrayIPAddr  = 1041, // Currently not supported
	
	// Text
	PGPostgresOidChar         = 1042, // StringHandler              => NSString 
	PGPostgresOidVarChar      = 1043, // StringHandler              => NSString
	
	// Date/time
	PGPostgresOidDate         = 1082, // DateHandler                => NSDate
	PGPostgresOidTime         = 1083, // DateHandler                => NSDate
	PGPostgresOidTimestamp    = 1114, // DateHandler                => NSDate
	PGPostgresOidTimestampTZ  = 1184, // DateHandler                => PGPostgresTimeTZ
	PGPostgresOidInterval     = 1186, // DateHandler                => PGPostgresTimeInterval
	PGPostgresOidTimeTZ       = 1266, // DateHandler                => PGPostgresTimeTZ
	
	// Bit strings
	PGPostgresOidBit          = 1560, // StringHandler              => NSString
	PGPostgresOidVarBit       = 1562, // StringHandler              => NSString
	
	// Numeric
	PGPostgresOidNumeric      = 1700, // NumberHandler              => NSNumber
	
	// UUID
	PGPostgresOidUUID         = 2950  // StringHandler              => NSString
};
