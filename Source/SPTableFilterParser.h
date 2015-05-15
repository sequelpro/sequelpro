//
//  SPTableFilterParser.h
//  sequel-pro
//
//  Created by Max Lohrmann on 22.04.15.
//  Relocated from existing files. Previous copyright applies.
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

@interface SPTableFilterParser : NSObject
{
	NSString *_clause;
	NSUInteger numberOfArguments;
	
	NSString *_currentField;
	NSString *_argument;
	NSString *_firstBetweenArgument;
	NSString *_secondBetweenArgument;
	
	BOOL caseSensitive;
	BOOL suppressLeadingTablePlaceholder;
}

- (id)initWithFilterClause:(NSString *)filter numberOfArguments:(NSUInteger)numArgs;

@property(readonly) NSString *clause;
@property(readonly) NSUInteger numberOfArguments;

@property BOOL suppressLeadingTablePlaceholder;
@property BOOL caseSensitive;
@property(copy) NSString *currentField;
@property(copy) NSString *argument;
@property(copy) NSString *firstBetweenArgument;
@property(copy) NSString *secondBetweenArgument;

- (NSString *)filterString;

@end
