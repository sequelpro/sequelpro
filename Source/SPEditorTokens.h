//
//  SPEditorTokens.h
//  sequel-pro
//
//  Created by Jakob on March 15, 2009.
//  Copyright (c) 2009 Jakob. All rights reserved.
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
 *  This file defines all the tokens used for parsing the source code
 */

#define SPT_DOUBLE_QUOTED_TEXT   1
#define SPT_SINGLE_QUOTED_TEXT   2
#define SPT_COMMENT              3
#define SPT_BACKTICK_QUOTED_TEXT 4
#define SPT_RESERVED_WORD        5
#define SPT_WHITESPACE           6
#define SPT_NUMERIC              7
#define SPT_VARIABLE             8
#define SPT_WORD                 9
#define SPT_OTHER               10
