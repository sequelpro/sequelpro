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

#import <Cocoa/Cocoa.h>

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
	
	/**
	 * Tables
	 */
	NSArray *sqlExportTables;
	
	/**
	 * Database host
	 */
	NSString *sqlDatabaseHost;
	
	/**
	 * Database name
	 */
	NSString *sqlDatabaseName;
	
	/**
	 * Database version
	 */
	NSString *sqlDatabaseVersion;
	
	/**
	 * Current table
	 */
	NSString *sqlExportCurrentTable;
	
	/**
	 * Export errors
	 */
	NSString *sqlExportErrors;
	
	/**
	 * Include UTF-8 BOM
	 */
	BOOL sqlOutputIncludeUTF8BOM;
	
	/**
	 * Encode BLOB fields as Hex data
	 */
	BOOL sqlOutputEncodeBLOBasHex;
	
	/**
	 * Include export errors
	 */
	BOOL sqlOutputIncludeErrors;
	
	/**
	 * New INSERT statement divider
	 */
	SPSQLExportInsertDivider sqlInsertDivider;

	/**
	 * Number of tables processed by exporter
	 */
	NSUInteger sqlCurrentTableExportIndex;
	
	/**
	 * The value after which a new INSERT statement should be created.
	 */
	NSUInteger sqlInsertAfterNValue;
	
	/**
	 * Table information fetcher and parser
	 */
	SPTableData *sqlTableDataInstance;
}

@property(readwrite, assign) NSObject *delegate;

@property(readwrite, retain) NSArray *sqlExportTables;

@property(readwrite, retain) NSString *sqlDatabaseHost;
@property(readwrite, retain) NSString *sqlDatabaseName;
@property(readwrite, retain) NSString *sqlDatabaseVersion;

@property(readwrite, retain) NSString *sqlExportCurrentTable;
@property(readwrite, retain) NSString *sqlExportErrors;

@property(readwrite, assign) BOOL sqlOutputIncludeUTF8BOM;
@property(readwrite, assign) BOOL sqlOutputEncodeBLOBasHex;
@property(readwrite, assign) BOOL sqlOutputIncludeErrors;

@property(readwrite, assign) NSUInteger sqlCurrentTableExportIndex;
@property(readwrite, assign) NSUInteger sqlInsertAfterNValue;

@property(readwrite, assign) SPSQLExportInsertDivider sqlInsertDivider;

/**
 * Initialise an instance of SPSQLExporter using the supplied delegate.
 *
 * @param exportDelegate The exporter delegate
 *
 * @return The initialised instance
 */
- (id)initWithDelegate:(NSObject *)exportDelegate;

/**
 * Returns whether or not any export errors occurred.
 *
 * @return A BOOL indicating the occurrence of errors
 */
- (BOOL)didExportErrorsOccur;

@end
