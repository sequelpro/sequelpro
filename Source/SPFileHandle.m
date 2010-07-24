//
//  $Id$
//
//  SPFileHandle.m
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

#import "SPFileHandle.h"
#import "zlib.1.2.4.h"
#import "bzlib.h"
#import "pthread.h"

// Define the maximum size of the background write buffer before the writing thread
// waits until some has been written out.  This can affect speed and memory usage.
#define SPFH_MAX_WRITE_BUFFER_SIZE 1048576

@interface SPFileHandle (PrivateAPI)

- (void)_writeBufferToData;

@end

@implementation SPFileHandle

#pragma mark -
#pragma mark Setup and teardown

/**
 * Initialises and returns a SPFileHandle with a specified file (FILE, gzFile or BZFILE).
 * "mode" indicates the file interaction mode - currently only read-only
 * or write-only are supported.
 *
 * On reading, theFile can either be one of FILE, gzFile or BZFILE depending on the attempt to
 * determine whether or not the file is in a compressed format (gzip or bzip2). On writing, 
 * theFile is a FILE when compression is disabled, a gzFile when gzip compression is enabled
 * or a BZFILE when bzip2 compression is enabled.
 */
- (id)initWithFile:(void *)theFile fromPath:(const char *)path mode:(int)mode
{
	if (self = [super init]) {
		dataWritten = NO;
		allDataWritten = YES;
		fileIsClosed = NO;

		wrappedFile = theFile;
		wrappedFilePath = malloc(strlen(path) + 1);
		strcpy(wrappedFilePath, path);

		// Check and set the mode
		fileMode = mode;
		
		if (fileMode != O_RDONLY && fileMode != O_WRONLY) {
			[NSException raise:NSInvalidArgumentException format:@"SPFileHandle only supports read-only and write-only file modes"];
		}

		// Instantiate the buffer
		pthread_mutex_init(&bufferLock, NULL);
		
		buffer = [[NSMutableData alloc] init];
		bufferDataLength = 0;
		bufferPosition = 0;
		endOfFile = NO;
		
		useCompression = NO;
		compressionFormat = SPNoCompression;

		// If in read mode, set up the buffer
		if (fileMode == O_RDONLY) {
			
			int i, c;
			char *bzbuf = malloc(4);
			const char *charFileMode = (fileMode == O_WRONLY) ? "wb" : "rb";
			
			BZFILE *bzfile;
			gzFile *gzfile = gzopen(path, charFileMode);
						
			// Set gzip buffer
			gzbuffer(gzfile, 131072);
			
			// Get the first 3 bytes from the file
			for (i = 0; (c = getc(wrappedFile)) != EOF && i < 4; bzbuf[i++] = c);
			
			// Test to see if the file is gzip compressed
			BOOL isGzip = (!gzdirect(gzfile));
			
			// Test to see if the first 2 bytes extracted from the file match the Bzip2 signature/magic number
			// (BZ). The 3rd byte should be either 'h' (Huffman encoding) or 0 (Bzip1 - deprecated) to 
			// indicate the Bzip version. Finally, the 4th byte should be a number between 1 and 9 that indicates
			// the block size used.
			BOOL isBzip2 = ((bzbuf[0] == 'B')   && (bzbuf[1] == 'Z')  && 
							((bzbuf[2] == 'h')  || (bzbuf[2] == '0')) &&
							((bzbuf[3] >= 0x31) && (bzbuf[3] <= 0x39)));
			
			free(bzbuf);
			
			if (isBzip2) bzfile = BZ2_bzopen(path, charFileMode);
						
			useCompression = (isGzip || isBzip2);
									
			if (useCompression) {
				if (isGzip) {
					compressionFormat = SPGzipCompression;
					wrappedFile = gzfile;
				}
				else if (isBzip2) {
					compressionFormat = SPBzip2Compression;
					wrappedFile = bzfile;
					gzclose(gzfile);
				}
				
				fclose(theFile);
			}
			else {
				gzclose(gzfile);
			}
			
			processingThread = nil;
		} 
		// In write mode, set up a thread to handle writing in the background
		else if (fileMode == O_WRONLY) {
			useCompression = NO;
			processingThread = [[NSThread alloc] initWithTarget:self selector:@selector(_writeBufferToData) object:nil];
			[processingThread start];
		}
	}

	return self;
}

/**
 * Dealloc.
 */
- (void)dealloc
{
	[self closeFile];
	if (processingThread) [processingThread release];
	free(wrappedFilePath);
	[buffer release];
	pthread_mutex_destroy(&bufferLock);
	[super dealloc];
}

#pragma mark -
#pragma mark Class methods

/**
 * Retrieve and return a SPFileHandle for reading a file at the supplied
 * path.  Returns nil if the file could not be found or opened.
 */
+ (id)fileHandleForReadingAtPath:(NSString *)path
{
	return [self fileHandleForPath:path mode:O_RDONLY];
}

/**
 * Retrieve and return a SPFileHandle for writing a file at the supplied
 * path.  Returns nil if the file could not be found or opened.
 */
+ (id)fileHandleForWritingAtPath:(NSString *)path
{
	return [self fileHandleForPath:path mode:O_WRONLY];
}

/**
 * Retrieve and return a SPFileHandle for a file at the specified path,
 * using the supplied file status flag. Returns nil if the file could
 * not be found or opened.
 */
+ (id)fileHandleForPath:(NSString *)path mode:(int)mode
{
	// Retrieves the path in a filesystem-appropriate format and encoding
	const char *pathRepresentation = [path fileSystemRepresentation];
	if (!pathRepresentation) return nil;

	// Open the file to get a file descriptor, returning on failure
	const char *theMode = (mode == O_WRONLY) ? "wb" : "rb";
	
	FILE *file = fopen(pathRepresentation, theMode);
	
	if (file == NULL) return nil;

	// Return an autoreleased file handle
	return [[[self alloc] initWithFile:file fromPath:pathRepresentation mode:mode] autorelease];
}

#pragma mark -
#pragma mark Data reading

/**
 * Reads data up to a specified number of uncompressed bytes from the file.
 */
- (NSMutableData *)readDataOfLength:(NSUInteger)length
{	
	long theDataLength;
	void *theData = malloc(length);
			
	if (useCompression) {
		if (compressionFormat == SPGzipCompression) {
			theDataLength = gzread(wrappedFile, theData, length);
		}
		else if (compressionFormat == SPBzip2Compression) {
			theDataLength = BZ2_bzread(wrappedFile, theData, length);
		}		
	}
	else {
		theDataLength = fread(theData, 1, length, wrappedFile);
	}
		
	return [NSMutableData dataWithBytesNoCopy:theData length:theDataLength freeWhenDone:YES];
}

/**
 * Returns all the data to the end of the file.
 */
- (NSMutableData *)readDataToEndOfFile
{
	return [self readDataOfLength:NSUIntegerMax];
}

/**
 * Returns the on-disk (raw/uncompressed) length of data read so far.
 * This includes any compression headers within the data, and can be used
 * for progress bars when processing files.
 */
- (NSUInteger)realDataReadLength
{
	if ((fileMode == O_WRONLY) || (compressionFormat == SPBzip2Compression)) return 0;
	
	if (useCompression && (compressionFormat == SPGzipCompression)) {
		return gzoffset(wrappedFile);
	}
	else {
		return ftell(wrappedFile);
	}
}

#pragma mark -
#pragma mark Data writing

/**
 * Set whether data should be written as gzipped data, defaulting
 * to NO on a fresh object. If this is called after data has been
 * written, an exception is thrown.
 */
- (void)setShouldWriteWithCompressionFormat:(SPFileCompressionFormat)useCompressionFormat
{
	if (compressionFormat == useCompressionFormat) return;

	// Regardless of the supplied argument, close the current file according to how it was previously opened
	if (useCompression) {
		if (compressionFormat == SPGzipCompression) {
			gzclose(wrappedFile);
		}
		else if (compressionFormat == SPBzip2Compression) {
			BZ2_bzclose(wrappedFile);
		}
	}
	else {
		fclose(wrappedFile);
	}
	
	if (dataWritten) [NSException raise:NSInternalInconsistencyException format:@"Cannot change compression settings when data has already been written."];

	useCompression = ((useCompressionFormat == SPGzipCompression) || (useCompressionFormat == SPBzip2Compression));
	
	compressionFormat = useCompressionFormat;
	
	if (useCompression) {		
		if (compressionFormat == SPGzipCompression) {
			wrappedFile = gzopen(wrappedFilePath, "wb");
			gzbuffer(wrappedFile, 131072);
		}
		else if (compressionFormat == SPBzip2Compression) {
			wrappedFile = BZ2_bzopen(wrappedFilePath, "wb");
		}
	} 
	else {
		wrappedFile = fopen(wrappedFilePath, "wb");
	}
}

/**
 * Write the supplied data to the file.  The data may not be written to the
 * disk at once (see synchronizeFile).
 */
- (void)writeData:(NSData *)data
{
	// Throw an exception if the file is closed
	if (fileIsClosed) [NSException raise:NSInternalInconsistencyException format:@"Cannot write to a file handle after it has been closed"];

	// Add the data to the buffer
	if ([data length]) {
		pthread_mutex_lock(&bufferLock);
		[buffer appendData:data];
		allDataWritten = NO;
		bufferDataLength += [data length];
	}

	// If the buffer is large, wait for some to be written out
	while (bufferDataLength > SPFH_MAX_WRITE_BUFFER_SIZE) {
		pthread_mutex_unlock(&bufferLock);
		usleep(100);
		pthread_mutex_lock(&bufferLock);
	}
	pthread_mutex_unlock(&bufferLock);
}

/**
 * Blocks until all data has been written to disk.
 */
- (void)synchronizeFile
{
	pthread_mutex_lock(&bufferLock);
	while (!allDataWritten) {
		pthread_mutex_unlock(&bufferLock);
		usleep(100);
		pthread_mutex_lock(&bufferLock);
	}
	pthread_mutex_unlock(&bufferLock);
}

/**
 * Ensure all data is written out, close any file handles, and prevent any
 * more data from being written to the file.
 */
- (void)closeFile
{
	if (!fileIsClosed) {
		[self synchronizeFile];
		
		if (useCompression) {
			if (compressionFormat == SPGzipCompression) {
				gzclose(wrappedFile);
			}
			else if (compressionFormat == SPBzip2Compression) {
				BZ2_bzclose(wrappedFile);
			}
		} 
		else {
			fclose(wrappedFile);
		}
		
		if (processingThread) {
			if ([processingThread isExecuting]) {
				[processingThread cancel];
				while ([processingThread isExecuting]) usleep(100);
			}
		}
		
		fileIsClosed = YES;
	}
}

#pragma mark -
#pragma mark File information

/**
 * Returns whether compression is enabled on the file.
 */
- (BOOL)isCompressed
{
	return useCompression;
}

/**
 * Returns the compression format being used. Currently gzip or bzip2 only.
 */
- (SPFileCompressionFormat)compressionFormat
{
	return compressionFormat;
}

@end

@implementation SPFileHandle (PrivateAPI)

/**
 * A method to be called on a background thread, allowing write data to build
 * up in a buffer and write to disk in chunks as the buffer fills.  This allows
 * background compression of the data when using Gzip compression.
 */
- (void)_writeBufferToData
{
	NSAutoreleasePool *writePool = [[NSAutoreleasePool alloc] init];

	// Process the buffer in a loop into the file, until cancelled
	while (!fileIsClosed && ![processingThread isCancelled]) {

		// Check whether any data in the buffer needs to be written out - using thread locks for safety
		pthread_mutex_lock(&bufferLock);
		if (!bufferDataLength) {
			pthread_mutex_unlock(&bufferLock);
			usleep(1000);
			continue;
		}

		// Copy the data into a local buffer
		NSData *dataToBeWritten = [NSData dataWithData:buffer];
		[buffer setLength:0];
		bufferDataLength = 0;
		pthread_mutex_unlock(&bufferLock);

		// Write out the data
		long bufferLengthWrittenOut;
				
		if (useCompression) {
			switch (compressionFormat) 
			{
				case SPGzipCompression:
					bufferLengthWrittenOut = gzwrite(wrappedFile, [dataToBeWritten bytes], [dataToBeWritten length]);
					break;
				case SPBzip2Compression:
					bufferLengthWrittenOut = BZ2_bzwrite(wrappedFile, [dataToBeWritten bytes], [dataToBeWritten length]);
					break;
			}
		} 
		else {
			bufferLengthWrittenOut = fwrite([dataToBeWritten bytes], 1, [dataToBeWritten length], wrappedFile);
		}

		// Restore data to the buffer if it wasn't written out
		pthread_mutex_lock(&bufferLock);
		if (bufferLengthWrittenOut < [dataToBeWritten length]) {
			if ([buffer length]) {
				long dataLengthToRestore = [dataToBeWritten length] - bufferLengthWrittenOut;
				[buffer replaceBytesInRange:NSMakeRange(0, 0) withBytes:[[dataToBeWritten subdataWithRange:NSMakeRange(bufferLengthWrittenOut, dataLengthToRestore)] bytes] length:dataLengthToRestore];
				bufferDataLength += dataLengthToRestore;
			}

		// Otherwise, mark all data as written if it has been - allows synching to hard disk.
		} else if (![buffer length]) {
			allDataWritten = YES;
		}
		pthread_mutex_unlock(&bufferLock);
	}

	[writePool drain];
}

@end
