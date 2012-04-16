//
//  $Id$
//
//  QKQueryUpdateParameter.h
//  QueryKit
//
//  Created by Stuart Connolly (stuconnolly.com) on March 24, 2012
//  Copyright (c) 2012 Stuart Connolly. All rights reserved.
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

/**
 * @class QKQueryUpdateParameter QKQueryUpdateParameter.h
 *
 * @author Stuart Connolly http://stuconnolly.com/
 *
 * QueryKit update query parameter class. 
 */
@interface QKQueryUpdateParameter : NSObject 
{
	NSString *_field;
	
	id _value;
}

/**
 * @property _field The field component of the parameter.
 */
@property (readwrite, retain, getter=field, setter=setField:) NSString *_field;

/**
 *@property _value The value component of the parameter.
 */
@property (readwrite, retain, getter=value, setter=setValue:) id _value;

+ (QKQueryUpdateParameter *)queryUpdateParamWithField:(NSString *)field value:(id)value;

- (id)initUpdateParamWithField:(NSString *)field value:(id)value;

@end
