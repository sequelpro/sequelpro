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
	FLXPostgresOidBool         = 16,
	FLXPostgresOidData         = 17,
	FLXPostgresOidName         = 19,
	FLXPostgresOidInt8         = 20,
	FLXPostgresOidInt2         = 21,
	FLXPostgresOidInt4         = 23,
	FLXPostgresOidText         = 25,
	FLXPostgresOidOid          = 26,
	FLXPostgresOidXML          = 142,
	FLXPostgresOidPoint        = 600,
	FLXPostgresOidLSeg         = 601,
	FLXPostgresOidPath         = 602,
	FLXPostgresOidBox          = 603,
	FLXPostgresOidPolygon      = 604,
	FLXPostgresOidFloat4       = 700,
	FLXPostgresOidFloat8       = 701,
	FLXPostgresOidAbsTime      = 702,
	FLXPostgresOidUnknown      = 705,
	FLXPostgresOidCircle       = 718,
	FLXPostgresOidMoney        = 790,
	FLXPostgresOidMacAddr      = 829,
	FLXPostgresOidIPAddr       = 869,
	FLXPostgresOidNetAddr      = 869,
	FLXPostgresOidArrayBool    = 1000,
	FLXPostgresOidArrayData    = 1001,
	FLXPostgresOidArrayChar    = 1002,
	FLXPostgresOidArrayName    = 1003,
	FLXPostgresOidArrayInt2    = 1005,
	FLXPostgresOidArrayInt4    = 1007,
	FLXPostgresOidArrayText    = 1009,
	FLXPostgresOidArrayVarchar = 1015,
	FLXPostgresOidArrayInt8    = 1016,
	FLXPostgresOidArrayFloat4  = 1021,
	FLXPostgresOidArrayFloat8  = 1022,
	FLXPostgresOidArrayMacAddr = 1040,
	FLXPostgresOidArrayIPAddr  = 1041,
	FLXPostgresOidChar         = 1042,
	FLXPostgresOidVarchar      = 1043,
	FLXPostgresOidDate         = 1082,
	FLXPostgresOidTime         = 1083,
	FLXPostgresOidTimestamp    = 1114,
	FLXPostgresOidTimestampTZ  = 1184,
	FLXPostgresOidInterval     = 1186,
	FLXPostgresOidTimeTZ       = 1266,
	FLXPostgresOidBit          = 1560,
	FLXPostgresOidVarbit       = 1562,
	FLXPostgresOidNumeric      = 1700,
	FLXPostgresOidMax          = 1700
};
