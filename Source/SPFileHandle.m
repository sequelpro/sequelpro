//
//  SPFileHandle.m
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

#import "SPFileHandle.h"
#import "bzlib.h"
#import "zlib.1.2.4.h"
#import "pthread.h"

// Define the maximum size of the background write buffer before the writing thread
// waits until some has been written out.  This can affect speed and memory usage.
#define SPFH_MAX_WRITE_BUFFER_SIZE 1048576

struct SPRawFileHandles {
	FILE *file;
	BZFILE *bzfile;
	gzFile *gzfile;
};

@interface SPFileHandle ()

- (void)_writeBufferToData;
- (void)_closeFileHandles;

@end

@implementation SPFileHandle

#pragma mark -

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
- (id)initWithFile:(FILE *)theFile fromPath:(const char *)path mode:(int)mode
{
	if ((self = [super init])) {
		dataWritten = NO;
		allDataWritten = YES;
		fileIsClosed = NO;

		wrappedFile = malloc(sizeof(*wrappedFile)); //FIXME ivar can be moved to .m file with "modern objc", replacing the opaque struct pointer
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
		
		compressionFormat = SPNoCompression;
		processingThread = nil;

		// If in read mode, set up the buffer
		if (fileMode == O_RDONLY) {
			// Test for GZIP (by opening the file with gz and checking what happens)
			{
				gzFile *gzfile = gzopen(path, "rb");
				
				// Set gzip buffer
				gzbuffer(gzfile, 131072);
				
				// Test to see if the file is gzip compressed
				if(!gzdirect(gzfile)) {
					compressionFormat = SPGzipCompression;
					wrappedFile->gzfile = gzfile;
				}
				else {
					// ...not gzip
					gzclose(gzfile);
				}
			}
			// Test for BZ (by checking the file header)
			if(compressionFormat == SPNoCompression) {
				char bzbuf[4];
				int i, c;
				
				// Get the first 4 bytes from the file
				for (i = 0; (c = getc(theFile)) != EOF && i < 4; bzbuf[i++] = c);
				
				rewind(theFile);
				
				// Test to see if the first 2 bytes extracted from the file match the Bzip2 signature/magic number
				// (BZ). The 3rd byte should be either 'h' (Huffman encoding) or 0 (Bzip1 - deprecated) to
				// indicate the Bzip version. Finally, the 4th byte should be a number between 1 and 9 that indicates
				// the block size used.
				
				BOOL isBzip2 = ((bzbuf[0] == 'B')  && (bzbuf[1] == 'Z')) &&
				               ((bzbuf[2] == 'h')  || (bzbuf[2] == '0')) &&
				               ((bzbuf[3] >= 0x31) && (bzbuf[3] <= 0x39));
				
				if (isBzip2) {
					compressionFormat = SPBzip2Compression;
					wrappedFile->bzfile = BZ2_bzReadOpen(NULL, theFile, 0, 0, NULL, 0);
				}
			}
			// We need to save the file handle both in plain and BZ2 format
			if(compressionFormat == SPNoCompression || compressionFormat == SPBzip2Compression) {
				wrappedFile->file = theFile;
			}
			else {
				fclose(theFile);
			}
		} 
		// In write mode, set up a thread to handle writing in the background
		else if (fileMode == O_WRONLY) {
			wrappedFile->file = theFile; // can be changed later via setCompressionFormat:
			processingThread = [[NSThread alloc] initWithTarget:self selector:@selector(_writeBufferToData) object:nil];
			[processingThread setName:@"SPFileHandle data writing thread"];
			[processingThread start];
		}
	}

	return self;
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
	long dataLength = 0;
	void *data = malloc(length);
	
	if (compressionFormat == SPGzipCompression) {
		dataLength = gzread(wrappedFile->gzfile, data, (unsigned)length);
	}
	else if (compressionFormat == SPBzip2Compression) {
		dataLength = BZ2_bzread(wrappedFile->bzfile, data, (int)length);
	}
	else {
		dataLength = fread(data, 1, length, wrappedFile->file);
	}
		
	return [NSMutableData dataWithBytesNoCopy:data length:dataLength freeWhenDone:YES];
}

/**
 * Returns all the data to the end of the file.
 */
- (NSMutableData *)readDataToEndOfFile
{
	return [self readDataOfLength:NSUIntegerMax];
}

/**
 * Returns the on-disk (raw/compressed) length of data read so far.
 * This includes any compression headers within the data, and can be used
 * for progress bars when processing files.
 */
- (NSUInteger)realDataReadLength
{
	if (fileMode == O_WRONLY) return 0;
	
	if (compressionFormat == SPGzipCompression) {
		return gzoffset(wrappedFile->gzfile);
	}
	else if(compressionFormat == SPBzip2Compression) {
		return ftell(wrappedFile->file);
	}
	else {
		return ftell(wrappedFile->file);
	}
}

#pragma mark -
#pragma mark Data writing

/**
 * Set whether data should be written as gzipped data, defaulting
 * to NO on a fresh object. If this is called after data has been
 * written, an exception is thrown.
 */
- (void)setCompressionFormat:(SPFileCompressionFormat)useCompressionFormat
{
	if (compressionFormat == useCompressionFormat) return;

	// Regardless of the supplied argument, close the current file according to how it was previously opened
	[self _closeFileHandles];
	
	if (dataWritten) [NSException raise:NSInternalInconsistencyException format:@"Cannot change compression settings when data has already been written."];

	compressionFormat = useCompressionFormat;
	
	if (compressionFormat == SPGzipCompression) {
		wrappedFile->gzfile = gzopen(wrappedFilePath, "wb");
		gzbuffer(wrappedFile->gzfile, 131072);
	}
	else if (compressionFormat == SPBzip2Compression) {
		wrappedFile->file = fopen(wrappedFilePath, "wb");
		wrappedFile->bzfile = BZ2_bzWriteOpen(NULL, wrappedFile->file, 9, 0, 0);
	}
	else {
		wrappedFile->file = fopen(wrappedFilePath, "wb");
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

	pthread_mutex_lock(&bufferLock);
	
	// Add the data to the buffer
	if ([data length]) {
		[buffer appendData:data];
		allDataWritten = NO;
		bufferDataLength += [data length];
	}

	// If the buffer is large, wait for some to be written out
	while (bufferDataLength > SPFH_MAX_WRITE_BUFFER_SIZE) 
	{
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
	
	while (!allDataWritten) 
	{
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
		[self _closeFileHandles];
		
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
 * Returns the compression format being used. Currently gzip or bzip2 only.
 */
- (SPFileCompressionFormat)compressionFormat
{
	return compressionFormat;
}

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
		NSData *dataToBeWritten = [buffer copy];
		
		[buffer setLength:0];
		bufferDataLength = 0;
		
		pthread_mutex_unlock(&bufferLock);

		// Write out the data
		long bufferLengthWrittenOut = 0;
		
		switch (compressionFormat) {
			case SPGzipCompression:
				bufferLengthWrittenOut = gzwrite(wrappedFile->gzfile, [dataToBeWritten bytes], (unsigned)[dataToBeWritten length]);
				break;
			case SPBzip2Compression:
				bufferLengthWrittenOut = BZ2_bzwrite(wrappedFile->bzfile, (void *)[dataToBeWritten bytes], (int)[dataToBeWritten length]);
				break;
			default:
				bufferLengthWrittenOut = fwrite([dataToBeWritten bytes], 1, [dataToBeWritten length], wrappedFile->file);
		}

		// Restore data to the buffer if it wasn't written out
		pthread_mutex_lock(&bufferLock);
		
		if (bufferLengthWrittenOut < (NSInteger)[dataToBeWritten length]) {
			if ([buffer length]) {
				long dataLengthToRestore = [dataToBeWritten length] - bufferLengthWrittenOut;
				[buffer replaceBytesInRange:NSMakeRange(0, 0) withBytes:[[dataToBeWritten subdataWithRange:NSMakeRange(bufferLengthWrittenOut, dataLengthToRestore)] bytes] length:dataLengthToRestore];
				bufferDataLength += dataLengthToRestore;
			}
		} 
		// Otherwise, mark all data as written if it has been - allows synching to hard disk.
		else if (![buffer length]) {
			allDataWritten = YES;
		}
		
		pthread_mutex_unlock(&bufferLock);

		[dataToBeWritten release];
	}

	[writePool drain];
}

/**
 * Close any open file handles
 */
- (void)_closeFileHandles
{
	if (compressionFormat == SPGzipCompression) {
		gzclose(wrappedFile->gzfile);
		wrappedFile->gzfile = NULL;
	}
	else if (compressionFormat == SPBzip2Compression) {
		if (fileMode == O_RDONLY) {
			BZ2_bzReadClose(NULL, wrappedFile->bzfile);
		}
		else if (fileMode == O_WRONLY) {
			BZ2_bzWriteClose(NULL, wrappedFile->bzfile, 0, NULL, NULL);
		}
		else {
			[NSException raise:NSInvalidArgumentException format:@"SPFileHandle only supports read-only and write-only file modes"];
		}
		fclose(wrappedFile->file);
		wrappedFile->bzfile = NULL;
		wrappedFile->file = NULL;
	}
	else {
		fclose(wrappedFile->file);
		wrappedFile->file = NULL;
	}
}

#pragma mark -

/**
 * Dealloc.
 */
- (void)dealloc
{
	[self closeFile];
	
	if (processingThread) SPClear(processingThread);
	
	free(wrappedFile);
	free(wrappedFilePath);
	SPClear(buffer);
	
	pthread_mutex_destroy(&bufferLock);
	
	[super dealloc];
}

@end
