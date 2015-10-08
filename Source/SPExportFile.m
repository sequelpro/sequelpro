//
//  SPExportFile.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on July 31, 2010.
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
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

#import "SPExportFile.h"
#import "SPFileHandle.h"

@interface SPExportFile ()

- (SPExportFileHandleStatus)_createFileHandle;

@end

@implementation SPExportFile

@synthesize exportFilePath;
@synthesize exportFileHandle;
@synthesize exportFileNeedsCSVHeader;
@synthesize exportFileNeedsXMLHeader;
@synthesize exportFileHandleStatus;

#pragma mark -
#pragma mark Initialisation

/**
 * Initialise an autoreleased instance of SPExport using the supplied path.
 *
 * @param path The path of the export file
 *
 * @return The initialised instance
 */
+ (SPExportFile *)exportFileAtPath:(NSString *)path
{
	return [[[SPExportFile alloc] initWithFilePath:path] autorelease];
}

/**
 * Initialise an instance of SPExportFile using the supplied path.
 *
 * @param path The path of the export file
 *
 * @return The initialised instance
 */
- (id)initWithFilePath:(NSString *)path
{
	if ((self = [super init])) {
		
		[self setExportFilePath:path];
		
		exportFileHandleStatus = -1;
		
		[self setExportFileNeedsCSVHeader:NO];
		[self setExportFileNeedsXMLHeader:NO];
	}
	
	return self;
}

#pragma mark -
#pragma mark General Methods

/**
 * Closes the export file to writing.
 */
- (void)close
{
	if (![self exportFileHandle]) return;
	
	[[self exportFileHandle] closeFile];
}

/**
 * Deletes the export file on disk.
 *
 * @return A BOOL indicating the success of attempting to delete the file
 */
- (BOOL)delete
{
	if ((![self exportFilePath]) || (![self exportFileHandle]) || ([[self exportFilePath] length] == 0)) return NO;

	// Ensure the file is closed to allow all processing threads to close
	[self close];

	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	if ([fileManager fileExistsAtPath:[self exportFilePath]]) {
		return [[NSFileManager defaultManager] removeItemAtPath:[self exportFilePath] error:nil];
	}
	
	return NO;
}

/**
 * This is a convenience method provided in order to write the supplied data to the underlying filehandle
 * without having to directly access it. Throws an exception if attempting to write data when no file 
 * handle exists.
 *
 * @param data The data to be written
 */
- (void)writeData:(NSData *)data
{
	if (![self exportFileHandle]) {
		[NSException raise:NSInternalInconsistencyException format:@"Attempting to write to an uninitialized file handle."];
		
		return;
	}
			
	[[self exportFileHandle] writeData:data];
}

/**
 * Creates the underlying export file handle and thus the actual file on disk.
 *
 * @param overwrite If true and a file already exists at this file's location, then it'll be overwritten.
 * 
 * @return One of SPExportFileHandleStatus indicating the status of its creation.
 */
- (SPExportFileHandleStatus)createExportFileHandle:(BOOL)overwrite
{
	// The file path must be set before attempting to create the file handle
	if ((![self exportFilePath]) || ([[self exportFilePath] length] == 0)) {
		[NSException raise:NSInternalInconsistencyException 
					format:@"Attempting to create an export filehandle for a path that is either not set or has zero length: %@." , [self exportFilePath]];
		
		return SPExportFileHandleFailed;
	}
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
		
	if ([fileManager fileExistsAtPath:[self exportFilePath]]) {
		
		// If specified attempt to overwrite the file
		if (overwrite) {
			// Check that it's writable first
			if ([fileManager isWritableFileAtPath:[self exportFilePath]]) {
				exportFileHandleStatus = [self _createFileHandle];
			}
			// The file is not writable, so return that we failed.
			else {
				exportFileHandleStatus = SPExportFileHandleFailed;
			}
		}
		else {
			exportFileHandleStatus = SPExportFileHandleExists;
		}
	} 
	// Otherwise attempt to create a file
	else {
		exportFileHandleStatus = [self _createFileHandle];
	}
	
	return exportFileHandleStatus;
}

/**
 * Sets the compression level on the newly created file. Throws an exception
 * if attempting to set the compression level when no file handle exists.
 *
 * @param fileCompressionFormat The compression level to support, from the SPFileCompressionFormat enum.
 */
- (void)setCompressionFormat:(SPFileCompressionFormat)fileCompressionFormat
{
	if (![self exportFileHandle]) {
		[NSException raise:NSInternalInconsistencyException format:@"Attempting to set compression level of an uninitialized file handle."];
		return;
	}

	[[self exportFileHandle] setCompressionFormat:fileCompressionFormat];
}

#pragma mark -
#pragma mark Private API

/**
 * Creates the actual empty file handle and establishes a file handle to it.
 *
 * @return The status of the file handle's creation. See SPExportFileHandleStatus constants.
 */
- (SPExportFileHandleStatus)_createFileHandle
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	if (![fileManager createFileAtPath:[self exportFilePath] contents:[NSData data] attributes:nil]) {
		return SPExportFileHandleFailed;
	}
	
	// Retrieve a filehandle for the file, attempting to delete it on failure.
	exportFileHandle = [[SPFileHandle fileHandleForWritingAtPath:[self exportFilePath]] retain];
	
	if (!exportFileHandle) {
		[[NSFileManager defaultManager] removeItemAtPath:[self exportFilePath] error:nil];
		
		return SPExportFileHandleFailed;
	}
	
	return SPExportFileHandleCreated;
}

#pragma mark -

- (void)dealloc
{
	if (exportFileHandle) SPClear(exportFileHandle);
	
	[super dealloc];
}

@end
