//
//  $Id$
//
//  SPMySQL.h
//  SPMySQLFramework
//
//  Created by Rowan Beentje (rowan.beent.je) on January 22, 2012
//  Copyright (c) 2012 Rowan Beentje. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//
//  More info at <http://code.google.com/p/sequel-pro/>

@class SPMySQLConnection, SPMySQLResult, SPMySQLStreamingResult, SPMySQLFastStreamingResult;

// Global include file for the framework.
// Constants
#import "SPMySQLConstants.h"

// Required category additions
#ifndef SP_REFACTOR
#import "SPMySQLStringAdditions.h"
#else
#import <SPMySQL/SPMySQL.h>
#endif

// MySQL Connection Delegate and Proxy protocols
#import "SPMySQLConnectionDelegate.h"
#import "SPMySQLConnectionProxy.h"

// MySQL Connection class and public categories
#import "SPMySQLConnection.h"
#import "Delegate & Proxy.h"
#import "Databases & Tables.h"
#import "Max Packet Size.h"
#import "Querying & Preparation.h"
#import "Encoding.h"
#import "Server Info.h"

// MySQL result set, streaming subclasses of same, and associated categories
#import "SPMySQLResult.h"
#import "SPMySQLStreamingResult.h"
#import "SPMySQLFastStreamingResult.h"
#import "Field Definitions.h"
#import "Convenience Methods.h"

// Result data objects
#import "SPMySQLGeometryData.h"
