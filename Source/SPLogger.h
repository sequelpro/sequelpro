//
//  $Id$
//
//  SPLogger.h
//  sequel-pro
//
//  Created by Rowan Beentje on 17/06/2009.
//  Copyright 2009 Rowan Beentje. All rights reserved.
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
//  More info at <http://code.google.com/p/sequel-pro/>

#import <Cocoa/Cocoa.h>

@interface SPLogger : NSObject 
{
	/**
	 * Dump leaks on termination flag.
	 */
	BOOL dumpLeaksOnTermination;
	
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

/**
 * Tells the logger to dump leaks analysis upon app termination.
 */
- (void)setDumpLeaksOnTermination;

/**
 * Dumps the result of running leaks to the file '/tmp/sp.leaks.<pid>.tmp'.
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
