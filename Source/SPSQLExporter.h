//
//  SPSQLExporter.h
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
#import "SPSQLExporterProtocol.h"

@class SPTableData;

/**
 * @class SPSQLExporter SPSQLExporter.m
 *
 * @author Stuart Connolly http://stuconnolly.com/
 *
 * SQL exporter class.
 */
@interface SPSQLExporter : SPExporter
{
	NSObject <SPSQLExporterProtocol> *delegate;
	
	NSArray *sqlExportTables;

	NSString *sqlDatabaseHost;
	NSString *sqlDatabaseName;
	NSString *sqlDatabaseVersion;
	NSString *sqlExportCurrentTable;
	NSString *sqlExportErrors;
	
	BOOL sqlOutputIncludeUTF8BOM;
	BOOL sqlOutputEncodeBLOBasHex;
	BOOL sqlOutputIncludeErrors;
	BOOL sqlOutputIncludeAutoIncrement;
	
	SPSQLExportInsertDivider sqlInsertDivider;

	NSUInteger sqlCurrentTableExportIndex;
	NSUInteger sqlInsertAfterNValue;

	SPTableData *sqlTableDataInstance;
}

/**
 * @property delegate Exporter delegate
 */
@property(readwrite, assign) NSObject <SPSQLExporterProtocol> *delegate;

/**
 * @property sqlExportTables Tables
 */
@property(readwrite, retain) NSArray *sqlExportTables;

/**
 * @property sqlDatabaseHost Database host
 */
@property(readwrite, retain) NSString *sqlDatabaseHost;

/**
 * @property sqlDatabaseName Database name
 */
@property(readwrite, retain) NSString *sqlDatabaseName;

/**
 * @property sqlDatabaseVersion Database version
 */
@property(readwrite, retain) NSString *sqlDatabaseVersion;

/**
 * @property sqlExportCurrentTable Current table
 */
@property(readwrite, retain) NSString *sqlExportCurrentTable;

/**
 * @property sqlExportErrors Export errors
 */
@property(readwrite, retain) NSString *sqlExportErrors;

/**
 * @property sqlOutputIncludeUTF8BOM Include UTF-8 BOM
 */
@property(readwrite, assign) BOOL sqlOutputIncludeUTF8BOM;

/**
 * @property sqlOutputEncodeBLOBasHex Encode BLOB fields as Hex data
 */
@property(readwrite, assign) BOOL sqlOutputEncodeBLOBasHex;

/**
 * @property sqlOutputIncludeErrors Include export errors
 */
@property(readwrite, assign) BOOL sqlOutputIncludeErrors;

/**
 * @property sqlOutputIncludeAutoIncrement Include auto increment in structure definition
 */
@property(readwrite, assign) BOOL sqlOutputIncludeAutoIncrement;

/**
 * @property sqlCurrentTableExportIndex Number of tables processed by exporter
 */
@property(readwrite, assign) NSUInteger sqlCurrentTableExportIndex;

/**
 * @property sqlInsertAfterNValue The value after which a new INSERT statement should be created
 */
@property(readwrite, assign) NSUInteger sqlInsertAfterNValue;

/**
 * @property sqlInsertDivider New INSERT statement divider
 */
@property(readwrite, assign) SPSQLExportInsertDivider sqlInsertDivider;

- (id)initWithDelegate:(NSObject<SPSQLExporterProtocol> *)exportDelegate;

- (BOOL)didExportErrorsOccur;

@end
