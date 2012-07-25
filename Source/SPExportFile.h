//
//  $Id$
//
//  SPExportFile.h
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
//  More info at <http://code.google.com/p/sequel-pro/>

@class SPFileHandle;

/**
 * @class SPExportFile SPExportFile.h
 *
 * @author Stuart Connolly http://stuconnolly.com/
 *
 * This class represents an abstract export file regardless of whether the file on disk actually exists on
 * disk upon initialization. It provides multiple convenience methods for accessing the underlying file handle
 * (SPFileHandle instance) as well as logic to deal with situations whether there are problems (file already 
 * exists, etc) creating the file and estabslishing a handle to it. 
 */
@interface SPExportFile : NSObject
{
	NSString *exportFilePath;
	
	BOOL exportFileNeedsCSVHeader;
	BOOL exportFileNeedsXMLHeader;
	
	SPFileHandle *exportFileHandle;
	
	SPExportFileHandleStatus exportFileHandleStatus;
}

/**
 * @property exportFilePath
 */
@property (readwrite, retain) NSString *exportFilePath;

/**
 * @property exportFileHandle
 */
@property (readonly) SPFileHandle *exportFileHandle;

/**
 * @property exportFileNeedsCSVHeader
 */
@property (readwrite, assign) BOOL exportFileNeedsCSVHeader;

/**
 * @property exportFileNeedsXMLHeader
 */
@property (readwrite, assign) BOOL exportFileNeedsXMLHeader;

/**
 * @property exportFileHandleStatus
 */
@property (readonly) SPExportFileHandleStatus exportFileHandleStatus;

+ (SPExportFile *)exportFileAtPath:(NSString *)path;

- (id)initWithFilePath:(NSString *)path;

- (void)close;
- (BOOL)delete;
- (void)writeData:(NSData *)data;
- (SPExportFileHandleStatus)createExportFileHandle:(BOOL)overwrite;
- (void)setCompressionFormat:(SPFileCompressionFormat)fileCompressionFormat;

@end
