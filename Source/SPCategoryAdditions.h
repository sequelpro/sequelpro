//
//  SPCategoryAdditions.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on October 23, 2010.
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

/**
 * This header is intended to import all of our custom category additions to classes outwith our control.
 * It is subsequently included in Sequel Ace's precompiled header making all of the additional methods/functions 
 * included in header available to all classes within the application.
 */

#import "SPArrayAdditions.h"
#import "SPMutableArrayAdditions.h"
#import "SPStringAdditions.h"
#import "SPObjectAdditions.h"
#import "SPTextViewAdditions.h"
#import "SPWindowAdditions.h"
#import "SPDataAdditions.h"
#import "SPDataBase64EncodingAdditions.h"
#import "SPNotLoaded.h"
#import "SPMainThreadTrampoline.h"
#import "SPColorAdditions.h"
#import "SPFileManagerAdditions.h"
#import "SPDateAdditions.h"
#import "SPScreenAdditions.h"

#import "NSNotificationCenterThreadingAdditions.h"
#import "NSMutableArray-MultipleSort.h"
