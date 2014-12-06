//
//  SPCSVExporter.h
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

#import "SPExporter.h"
#import "SPCSVExporterProtocol.h"

@class SPTableData;

/**
 * @class SPCSVExporter SPCSVExporter.m
 *
 * @author Stuart Connolly http://stuconnolly.com/
 *
 * CSV exporter class.
 */
@interface SPCSVExporter : SPExporter
{		
	NSObject <SPCSVExporterProtocol> *delegate;
	
	NSArray *csvDataArray;
	
	NSString *csvTableName;
	NSString *csvFieldSeparatorString;
	NSString *csvEnclosingCharacterString;
	NSString *csvEscapeString;
	NSString *csvLineEndingString;
	NSString *csvNULLString;
	
	BOOL csvOutputFieldNames;
	
	SPTableData *csvTableData;
}

/**
 * @property delegate Exporter delegate
 */
@property(readwrite, assign) NSObject <SPCSVExporterProtocol> *delegate;

/** 
 * @property csvDataArray Data array
 */
@property(readwrite, retain) NSArray *csvDataArray;

/**
 * @property csvTableName Table name
 */
@property(readwrite, retain) NSString *csvTableName;

/**
 * @property csvFieldSeparatorString CSV field separator string
 */
@property(readwrite, retain) NSString *csvFieldSeparatorString;

/**
 * @property csvEnclosingCharacterString CSV enclosing character string
 */
@property(readwrite, retain) NSString *csvEnclosingCharacterString;

/**
 * @property csvEscapeString CSV escape string
 */
@property(readwrite, retain) NSString *csvEscapeString;

/**
 * @property csvLineEndingString CSV line ending string
 */
@property(readwrite, retain) NSString *csvLineEndingString;

/**
 * @property csvNULLString CSV NULL string
 */
@property(readwrite, retain) NSString *csvNULLString;

/**
 * @property csvOutputFieldNames csvOutputFieldNames Output field names
 */
@property(readwrite, assign) BOOL csvOutputFieldNames;

/**
 * @property csvTableData Table data
 */
@property(readwrite, retain) SPTableData *csvTableData;

- (id)initWithDelegate:(NSObject *)exportDelegate;

@end
