//
//  $Id$
//
//  SPExporter.h
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

/**
 * @class SPExporter SPExporter.m
 *
 * @author Stuart Connolly http://stuconnolly.com/
 *
 * This class is designed to be the base class of all data exporters and provide basic functionality
 * common to each of them. Each data exporter (i.e. CSV, SQL, XML, etc.) should be implemented as a subclass
 * of this class, with the end result being a modular export architecture separated by export type. All exporters
 * should also have an associated delegate protocol and delegate category (of SPExportController) which conforms
 * to this protocol.
 *
 * All export functionality is initially controlled by SPExportController, which is the single point within the
 * architecture that controls the user interface and provides user feedback. When the user starts an export 
 * operation after selecting the available options, SPExportController should create an instance of the appropriate
 * exporter (e.g. SPCSVExporter for a CSV export, etc) and begin the export process. Any available progress information
 * (defined in SPExporter as it's common to all exporters) of the export should be set by the exporter and made 
 * available to SPExportController via delegate methods in order to update the user interface.
 *
 * Note that all exporters are designed to be run concurrently and as such this base class is a subclass of 
 * NSOperation. All the data format specific subclasses have to do is override NSOperation's main() method
 * and implement all processes which are to be run concurrently within it. This method is automatically called
 * once the exporter instance is placed on the operation queue once its ready to be run. It should not be
 * explicity called.
 */

#import "SPConstants.h"

@class MCPConnection, SPExportFile;

@interface SPExporter : NSOperation
{	
	MCPConnection *connection;
	
	double exportProgressValue;
	double exportMaxProgress;
	
	BOOL exportProcessIsRunning;
	BOOL exportUsingLowMemoryBlockingStreaming;
	BOOL exportOutputCompressFile;
	
	
	SPFileCompressionFormat exportOutputCompressionFormat;
	
	NSString *exportData;
	
	SPExportFile *exportOutputFile;

	NSStringEncoding exportOutputEncoding;
}

/**
 * @property connection The MySQL connection to use
 */
@property(readwrite, retain) MCPConnection *connection;

/**
 * @property exportProgressValue The export's current progress value
 */
@property(readwrite, assign) double exportProgressValue;

/**
 * @property exportMaxProgress The max progress value of the export operation
 */
@property(readwrite, assign) double exportMaxProgress;

/**
 * @property exportProcessIsRunning Indicates whether or not the exporter is running
 */
@property(readwrite, assign) BOOL exportProcessIsRunning;

/**
 * @property exportUsingLowMemoryBlockingStreaming Indicates whether or not low memory streaming is used
 */
@property(readwrite, assign) BOOL exportUsingLowMemoryBlockingStreaming;

/**
 * @property exportOutputCompressionFormat Compression format
 */
@property(readwrite, assign) SPFileCompressionFormat exportOutputCompressionFormat;

/**
 * @property exportData The resulting exported data as a string
 */
@property(readwrite, retain) NSString *exportData;

/**
 * @property exportOutputFile The output file of the exporter
 */
@property(readwrite, retain) SPExportFile *exportOutputFile;

/**
 * @property exportOutputEncoding Export output encoding
 */
@property(readwrite, assign) NSStringEncoding exportOutputEncoding;

- (BOOL)exportOutputCompressFile;

- (void)setExportOutputCompressFile:(BOOL)compress;

@end
