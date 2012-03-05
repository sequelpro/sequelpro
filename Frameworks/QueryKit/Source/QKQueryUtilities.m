//
//  $Id: QKQueryUtilities.m 3421 2011-09-10 22:58:45Z stuart02 $
//
//  QKQueryUtilities.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on September 4, 2011
//  Copyright (c) 2011 Stuart Connolly. All rights reserved.
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
//  More info at <http://code.google.com/p/sequel-pro/>

#import "QKQueryUtilities.h"

static NSString *QKUnrecognisedQueryOperatorException = @"QKUnrecognisedQueryOperator";

@implementation QKQueryUtilities

/**
 * Returns a string representation of the supplied operator type.
 *
 * @param operator The operator
 *
 * @return A string represenation of the operator.
 */
+ (NSString *)operatorRepresentationForType:(QKQueryOperator)operator
{
	NSString *opString = nil;
	
	switch (operator) 
	{
		case QKEqualityOperator:
			opString = @"=";
			break;
		case QKNotEqualOperator:
			opString = @"!=";
			break;
		case QKLikeOperator:
			opString = @"LIKE";
			break;
		case QKNotLikeOperator:
			opString = @"NOT LIKE";
			break;
		case QKInOperator:
			opString = @"IN";
			break;
		case QKNotInOperator:
			opString = @"NOT IN";
			break;
		case QKIsNullOperator:
			opString = @"IS NULL";
			break;
		case QKIsNotNullOperator:
			opString = @"IS NOT NULL";
			break;
		case QKGreaterThanOperator:
			opString = @">";
			break;
		case QKLessThanOperator:
			opString = @"<";
			break;
		case QKGreaterThanOrEqualOperator:
			opString = @">=";
			break;
		case QKLessThanOrEqualOperator:
			opString = @"<=";
			break;
		default:
			[NSException raise:QKUnrecognisedQueryOperatorException format:@"Unrecognised query operator type: %d", operator];
			break;
	}
	
	return opString;
}

@end
