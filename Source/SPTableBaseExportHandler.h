//
//  SPTableBaseExportHandler.h
//  sequel-pro
//
//  Created by Max Lohrmann on 25.11.15.
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
#import "SPExportHandlerInstance.h"
#import "SPBaseExportHandler.h"

@class SPExportController;
@protocol SPExportSchemaObject;
@protocol SPExportHandlerFactory;

/**
 * This class implements a basic export handler with support for selecting schema objects
 * via checkbox.
 * This is an **abstract** class. You still have to implement many of the methods.
 *
 * Note that this class makes the addonData of SPExportSchemaObject an NSMutableDictionary.
 */
@interface SPTableBaseExportHandler : SPBaseExportHandler {
	NSArray *_tableColumns;
}

@property(readonly, nonatomic, copy) NSArray *tableColumns;

@end

#pragma mark -
#pragma mark Protected


