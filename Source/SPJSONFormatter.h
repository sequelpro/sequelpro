//
//  SPJSONFormatter.h
//  sequel-pro
//
//  Created by Max Lohrmann on 10.02.17.
//  Copyright (c) 2017 Max Lohrmann. All rights reserved.
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

typedef NS_ENUM(UInt8, SPJSONToken) {
	JSON_TOK_EOF,
	JSON_TOK_CURLY_BRACE_OPEN,
	JSON_TOK_CURLY_BRACE_CLOSE,
	JSON_TOK_SQUARE_BRACE_OPEN,
	JSON_TOK_SQUARE_BRACE_CLOSE,
	JSON_TOK_DOUBLE_QUOTE,
	JSON_TOK_COLON,
	JSON_TOK_COMMA,
	JSON_TOK_OTHER,
	JSON_TOK_STRINGDATA
};

typedef NS_ENUM(UInt8, SPJSONContext) {
	JSON_ROOT_CONTEXT,
	JSON_STRING_CONTEXT
};

typedef struct {
	const char *str;
	size_t len;
	size_t pos;
	SPJSONContext ctxt;
} SPJSONTokenizerState;

typedef struct {
	SPJSONToken tok;
	size_t pos;
	size_t len;
} SPJSONTokenInfo;

/**
 * Initializes a caller defined SPJSONTokenizerState structure to the string that is passed.
 * The string is not retained. The caller is responsible for making sure it stays around as long 
 * as the tokenizer is used!
 *
 * @return 0 on success, -1 if an argument was NULL.
 */
int SPJSONTokenizerInit(NSString *input, SPJSONTokenizerState *stateInfo);

/**
 * This function returns the token that is at the current position of the input string or following
 * it most closely and forward the input string accordingly.
 * 
 * The JSON_TOK_EOF token is a zero length token that is returned after the last character in the input
 * string has been read and tokenized. Any call to this function after JSON_TOK_EOF has been returned
 * will return the same.
 *
 * JSON_TOK_OTHER and JSON_TOK_STRINGDATA are variable length tokens (but never 0) that represent whitespace,
 * numbers, true/false/null and the contents of strings (without the double quotes).
 *
 * The remaining tokens correspond to the respective control characters in JSON and are always a single
 * character long.
 *
 * The token/position/length information will be assigned to the tokenMatch argument given by the caller.
 *
 * @return  1 If a token was successfully matched
 *          0 If the matched token was JSON_TOK_EOF (tokenMatch will still be set, like for 1)
 *         -1 If the passed arguments were invalid (tokenMatch will not be updated)
 *
 * DO NOT try to build a parser/syntax validator based on this code! It is much too lenient for those purposes!
 */
int SPJSONTokenizerGetNextToken(SPJSONTokenizerState *stateInfo, SPJSONTokenInfo *tokenMatch);


@interface SPJSONFormatter : NSObject

/**
 * This method will return a formatted copy of the input string.
 *
 *  - A line break is inserted after every ",".
 *  - There will be a line break after every "{" and "[" (except if they are empty) and the indent
 *    of the following lines is increased by 1.
 *  - There will be a line break before "]" and "}" (except if they are empty) and the indent of this line
 *    and the following lines will be decreased by 1.
 *  - A line break will be inserted after "]" and "}", except if a "," follows.
 *  - Indenting is done using a single "\t" character per level.
 *
 * @return The formatted string or nil if formatting failed.
 */
+ (NSString *)stringByFormattingString:(NSString *)input;

/**
 * This method will return a compact copy of the input string.
 * All whitespace (outside of strings) will be removed (except for a single space after ":" and ",")
 *
 * @return The unformatted string or nil if unformatting failed.
 */
+ (NSString *)stringByUnformattingString:(NSString *)input;

@end
