%{

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
//  More info at <https://github.com/sequelpro/sequelpro>

#import "SPSQLTokenizer.h"
#include "SPParserUtils.h"

size_t yyuoffset, yyuleng;

//keep track of the current utf-8 character (not byte) offset and token length
#define YY_USER_ACTION { yyuoffset += yyuleng; yyuleng = utf8strlen(yytext); }
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
dval		[!-\x7E\x80-\xEF]
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
`(``|[^`])*`?						{ ; }

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
