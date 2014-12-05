//
//  SPDotExporter.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on April 17, 2010.
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
#import "SPDotExporterProtocol.h"

@class SPTableData;

/**
 * @class SPXMLExporter SPXMLExporter.m
 *
 * @author Stuart Connolly http://stuconnolly.com/
 *
 * XML exporter class.
 */
@interface SPDotExporter : SPExporter 
{
	NSObject <SPDotExporterProtocol> *delegate;
	
	NSArray *dotExportTables;
	
	NSString *dotExportCurrentTable;

	BOOL dotForceLowerTableNames;

	SPTableData *dotTableData;

	NSString *dotDatabaseHost;
	NSString *dotDatabaseName;
	NSString *dotDatabaseVersion;
}

/**
 * @property delegate Exporter delegate
 */
@property(readwrite, assign) NSObject <SPDotExporterProtocol> *delegate;

/**
 * @property dotExportTables Table information
 */
@property(readwrite, retain) NSArray *dotExportTables;

/**
 * @property dotExportCurrentTable Current table
 */
@property(readwrite, retain) NSString *dotExportCurrentTable;

/**
 * @property dotForceLowerTableNames dotForceLowerTableNames Force lowercase table names
 */
@property(readwrite, assign) BOOL dotForceLowerTableNames;

/**
 * @property dotTableData Table data
 */
@property(readwrite, retain) SPTableData *dotTableData;

/**
 * @property dotDatabaseHost Database host
 */
@property(readwrite, retain) NSString *dotDatabaseHost;

/**
 * @property dotDatabaseName Database name
 */
@property(readwrite, retain) NSString *dotDatabaseName;

/**
 * @property dotDatabaseVersion Database version
 */
@property(readwrite, retain) NSString *dotDatabaseVersion;

- (id)initWithDelegate:(NSObject *)exportDelegate;

@end
