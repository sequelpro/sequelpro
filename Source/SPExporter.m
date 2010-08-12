//
//  $Id$
//
//  SPExporter.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on August 29, 2009
//  Copyright (c) 2009 Stuart Connolly. All rights reserved.
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

#import "SPExporter.h"

@implementation SPExporter

@synthesize connection;
@synthesize exportProgressValue;
@synthesize exportProcessIsRunning;
@synthesize exportUsingLowMemoryBlockingStreaming;
@synthesize exportOutputCompressionFormat;
@synthesize exportData;
@synthesize exportOutputFile;
@synthesize exportOutputEncoding;
@synthesize exportMaxProgress;

/**
 * Initialise an instance of SPExporter, while setting some default values.
 */
- (id)init
{
	if ((self = [super init])) {		
		[self setExportProgressValue:0];
		[self setExportProcessIsRunning:NO];
		[self setExportOutputCompressFile:NO];
		[self setExportOutputCompressionFormat:SPNoCompression];
		
		// Default the resulting data to an empty string
		[self setExportData:[NSString string]];
		
		// Default the output encoding to UTF-8
		[self setExportOutputEncoding:NSUTF8StringEncoding];
	}
	
	return self;
}

/**
 * Override NSOperation's main() method. This method should never be called as all subclasses should override it.
 */
- (void)main
{
	[NSException raise:NSInternalInconsistencyException format:@"Cannot call NSOperation's main() method in SPExpoter, must be overriden in a subclass. See SPExporter.h"];
}

/**
 * Returns whether or not file compression is in use.
 *
 * @return A BOOL indicating the use of compression
 */
- (BOOL)exportOutputCompressFile
{
	return exportOutputCompressFile;
}

/**
 * Sets whether or not the resulting output of this exporter should be compressed.
 *
 * @param compress A BOOL indicating the use of compression
 */
- (void)setExportOutputCompressFile:(BOOL)compress
{
	// If the export file handle is nil or a compression format has not yet been set don't proceed
	if ((![exportOutputFile exportFileHandle]) || ([self exportOutputCompressionFormat] == SPNoCompression)) return;
	
	exportOutputCompressFile = compress;
	
	[[[self exportOutputFile] exportFileHandle] setShouldWriteWithCompressionFormat:(compress) ? [self exportOutputCompressionFormat] : SPNoCompression];
}

/**
 * Get rid of the export data.
 */
- (void)dealloc
{
	if (exportData) [exportData release], exportData = nil;
	if (connection) [connection release], connection = nil;
	if (exportOutputFile) [exportOutputFile release], exportOutputFile = nil;
	
	[super dealloc];
}

@end
