//
//  $Id$
//
//  FLXConstants.h
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

// Defaults
extern NSString *FLXPostgresConnectionDefaultEncoding;
extern NSString *FLXPostgresConnectionErrorDomain;
extern NSStringEncoding FLXPostgresConnectionDefaultStringEncoding;

// Server parameters
extern NSString *FLXPostgresParameterServerEncoding;
extern NSString *FLXPostgresParameterClientEncoding;
extern NSString *FLXPostgresParameterSuperUser;
extern NSString *FLXPostgresParameterTimeZone;
extern NSString *FLXPostgresParameterIntegerDateTimes;

// Value specifiers
extern const char *FLXPostgresResultValueMacAddr;
extern const char *FLXPostgresResultValueInet;
extern const char *FLXPostgresResultValueCidr;
extern const char *FLXPostgresResultValueDate;
extern const char *FLXPostgresResultValueTime;
extern const char *FLXPostgresResultValueTimeTZ;
extern const char *FLXPostgresResultValueTimestamp;
extern const char *FLXPostgresResultValueTimestmpTZ;
extern const char *FLXPostgresResultValueInterval;
