//
//  $Id$
//
//  FLXPostgresTypes.h
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
typedef Oid FLXPostgresOid;

// See PostgreSQL source: include/catalog/pg_type.h

enum 
{
	// BOOL
	FLXPostgresOidBool         = 16,  // NumberHandler              => NSNumber
	FLXPostgresOidData         = 17,  // Currently not supported    
	
	// Text
	FLXPostgresOidName         = 19,  // StringHandler              => NSString   
	
	// Integers
	FLXPostgresOidInt8         = 20,  // NumberHandler              => NSNumber
	FLXPostgresOidInt2         = 21,  // NumberHandler              => NSNumber
	FLXPostgresOidInt4         = 23,  // NumberHandler              => NSNumber
	
	// Text
	FLXPostgresOidText         = 25,  // StringHandler              => NSString
	
	// OID
	FLXPostgresOidOid          = 26,  // Currently not supported
	
	// XML
	FLXPostgresOidXML          = 142, // Currently not supported
	
	// Geometric
	FLXPostgresOidPoint        = 600, // Currently not supported
	FLXPostgresOidLSeg         = 601, // Currently not supported
	FLXPostgresOidPath         = 602, // Currently not supported
	FLXPostgresOidBox          = 603, // Currently not supported
	FLXPostgresOidPolygon      = 604, // Currently not supported
	
	// Float
	FLXPostgresOidFloat4       = 700, // NumberHandler              => NSNumber
	FLXPostgresOidFloat8       = 701, // NumberHandler              => NSNumber 
	
	// ABS Time
	FLXPostgresOidAbsTime      = 702, // DateHandler                => NSDate
	
	// What!
	FLXPostgresOidUnknown      = 705, // StringHandler              => NSString
	
	// Geometric
	FLXPostgresOidCircle       = 718, // Currently not supported
	
	// Monetary
	FLXPostgresOidMoney        = 790, // Currently not supported
	
	// Network
	FLXPostgresOidMacAddr      = 829, // Currently not supported
	FLXPostgresOidIPAddr       = 869, // Currently not supported
	FLXPostgresOidNetAddr      = 869, // Currently not supported
	
	// Arrays
	FLXPostgresOidArrayBool    = 1000, // Currently not supported
	FLXPostgresOidArrayData    = 1001, // Currently not supported   
	FLXPostgresOidArrayChar    = 1002, // Currently not supported
	FLXPostgresOidArrayName    = 1003, // Currently not supported
	FLXPostgresOidArrayInt2    = 1005, // Currently not supported
	FLXPostgresOidArrayInt4    = 1007, // Currently not supported
	FLXPostgresOidArrayText    = 1009, // Currently not supported
	FLXPostgresOidArrayVarchar = 1015, // Currently not supported
	FLXPostgresOidArrayInt8    = 1016, // Currently not supported
	FLXPostgresOidArrayFloat4  = 1021, // Currently not supported
	FLXPostgresOidArrayFloat8  = 1022, // Currently not supported
	FLXPostgresOidArrayMacAddr = 1040, // Currently not supported
	FLXPostgresOidArrayIPAddr  = 1041, // Currently not supported
	
	// Text
	FLXPostgresOidChar         = 1042, // StringHandler              => NSString 
	FLXPostgresOidVarchar      = 1043, // StringHandler              => NSString
	
	// Date/time
	FLXPostgresOidDate         = 1082, // DateHandler                => NSDate
	FLXPostgresOidTime         = 1083, // DateHandler                => NSDate
	FLXPostgresOidTimestamp    = 1114, // DateHandler                => NSDate
	FLXPostgresOidTimestampTZ  = 1184, // DateHandler                => FLXPostgresTimeTZ
	FLXPostgresOidInterval     = 1186, // DateHandler                => FLXPostgresTimeInterval
	FLXPostgresOidTimeTZ       = 1266, // DateHandler                => FLXPostgresTimeTZ
	
	// Binary
	FLXPostgresOidBit          = 1560, // Currently not supported
	FLXPostgresOidVarbit       = 1562, // Currently not supported
	
	// Numeric
	FLXPostgresOidNumeric      = 1700, // StringHandler              => NSString
	FLXPostgresOidMax          = 1700  // Currently not supported
};
