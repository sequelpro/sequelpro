//
//  SPExporter.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on August 29, 2009.
//  Copyright (c) 2009 Stuart Connolly. All rights reserved.
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

#import "SPExporter.h"
#import "SPExportFile.h"
#import "SPFileHandle.h"

@implementation SPExporter

@synthesize connection;
@synthesize serverSupport = serverSupport;
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
 * Override NSOperation's main() method.
 * This method only creates an autoreleasepool and calls exportOperation
 */
- (void)main
{
	@autoreleasepool {
		@try {
			[self exportOperation];
		}
		@catch(NSException *e) {
			[[NSApp onMainThread] reportException:e];
		}
	}
}

/**
 * This method should never be called as all subclasses should override it.
 */
- (void)exportOperation
{
	[NSException raise:NSInternalInconsistencyException format:@"Cannot call %s, must be overriden in a subclass. See SPExporter.h",__PRETTY_FUNCTION__];
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
	
	[[[self exportOutputFile] exportFileHandle] setCompressionFormat:(compress) ? [self exportOutputCompressionFormat] : SPNoCompression];
}

- (void)writeString:(NSString *)input
{
	[[self exportOutputFile] writeData:[input dataUsingEncoding:[self exportOutputEncoding]]];
}

- (void)writeUTF8String:(NSString *)input
{
	[[self exportOutputFile] writeData:[input dataUsingEncoding:NSUTF8StringEncoding]];
}

/**
 * Get rid of the export data.
 */
- (void)dealloc
{
	if (exportData) SPClear(exportData);
	if (connection) SPClear(connection);
	[self setServerSupport:nil];
	if (exportOutputFile) SPClear(exportOutputFile);
	
	[super dealloc];
}

@end
