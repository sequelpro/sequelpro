//
//  SPSXMLExporter.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on October 6, 2009.
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
#import "SPXMLExporterProtocol.h"

/**
 * @class SPXMLExporter SPXMLExporter.m
 *
 * @author Stuart Connolly http://stuconnolly.com/
 *
 * XML exporter class.
 */
@interface SPXMLExporter : SPExporter 
{
	NSObject <SPXMLExporterProtocol> *delegate;
	
	NSArray *xmlDataArray;

	NSString *xmlTableName;
	NSString *xmlNULLString;
	
	BOOL xmlOutputIncludeStructure;
	BOOL xmlOutputIncludeContent;
	
	SPXMLExportFormat xmlFormat;
}

/**
 * @property delegate Exporter delegate
 */
@property (readwrite, assign) NSObject <SPXMLExporterProtocol> *delegate;

/**
 * @property xmlDataArray Data array
 */
@property (readwrite, retain) NSArray *xmlDataArray;

/**
 * @property xmlTableName Table name
 */
@property (readwrite, retain) NSString *xmlTableName;

/**
 * @property xmlNULLString XML NULL string
 */
@property (readwrite, retain) NSString *xmlNULLString;

/**
 * @property xmlOutputIncludeStructure Include table structure
 */
@property (readwrite, assign) BOOL xmlOutputIncludeStructure;

/**
 * @property xmlOutputIncludeContent Include table content
 */
@property (readwrite, assign) BOOL xmlOutputIncludeContent;

/**
 * @property xmlFormat
 */
@property (readwrite, assign) SPXMLExportFormat xmlFormat;

- (id)initWithDelegate:(NSObject *)exportDelegate;

@end
