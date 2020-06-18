//
//  SPLogger.h
//  sequel-pro
//
//  Created by Rowan Beentje on June 17, 2009.
//  Copyright (c) 2009 Rowan Beentje. All rights reserved.
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
//  More info at <https://github.com/sequelpro/sequelpro>

#import "SPSingleton.h"

@interface SPLogger : SPSingleton 
{
	/**
	 * Dump leaks on termination flag.
	 */
	BOOL dumpLeaksOnTermination;
	
	/**
	 * Remove old leak dumps on termination flag.
	 */
	BOOL removeOldLeakDumpsOnTermination;
	
	/**
	 * Log file initialized successfully flag.
	 */
	BOOL initializedSuccessfully;
	
	/**
	 * Log file handle.
	 */
	NSFileHandle *logFileHandle;
}

/**
 * Returns the shared logger.
 * 
 * @return The logger instance
 */
+ (SPLogger *)logger;

@property(readwrite, assign) BOOL dumpLeaksOnTermination;
@property(readwrite, assign) BOOL removeOldLeakDumpsOnTermination;

/**
 * Dumps the result of running leaks to the file '~/tmp/sp.leaks.<pid>.tmp'.
 *
 * Note, that to enable useful output, make sure the following environment variables are set to YES:
 *
 *     MallocStackLogging
 *     MallocStackLoggingNoCompact
 *
 * Also note that the application may take a while to terminate if it has been running for a significant
 * period of time or has been handling large amounts of data.
 */
- (void)dumpLeaks;

/**
 * Logs the supplied string to the log file.
 */
- (void)log:(NSString *)theString, ...;

@end
