//
//  $Id$
//
//  SPFileHandle.h
//  sequel-pro
//
//  Created by Rowan Beentje on April 5, 2010
//  Copyright (c) 2010 Rowan Beentje. All rights reserved.
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

/**
 * Provides a class which aims to duplicate some of the most-used functionality
 * of NSFileHandle, while also transparently supporting gzip and bzip2 compressed content
 * on reading; gzip and bzip2 compression is also supported on writing.
 */

#import <Cocoa/Cocoa.h>

#import "SPConstants.h"

@interface SPFileHandle : NSObject 
{
	void *wrappedFile;
	char *wrappedFilePath;

	NSMutableData *buffer;
	NSUInteger bufferDataLength;
	NSUInteger bufferPosition;
	BOOL endOfFile;
	pthread_mutex_t bufferLock;
	NSThread *processingThread;

	int fileMode;
	BOOL dataWritten;
	BOOL allDataWritten;
	BOOL fileIsClosed;
	BOOL useCompression;
	
	SPFileCompressionFormat compressionFormat;
}

#pragma mark -
#pragma mark Class methods

+ (id)fileHandleForReadingAtPath:(NSString *)path;
+ (id)fileHandleForWritingAtPath:(NSString *)path;
+ (id)fileHandleForPath:(NSString *)path mode:(int)mode;

#pragma mark -
#pragma mark Initialisation

// Returns a file handle initialised with a file
- (id)initWithFile:(void *)theFile fromPath:(const char *)path mode:(int)mode;

#pragma mark -
#pragma mark Data reading

// Reads data up to a specified number of bytes from the file
- (NSMutableData *)readDataOfLength:(NSUInteger)length;

// Returns the data to the end of the file
- (NSMutableData *)readDataToEndOfFile;

// Returns the on-disk (raw) length of data read so far - can be used in progress bars
- (NSUInteger)realDataReadLength;

#pragma mark -
#pragma mark Data writing

// Set whether data should be written in the supplied compression format (defaults to NO on a fresh object)
- (void)setShouldWriteWithCompressionFormat:(SPFileCompressionFormat)useCompressionFormat;

// Write the provided data to the file
- (void)writeData:(NSData *)data;

// Ensures any buffers are written to disk
- (void)synchronizeFile;

// Prevents further access to the file
- (void)closeFile;

#pragma mark -
#pragma mark File information

// Returns whether compression is enabled on the file
- (BOOL)isCompressed;

// Returns the compression format being used. Currently gzip or bzip2 only.
- (SPFileCompressionFormat)compressionFormat;

@end
