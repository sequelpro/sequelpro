//
//  SPExportHandlerFactory.h
//  sequel-pro
//
//  Created by Max Lohrmann on 22.11.15.
//  Copyright (c) 2015 Max Lohrmann. All rights reserved.
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

#import <Foundation/Foundation.h>

@class SPExportController;
@protocol SPExportHandler;

@protocol SPExportHandlerFactory

/**
 * An internal name that will be used to uniquely identify an export handler.
 * This is not visible in the UI and must not be localized.
 */
- (NSString *)uniqueName;

/**
 * The localized short name of the export handler.
 * Usually this will be something like the file format ("SQL", "XML", ...)
 */
- (NSString *)localizedShortName;

/**
 * Does the export handler supports export to multiple files?
 * This will enable/disable a checkbox in the UI.
 * @return YES, if supported
 */
- (BOOL)supportsExportToMultipleFiles;

/**
 * Does the export handler support exports from a certain source?
 * @param source The export source
 * @return YES, if supported
 *
 * Note that declaring support for a certain export source also requires the
 * handler to implement the corresponding protocol.
 */
- (BOOL)supportsExportSource:(SPExportSource)source;

/**
 * Create a new instance of the export handler for a given controller
 * @param ctr The controller the export handler instance belongs to.
 *            This will be constant during the lifetime of the export handler.
 * @return An autoreleased instance of the export handler
 */
- (id<SPExportHandler>)makeInstanceWithController:(SPExportController *)ctr;

@end
