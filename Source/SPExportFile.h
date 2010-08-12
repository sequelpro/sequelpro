//
//  $Id$
//
//  SPExportFile.h
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

#import "SPConstants.h"

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

@end
