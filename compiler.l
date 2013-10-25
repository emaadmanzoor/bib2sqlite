%{
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#include "compiler.tab.h"

typedef int token_t;

extern void		yyerror (const char *s_);
extern int		yylex (void);
extern int		yyparse (void);
extern int		yywrap (void);

void		compact_space ();
void		eof_error ();
void		overflow ();
void 		strlower (char *s);
token_t		outbracedliteral ();
token_t		outbracedstring ();
token_t		outlbrace ();
token_t		outlparen ();
token_t		outrbrace ();
token_t		outrparen ();
token_t		outstring ();
token_t		outtoken (token_t t);
int			next_char ();

int			brace_level = 0;
token_t		last_object = TOKEN_UNKNOWN;
token_t		last_token = TOKEN_UNKNOWN;
long		line_number = 1L; /* Used to debug where the scanner/parser. Global in compiler.y */
int		paren_level = 0;

#undef YYLMAX				/* Increase buffer size */
#define YYLMAX BIBYYLMAX	/* 128K, should be big enough; set in the Makefile */

%}

/* Need to increase number of states and output table size
 * to accommodate for long titles and stuff like that */
 
%a		3000
%o		6000

/* abbrev, entry, key, field name syntax */
N		[A-Za-z][-A-Za-z0-9:.+/']*
					/* BibTeX entry opening delimiter */
O		[({]
					/* one white space character */
					/* \013 == \v, but lex doesn't */
					/* recognize \v */
W		[ \f\r\t\013]
					/* optional 'horizontal' space */
S		{W}*

%%
[@]				{ free(yylval.str); return (outtoken(TOKEN_AT)); }

[Cc][Oo][Mm][Mm][Ee][Nn][Tt]	{ free(yylval.str); return ((last_token == TOKEN_AT) ?
					outtoken(TOKEN_COMMENT) :
					outtoken(TOKEN_ABBREV)); }

[Ii][Nn][Cc][Ll][Uu][Dd][Ee]	{ free(yylval.str); return ((last_token == TOKEN_AT) ?
					outtoken(TOKEN_INCLUDE) :
					outtoken(TOKEN_ABBREV)); }

[Pp][Rr][Ee][Aa][Mm][Bb][Ll][Ee] { free(yylval.str); return ((last_token == TOKEN_AT) ?
					outtoken(TOKEN_PREAMBLE) :
					outtoken(TOKEN_ABBREV)); }

[Ss][Tt][Rr][Ii][Nn][Gg]	{ free(yylval.str);  
			return ((last_token == TOKEN_AT) ?
					outtoken(TOKEN_STRING) :
					outtoken(TOKEN_ABBREV)); }

{N}					{	free(yylval.str);
						if (last_object == TOKEN_STRING)
							return(outtoken(TOKEN_ABBREV));
						switch (last_token) {
							case TOKEN_COMMA:
								return(outtoken(TOKEN_FIELD));
							case TOKEN_LBRACE:
								return(outtoken(TOKEN_KEY));
							case TOKEN_AT:
								return(outtoken(TOKEN_ENTRY));
							default:
								return(outtoken(TOKEN_ABBREV));
						}
						free(yylval.str);
					}
					
[0-9]+				{ free(yylval.str); return (outtoken(TOKEN_VALUE)); }
[%].*[\n]{S}		{ free(yylval.str); return (outtoken(TOKEN_INLINE)); }
[#]					{ free(yylval.str); return (outtoken(TOKEN_SHARP)); }
["]					{ free(yylval.str); return (outstring()); }
[{]					return (outlbrace());
[}]					{ free(yylval.str); return (outrbrace()); }
[(]					{ free(yylval.str); return (outlparen()); }
[)]					{ free(yylval.str); return (outrparen()); }
[=]					return (outtoken(TOKEN_EQUALS));
[,]					return (outtoken(TOKEN_COMMA));
[\n]				return (outtoken(TOKEN_NEWLINE));
{W}+				return (outtoken(TOKEN_SPACE));
.					{ free(yylval.str); return (outtoken(TOKEN_LITERAL)); }

%%

void eof_error() {
    fprintf(stderr,"Unexpected EOF.\n");
    exit(1);
}

int next_char() {
    int c;
    c = input();
    if (c == EOF)
		eof_error();
    else if (c == '\n')
		line_number++;
    return (c);
}

token_t outbracedliteral() {
    int c;
    int n;
    int plevel = paren_level;

    for (n = 1; brace_level > 0; ){
		c = next_char();
		if (c == EOF)
			break;
		if (n > (YYLMAX - 2))
			overflow();
		yytext[n++] = c;
		switch (c) {
			case '(':
				plevel++;
				break;
			case ')':
				plevel--;
				break;
			case '{':
				brace_level++;
				break;
			case '}':
				brace_level--;
				break;
			default:
				break;
		}
		if ((paren_level > 0) && (plevel == 0))
			break;
    }
    yytext[0] = '{';
    yytext[n-1] = '}';
    yytext[n] = '\0';
    return (outtoken(TOKEN_LITERAL));
}

/* Convert braced to quoted string,
 * and a bit more text processing. 
 * Easier done here then using yacc.
 */
token_t outbracedstring() {					
    
    int blevel;
    int c;
    int n;
	free(yylval.str);
    for (blevel = 1, n = 1; (blevel > 0); ) {
		c = next_char();
		if (c == EOF)
			break;
		if (n > (YYLMAX - 5))
			overflow();
		
		yytext[n++] = c;
	
		switch (c) {
			case '{':
				blevel++;
				break;

			case '}':
				blevel--;
				break;

			case '"':
				if (blevel == 1) {
					if (yytext[n-2] == '\\') {	/* Match the pattern \" */
						c = next_char();
						if (c == '{') {
							yytext[n++] = c;
							blevel++;
						}
						if (c == EOF)
							break;
						yytext[n-2] = '{';
						yytext[n-1] = '\\';
						yytext[n++] = '\"';
						yytext[n++] = c;
						yytext[n++] = '}';
					} else {
						yytext[n-1] = '{';
						yytext[n++] = '\"';
						yytext[n++] = '}';
					}
				}
				break;

			default:
				break;
		}
    }
    
    yytext[0] = '\'';
    yytext[n-1] = '\'';
    yytext[n] = '\0';
    
    return (outtoken(TOKEN_VALUE));
}

token_t outlbrace() {
    if (brace_level == 0) {
		brace_level++;
		switch (last_object) {
			case TOKEN_COMMENT:
			case TOKEN_INCLUDE:
				return (outbracedliteral());
			default:
				return (outtoken(TOKEN_LBRACE));
		}
    }
    else
		return (outbracedstring());
}

token_t outlparen() {
    switch (last_token) {
		case TOKEN_ENTRY:
		case TOKEN_PREAMBLE:
		case TOKEN_STRING:
			yytext[0] = '{';
			paren_level++;
			brace_level++;
			return (outtoken(TOKEN_LBRACE));

		case TOKEN_COMMENT:
		case TOKEN_INCLUDE:
			yytext[0] = '{';
			paren_level++;
			brace_level++;
			return (outbracedliteral());

		default:
			return (outtoken(TOKEN_LITERAL));
    }
}

token_t outrbrace() {
    if (brace_level == 1) {
		brace_level--;
		return (outtoken(TOKEN_RBRACE));
    } else
		return (outtoken(TOKEN_LITERAL));
}

token_t outrparen() {
    paren_level--;
    if (paren_level  == 0) {
		yytext[0] = '}';
		brace_level--;
		return (outtoken(TOKEN_RBRACE));
    } else
		return (outtoken(TOKEN_LITERAL));
}

token_t outstring() {
    int blevel;
    int c;
    int n;

    for (blevel = 0, n = 1; ; ) {
		
		c = next_char();
		
		if (c == EOF)
			break;
	
		if (n > (YYLMAX - 2))
			overflow();
		
		yytext[n++] = c;
		
		switch (c) {
			case '{':
				blevel++;
				break;
			case '}':
				blevel--;
				break;
			case '"':
				if (blevel == 0)
				goto LOOP_EXIT;	/* Can't break; through the switch, and out of the loop */
			default:
				break;
		}
    }
 
	LOOP_EXIT:
		yytext[n++] = '\0';
		return (outtoken(TOKEN_VALUE));
}

/* ALL token output is directed through this function */
token_t outtoken(token_t t) {
	yylval.str = strdup(yytext);
    switch (t) {
    	case TOKEN_AT:
			last_object = TOKEN_UNKNOWN;
			break;

    	case TOKEN_VALUE:
			break;

		case TOKEN_COMMENT:
		case TOKEN_INCLUDE:
			last_object = t;
			break;

		case TOKEN_ENTRY:
		case TOKEN_PREAMBLE:
		case TOKEN_STRING:
			strlower(yytext);
			free(yylval.str);
			yylval.str = strdup(yytext);
			last_object = t;
			break;
	
		case TOKEN_KEY:	
    	case TOKEN_FIELD:
			break;

		case TOKEN_INLINE:
		case TOKEN_NEWLINE:
			line_number++;
			break;

    	case TOKEN_LITERAL:
    	default:
			break;
    }
    
    /* Remember last non-space token type */
    if (!((t == TOKEN_INLINE) || (t == TOKEN_SPACE) || (t == TOKEN_NEWLINE)))
		last_token = t;
		
    return (t);
}

void strlower ( char *s ) {
	int i;
  	for( i = 0; s[i]; i++)
    	s[i] = tolower( s[i] );	
}

void overflow() {
    fprintf(stderr, "Overflowed buffer of size %d\n", YYLMAX);
    exit(1);
}
