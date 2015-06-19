//
//  $$
//
//  SPMySQLEmptyResult.m
//  SPMySQLFramework
//
//  Created by Rowan Beentje (rowan.beent.je) on March 11, 2013
//  Copyright (c) 2013 Rowan Beentje. All rights reserved.
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

#import "SPMySQLEmptyResult.h"

@implementation SPMySQLEmptyResult

@synthesize delegate;

#pragma mark -
#pragma mark Setup and teardown

/**
 * Override the standard SPMySQLResult interface
 */
- (id)initWithMySQLResult:(void *)theResult stringEncoding:(NSStringEncoding)theStringEncoding
{
	return [super init];
}

- (void)dealloc
{
	[super dealloc];
}

#pragma mark -
#pragma mark Overrides

- (NSUInteger)numberOfFields
{
	return 0;
}

- (unsigned long long)numberOfRows
{
	return 0;
}

- (NSArray *)fieldNames
{
	return nil;
}

- (void)seekToRow:(unsigned long long)targetRow
{
}

- (BOOL)dataDownloaded
{
	return YES;
}

- (id)getRow
{
	return nil;
}

- (NSArray *)getRowAsArray
{
	return nil;
}

- (NSDictionary *)getRowAsDictionary
{
	return nil;
}

- (id)getRowAsType:(SPMySQLResultRowType)theType
{
	return nil;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len
{
	return 0;
}

- (NSArray *)fieldDefinitions
{
	return nil;
}

- (void)startDownload
{
}

- (void)cancelResultLoad
{
}

- (void)removeAllRows
{
}

- (id)_stringWithBytes:(const void *)bytes length:(NSUInteger)length
{
	return nil;
}

- (NSString *)_lossyStringWithBytes:(const void *)bytes length:(NSUInteger)length wasLossy:(BOOL *)outLossy
{
	return nil;
}

- (id)_getObjectFromBytes:(char *)bytes ofLength:(NSUInteger)length fieldDefinitionIndex:(NSUInteger)fieldIndex previewLength:(NSUInteger)previewLength
{
	return nil;
}

@end
