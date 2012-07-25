%{

//
//  $Id$
//
//  SPSQLTokenizer.l
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on May 14, 2009.
//  Copyright (c) 2009 Hans-Jörg Bibiko. All rights reserved.
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

#import "SPSQLTokenizer.h"

int utf8strlenfortoken(const char * _s);
int yyuoffset, yyuleng;

//keep track of the current utf-8 character (not byte) offset and token length
#define YY_USER_ACTION { yyuoffset += yyuleng; yyuleng = utf8strlenfortoken(yytext); }
//ignore the output of unmatched characters
#define ECHO {}
%}
%option prefix="to"
%option noyywrap
%option nounput
%option noinput
%option case-insensitive
%option nostdinit

s			[ \t\n\r]
dkey		"delimiter"
scol		";"
dval		[!-ﾟ]
compstart	"begin"{s}
compend		{s}"end"
%x comment
%x delim
%x delimend
%x comp
%x compbody

%%

\"([^"\\]|\\(.|[\n\r]))*\"?			{ ; }
'([^'\\]|\\(.|[\n\r]))*'?			{ ; }
`[^`]*`?							{ ; }

"/*"								{ BEGIN(comment); }
<comment>[^*]* 						{ ; }
<comment>"*"+						{ ; }
<comment>"*"+"/" 					{ BEGIN(INITIAL); }
#[^\n\r]*(\n|\r)?			|
--[ \t][^\n\r]*(\n|\r)?				{ return SP_SQL_TOKEN_SINGLE_LINE_COMMENT; }

{s}+								{ ; }

{s}*{dkey}{s}+						{ BEGIN(delim); }
<delim>{dval}+						{ BEGIN(delimend); return SP_SQL_TOKEN_DELIM_VALUE; }
<delimend>{s}+{dkey}{s}+{scol}{s}*	{ BEGIN(INITIAL); return SP_SQL_TOKEN_DELIM_END; }
{compstart}							{ BEGIN(comp); }
<comp>{dval}+						{ BEGIN(compbody); }
<compbody>{compend}{s}*{scol}		{ BEGIN(INITIAL); return SP_SQL_TOKEN_COMPOUND_END; }

{scol}{s}*							{ return SP_SQL_TOKEN_SEMICOLON; }


<<EOF>>   						{
                                    BEGIN(INITIAL);   /* make sure we return to initial state when finished! */
            						yy_delete_buffer(YY_CURRENT_BUFFER);
            						return 0;
          						}
%%
#define ONEMASK ((size_t)(-1) / 0xFF)
// adapted from http://www.daemonology.net/blog/2008-06-05-faster-utf8-strlen.html
int utf8strlenfortoken(const char * _s)
{
	const char * s;
	size_t count = 0;
	size_t u;
	unsigned char b;

	/* Handle any initial misaligned bytes. */
	for (s = _s; (uintptr_t)(s) & (sizeof(size_t) - 1); s++) {
		b = *s;

		/* Exit if we hit a zero byte. */
		if (b == '\0')
			goto done;

		/* Is this byte NOT the first byte of a character? */
		count += (b >> 7) & ((~b) >> 6);
	}

	/* Handle complete blocks. */
	for (; ; s += sizeof(size_t)) {
		/* Prefetch 256 bytes ahead. */
		__builtin_prefetch(&s[256], 0, 0);

		/* Grab 4 or 8 bytes of UTF-8 data. */
		u = *(size_t *)(s);

		/* Exit the loop if there are any zero bytes. */
		if ((u - ONEMASK) & (~u) & (ONEMASK * 0x80))
			break;

		/* Count bytes which are NOT the first byte of a character. */
		u = ((u & (ONEMASK * 0x80)) >> 7) & ((~u) >> 6);
		count += (u * ONEMASK) >> ((sizeof(size_t) - 1) * 8);
	}

	/* Take care of any left-over bytes. */
	for (; ; s++) {
		b = *s;

		/* Exit if we hit a zero byte. */
		if (b == '\0')
			break;

		/* Is this byte NOT the first byte of a character? */
		count += (b >> 7) & ((~b) >> 6);
	}

done:
	return (int)((s - _s) - count);
}
