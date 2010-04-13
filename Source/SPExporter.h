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

#import <Cocoa/Cocoa.h>

/**
 * This class is designed to be the base class of all data exporters and provide basic functionality
 * common to each of them. Each data exporter (i.e. CSV, SQL, XML, etc.) should be implemented as a subclass
 * of this class, with the end result being a modular export architecture separated by export type. All exporters
 * should also conform to the SPExporterAccess protocol to allow generic access to the exporter's state and common
 * functionality.
 *
 * All export functionality is initially controlled by SPExportController, which is the single point within the
 * architecture that controls the user interface and provides user feedback. When the user starts an export 
 * operation after selecting the available options, SPExportController should create an instance of the appropriate
 * exporter (e.g. SPCSVExporter for a CSV export) and begin the export process. Any available progress information
 * (defined in SPExporter as is common to all exporters) of the export should be set by the exporter and made 
 * available to SPExportController via delegate methods in order to update the user interface.
 *
 * Note that all exporters are designed to be run concurrently and as such this base class is a subclass of 
 * NSOperation. All the data format specific subclasses have to do is override NSOperation's main() method
 * and implement all processes which are to be run concurrently within it. This method is automatically called
 * once the exporter instance is placed on the operation queue once its ready to be run.
 */

@class MCPConnection, SPFileHandle;

@interface SPExporter : NSOperation
{
	id delegate;
	
	MCPConnection *connection;
		
	double exportProgressValue;
	
	BOOL exportProcessIsRunning;
	BOOL exportUsingLowMemoryBlockingStreaming;
	
	NSString *exportData;
	SPFileHandle *exportOutputFileHandle;
	NSStringEncoding exportOutputEncoding;

	NSInteger exportMaxProgress;
}

@property (readwrite, assign) id delegate;

@property (readwrite, retain) MCPConnection *connection;

@property (readwrite, assign) double exportProgressValue;

@property (readwrite, assign) BOOL exportProcessIsRunning;
@property (readwrite, assign) BOOL exportUsingLowMemoryBlockingStreaming;

@property (readwrite, retain) NSString *exportData;
@property (readwrite, retain) SPFileHandle *exportOutputFileHandle;
@property (readwrite, assign) NSStringEncoding exportOutputEncoding;

@property (readwrite, assign) NSInteger exportMaxProgress;

- (id)initWithDelegate:(id)exportDelegate;

@end
