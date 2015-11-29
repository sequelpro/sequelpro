//
//  SPBaseExportHandler.m
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

#import "SPExportHandlerFactory.h"
#import "SPTableBaseExportHandler.h"
#import "SPBaseExportHandler_Protected.h"

@implementation SPBaseExportHandler

@synthesize canBeImported = _canBeImported;
@synthesize isValidForExport = _isValidForExport;
@synthesize fileExtension = _fileExtension;
@synthesize accessoryViewController = _accessoryViewController;
@synthesize controller = _controller;
@synthesize factory = _factory;

- (id)initWithFactory:(id<SPExportHandlerFactory>)factory
{
	if((self = [super init])) {
		[self setIsValidForExport:NO];
		[self setCanBeImported:NO];
		[self setController:nil];
		[self setFileExtension:nil];
		[self setAccessoryViewController:nil];
		exportTableCount = 0;
		currentTableExportIndex = 0;
		_factory = factory;
	}
	return self;
}

- (id)init
{
	[NSException raise:SPNotImplementedExceptionName format:@"use initWithFactory: instead of init!"];
}

- (NSDictionary *)settings
{
	//nothing to do here. must be overridden
	return nil;
}

- (void)applySettings:(NSDictionary *)settings
{
	//nothing to do here. must be overridden
}

@end