//
//  $Id: PGConstants.h 3866 2012-09-26 01:30:28Z stuart02 $
//
//  PGConstants.h
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
extern const NSUInteger PGPostgresConnectionDefaultTimeout;
extern const NSUInteger PGPostgresConnectionDefaultServerPort;
extern const NSUInteger PGPostgresConnectionDefaultKeepAlive;

extern NSString *PGPostgresConnectionDefaultEncoding;
extern NSString *PGPostgresConnectionErrorDomain;
extern NSStringEncoding PGPostgresConnectionDefaultStringEncoding;

// Server parameters
extern NSString *PGPostgresParameterServerEncoding;
extern NSString *PGPostgresParameterClientEncoding;
extern NSString *PGPostgresParameterSuperUser;
extern NSString *PGPostgresParameterTimeZone;
extern NSString *PGPostgresParameterIntegerDateTimes;

// Result value specifiers
extern const char *PGPostgresResultValueMacAddr;
extern const char *PGPostgresResultValueInet;
extern const char *PGPostgresResultValueCidr;
extern const char *PGPostgresResultValueDate;
extern const char *PGPostgresResultValueTime;
extern const char *PGPostgresResultValueTimeTZ;
extern const char *PGPostgresResultValueTimestamp;
extern const char *PGPostgresResultValueTimestmpTZ;
extern const char *PGPostgresResultValueInterval;
extern const char *PGPostgresResultValueNumeric;
extern const char *PGPostgresResultValueBool;
extern const char *PGPostgresResultValueInt2;
extern const char *PGPostgresResultValueInt4;
extern const char *PGPostgresResultValueInt8;
extern const char *PGPostgresResultValueFloat4;
extern const char *PGPostgresResultValueFloat8;
extern const char *PGPostgresResultValueByteA;

// Connection parameters
extern const char *PGPostgresKitApplicationName;
extern const char *PGPostgresApplicationParam;
extern const char *PGPostgresUserParam;
extern const char *PGPostgresHostParam;
extern const char *PGPostgresPasswordParam;
extern const char *PGPostgresPortParam;
extern const char *PGPostgresDatabaseParam;
extern const char *PGPostgresClientEncodingParam;
extern const char *PGPostgresKeepAliveParam;
extern const char *PGPostgresKeepAliveIntervalParam;
