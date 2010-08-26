//
//  $Id$
//
//  SPExportFile.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on July 31, 2010
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
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

#import "SPExportFile.h"

@interface SPExportFile (PrivateAPI)

- (SPExportFileHandleStatus)_createFileHandle;

@end

@implementation SPExportFile

@synthesize exportFilePath;
@synthesize exportFileHandle;
@synthesize exportFileNeedsCSVHeader;
@synthesize exportFileNeedsXMLHeader;
@synthesize exportFileHandleStatus;

#pragma mark -
#pragma mark Initialization

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
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	if ([fileManager fileExistsAtPath:[self exportFilePath]]) {
		return [[NSFileManager defaultManager] removeItemAtPath:[self exportFilePath] error:nil];
	}
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
					format:@"Attempting to create an export filehandle for a path that is either not set or has zero length: %@." 
				 arguments:[self exportFilePath]];
		
		return;
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

	[[self exportFileHandle] setShouldWriteWithCompressionFormat:fileCompressionFormat];
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
		[[NSFileManager defaultManager] removeFileAtPath:[self exportFilePath] handler:nil];
		
		return SPExportFileHandleFailed;
	}
	
	return SPExportFileHandleCreated;
}

#pragma mark -
#pragma mark Other

/**
 * Dealloc.
 */
- (void)dealloc
{
	if (exportFileHandle) [exportFileHandle release], exportFileHandle = nil; 
}

@end
