//
//  $Id$
//
//  FLXConstants.m
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

// Connection defaults
const NSUInteger FLXPostgresConnectionDefaultTimeout    = 30;
const NSUInteger FLXPostgresConnectionDefaultServerPort = 5432;
const NSUInteger FLXPostgresConnectionDefaultKeepAlive  = 60;

NSString *FLXPostgresConnectionDefaultEncoding              = @"UNICODE";
NSString *FLXPostgresConnectionErrorDomain                  = @"FLXPostgresConnectionError";
NSStringEncoding FLXPostgresConnectionDefaultStringEncoding = NSUTF8StringEncoding;

// Server parameters
NSString *FLXPostgresParameterServerEncoding   = @"server_encoding";
NSString *FLXPostgresParameterClientEncoding   = @"client_encoding";
NSString *FLXPostgresParameterSuperUser        = @"is_superuser";
NSString *FLXPostgresParameterTimeZone         = @"TimeZone";
NSString *FLXPostgresParameterIntegerDateTimes = @"integer_datetimes";

// Result value specifiers
const char *FLXPostgresResultValueMacAddr    = "%macaddr"; 
const char *FLXPostgresResultValueInet       = "%inet";
const char *FLXPostgresResultValueCidr       = "%cidr";
const char *FLXPostgresResultValueDate       = "%date";
const char *FLXPostgresResultValueTime       = "%time";
const char *FLXPostgresResultValueTimeTZ     = "%timetz";
const char *FLXPostgresResultValueTimestamp  = "%timestamp";
const char *FLXPostgresResultValueTimestmpTZ = "%timestamptz";
const char *FLXPostgresResultValueInterval   = "%interval";
const char *FLXPostgresResultValueNumeric    = "%numeric";
const char *FLXPostgresResultValueBool       = "%bool";
const char *FLXPostgresResultValueInt2       = "%int2";
const char *FLXPostgresResultValueInt4       = "%int4";
const char *FLXPostgresResultValueInt8       = "%int8";
const char *FLXPostgresResultValueFloat4     = "%float4";
const char *FLXPostgresResultValueFloat8     = "%float8";

// Connection parameters
const char *FLXPostgresKitApplicationName     = "PostgresKit";
const char *FLXPostgresApplicationParam       = "application_name";
const char *FLXPostgresUserParam              = "user";
const char *FLXPostgresHostParam              = "host";
const char *FLXPostgresPasswordParam          = "password";
const char *FLXPostgresPortParam              = "port";
const char *FLXPostgresDatabaseParam          = "dbname";
const char *FLXPostgresClientEncodingParam    = "client_encoding";
const char *FLXPostgresKeepAliveParam         = "keepalives";
const char *FLXPostgresKeepAliveIntervalParam = "keepalives_interval";
