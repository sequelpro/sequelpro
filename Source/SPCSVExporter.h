//
//  $Id$
//
//  SPCSVExporter.h
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
