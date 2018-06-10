//
//  SPFileHandle.h
//  sequel-pro
//
//  Created by Rowan Beentje on April 5, 2010.
//  Copyright (c) 2010 Rowan Beentje. All rights reserved.
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

struct SPRawFileHandles;
/**
 * @class SPFileHandle SPFileHandle.h
 *
 * @author Rowan Beentje
 *
 * Provides a class which aims to duplicate some of the most-used functionality
 * of NSFileHandle, while also transparently supporting gzip and bzip2 compressed content
 * on reading; gzip and bzip2 compression is also supported on writing.
 */
@interface SPFileHandle : NSObject 
{
	struct SPRawFileHandles *wrappedFile;
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
- (id)initWithFile:(FILE *)theFile fromPath:(const char *)path mode:(int)mode;

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
// This has no influence on reading data.
- (void)setCompressionFormat:(SPFileCompressionFormat)useCompressionFormat;

// Returns the compression format being used. Currently gzip or bzip2 only.
- (SPFileCompressionFormat)compressionFormat;

// Write the provided data to the file
- (void)writeData:(NSData *)data;

// Ensures any buffers are written to disk
- (void)synchronizeFile;

// Prevents further access to the file
- (void)closeFile;

@end
