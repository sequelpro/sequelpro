//
//  SPSQLExporterProtocol.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on April 15, 2010.
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
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

@class SPSQLExporter;

/**
 * @protocol SPSQLExporterProtocol SPSQLExporterProtocol.h
 *
 * @author Stuart Connolly http://stuconnolly.com/
 *
 * SQL exporter delegate protocol.
 */
@protocol SPSQLExporterProtocol

/**
 * Called when the SQL export process is about to begin. 
 * 
 * @param SPSQLExporter The expoter calling the method.
 */
- (void)sqlExportProcessWillBegin:(SPSQLExporter *)exporter;

/**
 * Called when the SQL export process is complete.
 * 
 * @param SPSQLExporter The expoter calling the method.
 */
- (void)sqlExportProcessComplete:(SPSQLExporter *)exporter;

/**
 * alled when the progress of the SQL export process is updated.
 *
 * @param SPSQLExporter The expoter calling the method.
 */
- (void)sqlExportProcessProgressUpdated:(SPSQLExporter *)exporter;

/**
 * Called when the SQL export process is about to begin fetching data from the database.
 *
 * @param SPSQLExporter The expoter calling the method.
 */
- (void)sqlExportProcessWillBeginFetchingData:(SPSQLExporter *)exporter;

/**
 * Called when the SQL export process is about to begin writing data to disk.
 *
 * @param SPSQLExporter The expoter calling the method.
 */
- (void)sqlExportProcessWillBeginWritingData:(SPSQLExporter *)exporter;

@end
