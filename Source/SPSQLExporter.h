//
//  $Id$
//
//  SPSQLExporter.h
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

#import "SPExporter.h"
#import "SPConstants.h"
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
	
	SPSQLExportInsertDivider sqlInsertDivider;

	NSUInteger sqlCurrentTableExportIndex;
	NSUInteger sqlInsertAfterNValue;

	SPTableData *sqlTableDataInstance;
}

/**
 * @property delegate Exporter delegate
 */
@property(readwrite, assign) NSObject *delegate;

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

- (id)initWithDelegate:(NSObject *)exportDelegate;

- (BOOL)didExportErrorsOccur;

@end
