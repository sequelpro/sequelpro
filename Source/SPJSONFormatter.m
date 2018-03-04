//
//  SPJSONFormatter.m
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

#import "SPJSONFormatter.h"


static char GetNextANSIChar(SPJSONTokenizerState *stateInfo);


@implementation SPJSONFormatter

+ (NSString *)stringByFormattingString:(NSString *)input
{
	SPJSONTokenizerState stateInfo;
	if(SPJSONTokenizerInit(input,&stateInfo) == -1) return nil;
	
	NSUInteger idLevel = 0;
	
	NSCharacterSet *wsNlCharset = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	NSMutableString *formatted = [[NSMutableString alloc] init];
	
	SPJSONToken prevTokenType = JSON_TOK_EOF;
	SPJSONTokenInfo curToken;
	if(SPJSONTokenizerGetNextToken(&stateInfo,&curToken) == -1) {
		[formatted release];
		return nil;
	}
	
	BOOL needIndent = NO;
	SPJSONTokenInfo nextToken;
	do {
		//we need to know the next token to do meaningful formatting
		if(SPJSONTokenizerGetNextToken(&stateInfo,&nextToken) == -1) {
			[formatted release];
			return nil;
		}
		
		if(idLevel > 0 && (curToken.tok == JSON_TOK_SQUARE_BRACE_CLOSE || curToken.tok == JSON_TOK_CURLY_BRACE_CLOSE))
			idLevel--;
		
		//if this token is a "]" or "}" and there was no ",", "[" or "{" directly before it, add a linebreak before
		if(prevTokenType != JSON_TOK_CURLY_BRACE_OPEN && prevTokenType != JSON_TOK_SQUARE_BRACE_OPEN && prevTokenType != JSON_TOK_COMMA && (curToken.tok == JSON_TOK_SQUARE_BRACE_CLOSE || curToken.tok == JSON_TOK_CURLY_BRACE_CLOSE)) {
			[formatted appendString:@"\n"];
			needIndent = YES;
		}
		
		//if this token is on a new line indent it
		if(needIndent && idLevel > 0) {
			//32 tabs pool (with fallback for even deeper nesting)
			static NSString *tabs = @"\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t";
			NSUInteger myIdLevel = idLevel;
			while(myIdLevel > [tabs length]) {
				[formatted appendString:tabs];
				myIdLevel -= [tabs length];
			}
			[formatted appendString:[tabs substringWithRange:NSMakeRange(0, myIdLevel)]];
			needIndent = NO;
		}
		
		//save ourselves the overhead of creating an NSString if we already know what it will contain
		NSString *curTokenString;
		id freeMe = nil;
		switch (curToken.tok) {
			case JSON_TOK_CURLY_BRACE_OPEN:
				curTokenString = @"{";
				break;
				
			case JSON_TOK_CURLY_BRACE_CLOSE:
				curTokenString = @"}";
				break;
				
			case JSON_TOK_SQUARE_BRACE_OPEN:
				curTokenString = @"[";
				break;
				
			case JSON_TOK_SQUARE_BRACE_CLOSE:
				curTokenString = @"]";
				break;
				
			case JSON_TOK_DOUBLE_QUOTE:
				curTokenString = @"\"";
				break;
				
			case JSON_TOK_COLON:
				curTokenString = @": "; //add a space after ":" for readability
				break;
				
			case JSON_TOK_COMMA:
				curTokenString = @",";
				break;
				
			//JSON_TOK_OTHER
			//JSON_TOK_STRINGDATA
			default:
				curTokenString = [[NSString alloc] initWithBytesNoCopy:(void *)(&stateInfo.str[curToken.pos]) length:curToken.len encoding:NSUTF8StringEncoding freeWhenDone:NO];
				//for everything except strings get rid of surrounding whitespace
				if(curToken.tok != JSON_TOK_STRINGDATA) {
					NSString *newTokenString = [[curTokenString stringByTrimmingCharactersInSet:wsNlCharset] retain];
					[curTokenString release];
					curTokenString = newTokenString;
				}
				freeMe = curTokenString;
		}
		
		[formatted appendString:curTokenString];
		
		if(freeMe) [freeMe release];
		
		//if the current token is a "[", "{" or "," and the next token is not a "]" or "}" add a line break afterwards
		if(
		   curToken.tok == JSON_TOK_COMMA ||
		   (curToken.tok == JSON_TOK_CURLY_BRACE_OPEN && nextToken.tok != JSON_TOK_CURLY_BRACE_CLOSE) ||
		   (curToken.tok == JSON_TOK_SQUARE_BRACE_OPEN && nextToken.tok != JSON_TOK_SQUARE_BRACE_CLOSE)
		) {
			[formatted appendString:@"\n"];
			needIndent = YES;
		}
		
		if(curToken.tok == JSON_TOK_CURLY_BRACE_OPEN || curToken.tok == JSON_TOK_SQUARE_BRACE_OPEN)
			idLevel++;
		
		prevTokenType = curToken.tok;
		curToken = nextToken;
	} while(curToken.tok != JSON_TOK_EOF); //SPJSONTokenizerGetNextToken() will always return JSON_TOK_EOF once it has reached that state
	
	return [formatted autorelease];
}

+ (NSString *)stringByUnformattingString:(NSString *)input
{
	SPJSONTokenizerState stateInfo;
	if(SPJSONTokenizerInit(input,&stateInfo) == -1) return nil;
	
	NSCharacterSet *wsNlCharset = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	NSMutableString *unformatted = [[NSMutableString alloc] init];
	
	do {
		SPJSONTokenInfo curToken;
		if(SPJSONTokenizerGetNextToken(&stateInfo,&curToken) == -1) {
			[unformatted release];
			return nil;
		}
		
		if(curToken.tok == JSON_TOK_EOF) break;
		
		//save ourselves the overhead of creating an NSString from input if we already know what it will contain
		NSString *curTokenString;
		id freeMe = nil;
		switch (curToken.tok) {
			case JSON_TOK_CURLY_BRACE_OPEN:
				curTokenString = @"{";
				break;
				
			case JSON_TOK_CURLY_BRACE_CLOSE:
				curTokenString = @"}";
				break;
				
			case JSON_TOK_SQUARE_BRACE_OPEN:
				curTokenString = @"[";
				break;
				
			case JSON_TOK_SQUARE_BRACE_CLOSE:
				curTokenString = @"]";
				break;
				
			case JSON_TOK_DOUBLE_QUOTE:
				curTokenString = @"\"";
				break;
				
			case JSON_TOK_COLON:
				curTokenString = @": "; //add a space after ":" to match MySQL
				break;
				
			case JSON_TOK_COMMA:
				curTokenString = @", "; //add a space after "," to match MySQL
				break;
				
			//JSON_TOK_OTHER
			//JSON_TOK_STRINGDATA
			default:
				curTokenString = [[NSString alloc] initWithBytesNoCopy:(void *)(&stateInfo.str[curToken.pos]) length:curToken.len encoding:NSUTF8StringEncoding freeWhenDone:NO];
				//for everything except strings get rid of surrounding whitespace
				if(curToken.tok != JSON_TOK_STRINGDATA) {
					NSString *newTokenString = [[curTokenString stringByTrimmingCharactersInSet:wsNlCharset] retain];
					[curTokenString release];
					curTokenString = newTokenString;
				}
				freeMe = curTokenString;
		}
		
		[unformatted appendString:curTokenString];
		
		if(freeMe) [freeMe release];
		
	} while(1);
	
	return [unformatted autorelease];
}


@end

/**
 * This function returns the char at the current position in the input string and forwards the read pointer to the next char.
 * If the character is part of an UTF8 multibyte sequence, the function will skip forward until a single byte character is found again
 * or EOF is reached (whichever comes first).
 *
 * stateInfo MUST be valid or this will crash!
 *
 * @return Either a char in the range 0-127 or -1 if EOF is reached.
 */
char GetNextANSIChar(SPJSONTokenizerState *stateInfo) {
	do {
		if(stateInfo->pos >= stateInfo->len)
			return -1;
		char val = stateInfo->str[stateInfo->pos++];
		// all utf8 multibyte characters start with the most significant bit being 1 for all of their bytes
		// but since all JSON control characters are in the single byte ANSI compatible plane, we can just ignore any MB chars
		if((val & 0x80) == 0)
			return val;
	} while(1);
}

int SPJSONTokenizerInit(NSString *input, SPJSONTokenizerState *stateInfo) {
	if(!input || ![input respondsToSelector:@selector(UTF8String)] || stateInfo == NULL)
		return -1;
	
	stateInfo->ctxt = JSON_ROOT_CONTEXT;
	stateInfo->pos = 0;
	stateInfo->str = [input UTF8String];
	stateInfo->len = [input lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
	
	return 0;
}

int SPJSONTokenizerGetNextToken(SPJSONTokenizerState *stateInfo, SPJSONTokenInfo *tokenMatch) {
	if(tokenMatch == NULL || stateInfo == NULL || stateInfo->str == NULL)
		return -1;
	
	size_t posBefore = stateInfo->pos;
	do {
		char c = GetNextANSIChar(stateInfo);
		if(stateInfo->ctxt == JSON_STRING_CONTEXT) {
			//the only characters inside a string that are relevant to us are backslash and doublequote
			if(c == '"' || c == -1) {
				//if the string has contents, return that first
				if((stateInfo->pos - posBefore) > 1) {
					tokenMatch->tok = JSON_TOK_STRINGDATA;
					tokenMatch->pos = posBefore;
					if(c == '"')
						stateInfo->pos--; //rewind to read it again
					tokenMatch->len = stateInfo->pos - posBefore;
					return 1;
				}
				//string is terminated by EOF (invalid JSON)
				if(c == -1) {
					//switch to root context and try again to reach EOF branch below
					stateInfo->ctxt = JSON_ROOT_CONTEXT;
					continue;
				}
				stateInfo->ctxt = JSON_ROOT_CONTEXT;
				tokenMatch->tok = JSON_TOK_DOUBLE_QUOTE;
				tokenMatch->pos = posBefore;
				tokenMatch->len = stateInfo->pos - posBefore;
				return 1;
			}
			else if(c == '\\') {
				//for backslash we need to skip the next byte
				// We don't care for the value of the next byte since we don't really want to parse JSON, but only format it.
				// Thus we only have to pay attention to differntiate backslash-dquote and dquote.
				stateInfo->pos++;
			}
		}
		else if(c == -1) {
			//if there is still unreturned input, return that first
			if(posBefore < stateInfo->len) {
				tokenMatch->tok = JSON_TOK_OTHER;
				tokenMatch->pos = posBefore;
				tokenMatch->len = stateInfo->pos - posBefore;
				return 1;
			}
			tokenMatch->tok = JSON_TOK_EOF;
			tokenMatch->pos = stateInfo->pos; //EOF sits after the last character
			tokenMatch->len = 0; // EOF has no length
			return 0;
		}
		else {
			SPJSONToken tokFound = JSON_TOK_EOF;
			
			switch(c) {
				case '"':
					stateInfo->ctxt = JSON_STRING_CONTEXT;
					tokFound = JSON_TOK_DOUBLE_QUOTE;
					break;
					
				case '{':
					tokFound = JSON_TOK_CURLY_BRACE_OPEN;
					break;
					
				case '}':
					tokFound = JSON_TOK_CURLY_BRACE_CLOSE;
					break;
					
				case '[':
					tokFound = JSON_TOK_SQUARE_BRACE_OPEN;
					break;
					
				case ']':
					tokFound = JSON_TOK_SQUARE_BRACE_CLOSE;
					break;
					
				case ':':
					tokFound = JSON_TOK_COLON;
					break;
					
				case ',':
					tokFound = JSON_TOK_COMMA;
					break;
			}
			
			//if we found a token, but had to walk more than 1 char there was something else
			//between the previous token and this token, which we should report first
			if(tokFound != JSON_TOK_EOF && (stateInfo->pos - posBefore) > 1) {
				stateInfo->ctxt = JSON_ROOT_CONTEXT;
				stateInfo->pos--; //rewind so we will read the token again next time
				tokFound = JSON_TOK_OTHER;
			}
			
			if(tokFound != JSON_TOK_EOF) {
				tokenMatch->tok = tokFound;
				tokenMatch->pos = posBefore;
				tokenMatch->len = stateInfo->pos - posBefore;
				return 1;
			}
		}
	} while(1);
}
