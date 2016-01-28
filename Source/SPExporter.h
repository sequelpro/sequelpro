//
//  SPExporter.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on August 29, 2009.
//  Copyright (c) 2009 Stuart Connolly. All rights reserved.
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

@class SPMySQLConnection, SPExportFile, SPServerSupport;

@interface SPExporter : NSOperation
{	
	SPMySQLConnection *connection;
	SPServerSupport *serverSupport;
	
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
@property(readwrite, retain) SPMySQLConnection *connection;

/**
 * @property serverSupport Information about the features supported by this mysql version
 */
@property(readwrite, retain) SPServerSupport *serverSupport;

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

#pragma mark Shared Private

/**
 * This is the method you should override in every concrete exporter implementation.
 */
- (void)exportOperation;

/**
 * Write a string to the current output file using the current output encoding
 * @param input The string to write
 */
- (void)writeString:(NSString *)input;

/**
 * Write a string to the current output file using UTF-8 encoding
 * @param input The string to write
 */
#warning This method mainly exists to shorten some old code which sometimes uses [self exportOutputEncoding] and sometimes NSUTF8StringEncoding. \
	     In general there should be no need to have more than one encoding in a file. \
         Someone needs to check if that was an oversight or intentional.
- (void)writeUTF8String:(NSString *)input;

@end
