//
//  SPXMLExporterProtocol.h
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

@class SPXMLExporter;

/**
 * @protocol SPXMLExporterProtocol SPXMLExporterProtocol.h
 *
 * @author Stuart Connolly http://stuconnolly.com/
 *
 * SQL exporter delegate protocol.
 */
@protocol SPXMLExporterProtocol

/**
 * Called when the XML export process is about to begin. 
 *
 * @param SPXMLExporter The expoter calling the method.
 */
- (void)xmlExportProcessWillBegin:(SPXMLExporter *)exporter;

/**
 * Called when the XML export process is complete.
 *
 * @param SPXMLExporter The expoter calling the method.
 */
- (void)xmlExportProcessComplete:(SPXMLExporter *)exporter;

/**
 * Called when the progress of the XML export process is updated.
 *
 * @param SPXMLExporter The expoter calling the method.
 */
- (void)xmlExportProcessProgressUpdated:(SPXMLExporter *)exporter;

/**
 * Called when the XML export process is about to begin writing data to disk.
 *
 * @param SPXMLExporter The expoter calling the method.
 */
- (void)xmlExportProcessWillBeginWritingData:(SPXMLExporter *)exporter;

@end
