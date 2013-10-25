%{
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#include <alloca.h>

extern void		yyerror (const char *s);
extern int		yylex (void);
extern int		yyparse (void);
extern int		yywrap (void);

void		doparse ();
int			main (int argc_, char *argv_[]);
int			nextchar ();
void		recognize (const char *s_);
int			yyparse ();
void		yywarning (const char *s_);

char *Abstract;
char *Address;
char *Author;
char *Bibdate;
char *Bibtype;
char *Bibsource;
char *Booktitle;
char *Chapter;
char *CODEN;
char *Crossref;
char *Day;
char *DOI;
char *Editor;
char *Edition;
char *Filename; 
char *Institution;
char *ISBN;
char *ISBN13;
char *ISSN;
char *Journal;
char *Keywords;
char *Label;
char *LCCN;
char *Month;
char *Monthnumber;
char *MRclass;
char *MRnumber;
char *MRreviewer;
char *Note;
char *Number;
char *Organization;
char *Publisher;
char *Pages;
char *Pagecount;
char *Remark;
char *School;
char *Subject;
char *Title;
char *Type;
char *TOC;
char *URL;
char *Volume;
char *Year;
char *Series;
char *ZMnumber;

/* Database functions */
void initialize_keys();
void do_entry();
void add_key(char *key, char *value);
void initialize();
void terminate();
char * wrap_quotes (char *string);

char			*program_name;	/* for error messages */
const char	*the_filename;

/* These variables are defined in compiler.l: */
extern long		line_number;
extern char		yytext[BIBYYLMAX];
extern void strlower (char *string);

#define	ERROR_PREFIX	"??"	/* Error prefix */
#define WARNING_PREFIX	"%%"	/* Warning prefix */
#define YYDEBUG		0
%}

%union {
  char *str;
}

%token <str> TOKEN_UNKNOWN 	0
%token <str> TOKEN_ABBREV	1
%token <str> TOKEN_AT		2
%token <str> TOKEN_COMMA	3
%token <str> TOKEN_COMMENT	4
%token <str> TOKEN_ENTRY	5
%token <str> TOKEN_EQUALS	6
%token <str> TOKEN_FIELD	7
%token <str> TOKEN_INCLUDE	8
%token <str> TOKEN_INLINE	9
%token <str> TOKEN_KEY		10
%token <str> TOKEN_LBRACE	11
%token <str> TOKEN_LITERAL	12
%token <str> TOKEN_NEWLINE	13
%token <str> TOKEN_PREAMBLE	14
%token <str> TOKEN_RBRACE	15
%token <str> TOKEN_SHARP	16
%token <str> TOKEN_SPACE	17
%token <str> TOKEN_STRING	18
%token <str> TOKEN_VALUE	19

%type <str> value simple_value assignment assignment_lhs key_name

%nonassoc TOKEN_EQUALS							/* Got these ideas from "Compiler Design In C; Allen I. Holub (1990)" */
%left TOKEN_SPACE TOKEN_INLINE TOKEN_NEWLINE	/* Also from "Compilers - Principles, Techniques and Tools; Aho, Ram, Sethi, Ullman" */
%left TOKEN_SHARP								/* Without these precedence rules, the grammar is ambigous. */

%%

file:		  opt_space
			{recognize("file-1");}
		| opt_space object_list opt_space
			{recognize("file-2"); terminate(); }
		;

object_list:	  object
			{recognize("object-1");}
		| object_list opt_space object
			{recognize("object-2");}
		;

object:	  	  TOKEN_AT opt_space at_object
			{recognize("object"); }
		;

at_object:	  comment
			{recognize("comment");}
		| entry
			{recognize("entry"); do_entry(); }
		| include
			{recognize("include");}
		| preamble
			{recognize("preamble");}
		| string
			{recognize("string");}
		| error TOKEN_RBRACE
			{recognize("error");}
		;
comment:	  TOKEN_COMMENT opt_space
			TOKEN_LITERAL
			{recognize("comment");}
		;

entry:		  entry_head
			assignment_list
			TOKEN_RBRACE
			{recognize("entry-1");}
		| entry_head
			assignment_list
			TOKEN_COMMA opt_space
			TOKEN_RBRACE
			{recognize("entry-2");}
		| entry_head TOKEN_RBRACE
			{recognize("entry-3");}
		;

entry_head:	  TOKEN_ENTRY opt_space
			TOKEN_LBRACE opt_space
			key_name opt_space
			TOKEN_COMMA opt_space
			{	
				recognize("entry_head"); 
				initialize_keys();
				free(Bibtype);	
				Bibtype = strdup($1);
				Bibtype = wrap_quotes(Bibtype);
				free(Label);
				Label = strdup($5);
				Label = wrap_quotes(Label);
				free($1);
				free($5);
			}
		;

key_name:	  TOKEN_KEY
			{recognize("key_name-1"); $$ = $1; }
		| TOKEN_ABBREV
			{recognize("key_name-2");}
		;

include:	  TOKEN_INCLUDE opt_space
			TOKEN_LITERAL
			{recognize("include");}
		;

preamble:	  TOKEN_PREAMBLE opt_space
			TOKEN_LBRACE opt_space
			value opt_space
			TOKEN_RBRACE
			{recognize("preamble");}
		;

string:		  TOKEN_STRING opt_space
			TOKEN_LBRACE opt_space
			assignment
			opt_space TOKEN_RBRACE
			{recognize("string");}
		;

value:	  	  simple_value
			{recognize("value-1"); $$ = $1;}
		| value opt_space
			{recognize("value-1-1");}
			TOKEN_SHARP
			{recognize("value-1-2");}
			opt_space simple_value
			{recognize("value-2"); $$ = $4; }
		;

simple_value:	  TOKEN_VALUE
			{recognize("simple_value-1"); $$ = $1; }
		| TOKEN_ABBREV
			{recognize("simple_value-2");}
		;

assignment_list:  assignment
			{recognize("single assignment");}
		| assignment_list
			TOKEN_COMMA opt_space
			assignment
			{recognize("assignment-list");}
		;

assignment:	  assignment_lhs opt_space
			TOKEN_EQUALS opt_space
			{recognize("assignment-0");}
			value opt_space
			{recognize("assignment"); add_key($1, $6); free($1); free($6);}
		;

assignment_lhs:	  TOKEN_FIELD
			{recognize("assignment_lhs-1"); $$ = $1; }
		| TOKEN_ABBREV
			{recognize("assignment_lhs-2");}
		;

opt_space:	/* empty */
			{recognize("opt_space-1");}
		| space
			{recognize("opt_space-2");}
		;

space:		  single_space
			{recognize("single space");}
		| space single_space
			{recognize("multiple spaces");}
		;

single_space:	  TOKEN_SPACE
		| TOKEN_INLINE
		| TOKEN_NEWLINE
		;
%%

char *wrap_quotes (char *string) {	/* Wraps a string in single quotes */
	char *temp = (char *)malloc((strlen(string)+3) * sizeof(char));
	temp[0] = '\'';
	int i = 1;
	char *p = string;
	while (*p != 0) {
		temp[i++] = *p++;
	}
	temp[i++] = '\'';
	temp[i++] = '\0';
	return (temp); 
}

void compact_space(char *string) { /* compact spaces to single blank */
    char *p;
    char *q;
    for (p = q = string; *p ; ) {
		*q++ = isspace(*p) ? ' ' : *p;
		if (isspace(*p)) {
	    	while (isspace(*p))
				++p;
		}
		else
	    	++p;
    }  
    *q = '\0';
}

void initialize_keys() {		/* Initial values of database entries */
	Abstract = strdup("NULL");
	Address = strdup("NULL");
	Author = strdup("NULL");
	Bibdate = strdup("NULL");
	Bibsource = strdup("NULL");
	Bibtype = strdup("NULL");
	Booktitle = strdup("NULL");
	Chapter = strdup("NULL");
	CODEN = strdup("NULL");
	Crossref = strdup("NULL");
	Day = strdup("NULL");
	DOI = strdup("NULL");
	Editor = strdup("NULL");
	Edition = strdup("NULL");
	Filename = strdup("NULL");
	Institution = strdup("NULL");
	ISBN = strdup("NULL");
	ISBN13 = strdup("NULL");
	ISSN = strdup("NULL");
	Journal = strdup("NULL");
	Keywords = strdup("NULL");
	Label = strdup("NULL");
	LCCN = strdup("NULL");
	Month = strdup("NULL");
	Monthnumber = strdup("NULL");
	MRclass = strdup("NULL");
	MRnumber = strdup("NULL");
	MRreviewer = strdup("NULL");
	Note = strdup("NULL");
	Number = strdup("NULL");
	Organization = strdup("NULL");
	Publisher = strdup("NULL");
	Pages = strdup("NULL");
	Pagecount = strdup("NULL");
	Remark = strdup("NULL");
	School = strdup("NULL");
	Subject = strdup("NULL");
	Title = strdup("NULL");
	Type = strdup("NULL");
	TOC = strdup("NULL");
	URL = strdup("NULL");
	Volume = strdup("NULL");
	Year = strdup("NULL");
	Series = strdup("NULL");
	ZMnumber = strdup("NULL");
}

void do_entry() {	/* Prints out the SQL query */
	printf("INSERT INTO bibtab\n");
    printf("\t(bibtype, label,\n");
    printf("\tauthor, editor, booktitle, title, crossref, chapter, journal, volume,\n");
    printf("\ttype, number, institution, organization, publisher, school,\n");
    printf("\taddress, edition, pages, day, month, year, CODEN,\n");
    printf("\tDOI, ISBN, ISBN13, ISSN, LCCN, MRclass, MRnumber, MRreviewer,\n");
    printf("\tbibdate, bibsource, note, series, URL, abstract,\n");
    printf("\tkeywords, remark, subject, TOC, ZMnumber)\n");
    printf("\tVALUES (\n");
    printf("\t%s,\n", Bibtype);
    printf("\t%s,\n", Label);
    printf("\t%s,\n", Author);
    printf("\t%s,\n", Editor);
    printf("\t%s,\n", Booktitle);
    printf("\t%s,\n", Title);
    printf("\t%s,\n", Crossref);
    printf("\t%s,\n", Chapter);
    printf("\t%s,\n", Journal);
    printf("\t%s,\n", Volume);
    printf("\t%s,\n", Type);
    printf("\t%s,\n", Number);
    printf("\t%s,\n", Institution);
    printf("\t%s,\n", Organization);
    printf("\t%s,\n", Publisher);
    printf("\t%s,\n", School);
    printf("\t%s,\n", Address);
    printf("\t%s,\n", Edition);
    printf("\t%s,\n", Pages);
    printf("\t%s,\n", Day);
    printf("\t%s,\n", Month);
    printf("\t%s,\n", Year);
    printf("\t%s,\n", CODEN);
    printf("\t%s,\n", DOI);
    printf("\t%s,\n", ISBN);
    printf("\t%s,\n", ISBN13);
    printf("\t%s,\n", ISSN);
    printf("\t%s,\n", LCCN);
    printf("\t%s,\n", MRclass);
    printf("\t%s,\n", MRnumber);
    printf("\t%s,\n", MRreviewer);
    printf("\t%s,\n", Bibdate);
    printf("\t%s,\n", Bibsource);
    printf("\t%s,\n", Note);
    printf("\t%s,\n", Series);
    printf("\t%s,\n", URL);
    printf("\t%s,\n", Abstract);
    printf("\t%s,\n", Keywords);
    printf("\t%s,\n", Remark);
    printf("\t%s,\n", Subject);
    printf("\t%s,\n", TOC);
    printf("\t%s\n", ZMnumber);
    printf(");\n");
    
    free(Bibtype);
    free(Label);
    free(Author);
    free(Editor);
    free(Booktitle);
    free(Title);
    free(Crossref);
    free(Chapter);
    free(Journal);
    free(Volume);
    free(Type);
    free(Number);
    free(Institution);
    free(Organization);
    free(Publisher);
    free(School);
    free(Address);
    free(Edition);
    free(Pages);
    free(Day);
    free(Month);
    free(Year);
    free(CODEN);
    free(DOI);
    free(ISBN);
    free(ISBN13);
    free(ISSN);
    free(LCCN);
    free(MRclass);
    free(MRnumber);
    free(MRreviewer);
    free(Bibdate);   
    free(Bibsource);
    free(Note);
    free(Series);
    free(URL);
    free(Abstract);
    free(Keywords);
    free(Remark);
    free(Subject);
    free(TOC);
    free(ZMnumber);
}

void add_key(char *key, char *value) {
	
	/* Internal text processing */

	/*	1. Remove control characters and braces
		2. Escape single quotes for sqlite */
	
	char *p1 = value;
  	char *p2 = value;
  	
   	p1 = value;
   	while(*p1 != 0) {
   		if(*p1 == '\n') {
      		++p1;
    	} else if (*p1 == '\t') {
    		++p1;
    		*p2++ = ' ';
    	} else if ( 
    		(*p1 == '{') ||						/* Add characters to strip out here */
    		(*p1 == '}') ||
    		(*p1 == '"')
    		) {
    		++p1;
    	} else if ( (*p1 == '\\') && (*(p1+1) == '\'') ) {
    		/*	The commented code doesn't segfault, but I think it
    			should. It works with EMOO.bib; pure luck
    			that the decrease in string size by stripping chars
    			is always more than the increments by escaping single quotes. */
    		//*p2++ = *p1++;
    		//*p2++ = '\'';
    		//*p2++ = *p1++;
    		++p1;
    	} else if ( (*p1 == '\'') /*&& (*(p1-1) != '\\') */ && (*(p1+1) != 0 ) && (p1 != value) ) {
    		//*p2++ = *p1++;	/* 	This code (after uncommenting) segfaults because I was trying to 
    		//*p2++ = '\''			expand my string and get away with it. But it
    		//*p2++ = *p1++;		didn't for the previous lines of code. Why? */
    		++p1;
    	} else
    		*p2++ = *p1++; 
  	}
  	*p2 = 0; 
  	
  	if (value[0] != '\'')
		value = wrap_quotes(value);
	
	compact_space(value);
	
	/* End internal text processing */
		
	//printf("Adding key:%s value:%s\n", key, value);
	
	strlower(key);	/* 	Realised this on the final day, sneaky last few
						entries of EMOO.bib, completely evaded me. */
	
	/* Copy the value into the correct field */
	if (!strcmp(key, "author")) {
			free(Author);
			Author = strdup(value);		
	} else if (!strcmp(key, "editor")) {
			free(Editor);
			Editor = strdup(value);
	} else if (!strcmp(key, "booktitle")) {
			free(Booktitle);
			Booktitle = strdup(value);
	} else if (!strcmp(key, "title")) {
			free(Title);
			Title = strdup(value);
	} else if (!strcmp(key, "crossref")) {
			free(Crossref);
			Crossref = strdup(value);
	} else if (!strcmp(key, "chapter")) {
			free(Chapter);
			Chapter = strdup(value);
	} else if (!strcmp(key, "journal")) {
			free(Journal);
			Journal = strdup(value);
	} else if (!strcmp(key, "volume")) {
			free(Volume);
			Volume = strdup(value);
	} else if (!strcmp(key, "type")) {
			free(Type);
			Type = strdup(value);
	} else if (!strcmp(key, "number")) {
			free(Number);
			Number = strdup(value);
	} else if (!strcmp(key, "institution")) {
			free(Institution);
			Institution = strdup(value);
	} else if (!strcmp(key, "organization")) {
			free(Organization);
			Organization = strdup(value);
	} else if (!strcmp(key, "publisher")) {
			free(Publisher);
			Publisher = strdup(value);
	} else if (!strcmp(key, "school")) {
			free(School);
			School = strdup(value);
	} else if (!strcmp(key, "address")) {
			free(Address);
			Address = strdup(value);
	} else if (!strcmp(key, "edition")) {
			free(Edition);
			Edition = strdup(value);
	} else if (!strcmp(key, "pages")) {
			free(Pages);
			Pages = strdup(value);
	} else if (!strcmp(key, "day")) {
			free(Day);
			Day = strdup(value);
	} else if ( (!strcmp(key, "month")) || (!strcmp(key, "date")) ) {
			free(Month);
			Month = strdup(value);
	} else if (!strcmp(key, "year")) {
			free(Year);
			Year = strdup(value);
	} else if (!strcmp(key, "coden")) {
			free(CODEN);
			CODEN = strdup(value);
	} else if (!strcmp(key, "doi")) {
			free(DOI);
			DOI = strdup(value);
	} else if (!strcmp(key, "isbn-13")) {
			free(ISBN13);
			ISBN13 = strdup(value);
	} else if (!strcmp(key, "isbn")) {
			free(ISBN);
			ISBN = strdup(value);
	} else if (!strcmp(key, "issn")) {
			free(ISSN);
			ISSN = strdup(value);
	} else if (!strcmp(key, "lccn")) {
			free(LCCN);
			LCCN = strdup(value);
	} else if (!strcmp(key, "mrclass")) {
			free(MRclass);
			MRclass = strdup(value);
	} else if (!strcmp(key, "mrnumber")) {
			free(MRnumber);			
			MRnumber = strdup(value);
	} else if (!strcmp(key, "mrreviewer")) {
			free(MRreviewer);
			MRreviewer = strdup(value);
	} else if (!strcmp(key, "bibdate")) {
			free(Bibdate);
			Bibdate = strdup(value);
	} else if (!strcmp(key, "bibsource")) {
			free(Bibsource);
			Bibsource = strdup(value);
	} else if (!strcmp(key, "note")) {
			free(Note);
			Note = strdup(value);
	} else if (!strcmp(key, "series")) {
			free(Subject);
			Subject = strdup(value);
	} else if (!strcmp(key, "url")) {
			free(URL);
			URL = strdup(value);
	} else if (!strcmp(key, "abstract")) {
			free(Abstract);
			Abstract = strdup(value);
	} else if (!strcmp(key, "keywords")) {
			free(Keywords);
			Keywords = strdup(value);
	} else if (!strcmp(key, "remark")) {
			free(Remark);
			Remark = strdup(value);
	} else if (!strcmp(key, "subject")) {
			free(Series);
			Series = strdup(value);
	} else if (!strcmp(key, "tableofcontents")) {
			free(TOC);
			TOC = strdup(value);
	} else if (!strcmp(key, "zmnumber")) {
			free(ZMnumber);
			ZMnumber = strdup(value);
	}
}

void initialize() {
	printf("DROP TABLE IF EXISTS bibtab;\n");

	printf("CREATE TABLE bibtab (\n");
	printf("\tbibtype      TEXT COLLATE NOCASE,\n");
	printf("\tlabel        TEXT COLLATE NOCASE,\n");
	printf("\tauthor       TEXT COLLATE NOCASE,\n");
	printf("\teditor       TEXT COLLATE NOCASE,\n");
	printf("\tbooktitle    TEXT COLLATE NOCASE,\n");
	printf("\ttitle        TEXT COLLATE NOCASE,\n");
	printf("\tcrossref     TEXT COLLATE NOCASE,\n");
	printf("\tchapter      TEXT COLLATE NOCASE,\n");
	printf("\tjournal      TEXT COLLATE NOCASE,\n");
	printf("\tvolume       TEXT COLLATE NOCASE,\n");
	printf("\ttype         TEXT COLLATE NOCASE,\n");
	printf("\tnumber       TEXT COLLATE NOCASE,\n");
	printf("\tinstitution  TEXT COLLATE NOCASE,\n");
	printf("\torganization TEXT COLLATE NOCASE,\n");
	printf("\tpublisher    TEXT COLLATE NOCASE,\n");
	printf("\tschool       TEXT COLLATE NOCASE,\n");
	printf("\taddress      TEXT COLLATE NOCASE,\n");
	printf("\tedition      TEXT COLLATE NOCASE,\n");
	printf("\tpages        TEXT COLLATE NOCASE,\n");
	printf("\tday          TEXT COLLATE NOCASE,\n");
	printf("\tmonth        TEXT COLLATE NOCASE,\n");
	printf("\tyear         TEXT COLLATE NOCASE,\n");
	printf("\tCODEN        TEXT COLLATE NOCASE,\n");
	printf("\tDOI          TEXT COLLATE NOCASE,\n");
	printf("\tISBN         TEXT COLLATE NOCASE,\n");
	printf("\tISBN13       TEXT COLLATE NOCASE,\n");
	printf("\tISSN         TEXT COLLATE NOCASE,\n");
	printf("\tLCCN         TEXT COLLATE NOCASE,\n");
	printf("\tMRclass      TEXT COLLATE NOCASE,\n");
	printf("\tMRnumber     TEXT COLLATE NOCASE,\n");
	printf("\tMRreviewer   TEXT COLLATE NOCASE,\n");
	printf("\tbibdate      TEXT COLLATE NOCASE,\n");
	printf("\tbibsource    TEXT COLLATE NOCASE,\n");
	printf("\tnote         TEXT COLLATE NOCASE,\n");
	printf("\tseries       TEXT COLLATE NOCASE,\n");
	printf("\tURL          TEXT COLLATE NOCASE,\n");
	printf("\tabstract     TEXT COLLATE NOCASE,\n");
	printf("\tkeywords     TEXT COLLATE NOCASE,\n");
	printf("\tremark       TEXT COLLATE NOCASE,\n");
	printf("\tsubject      TEXT COLLATE NOCASE,\n");
	printf("\tTOC          TEXT COLLATE NOCASE,\n");
	printf("\tZMnumber     TEXT COLLATE NOCASE\n");
	printf(");\n");
	
	printf("BEGIN TRANSACTION;\n");
	
}

void terminate() {
	printf("COMMIT;\n");
}

void doparse() {
    int c;
    line_number = 1L;
    c = getchar();
    ungetc(c,stdin);
    yyparse();
}


int main(int argc, char *argv[]) {
    int k;				/* index into argv[] */
    FILE *fp;
	FILE *outfile;
    
    program_name = argv[0];

	/* Redirect STDOUT to a file */
    outfile = freopen("out.sql", "w", stdout);
    if (outfile == (FILE*)NULL) {
		fprintf(stderr, "\n%s Open failure on file [%s]\n", ERROR_PREFIX, "out.sql");
		perror("perror() says");
	} 
	
	initialize();		/* SQL queries to create the tables */
	
	/* Redirect STDIN to be sourced from the specified file */
    if (argc > 1) {
		for (k = 1; k < argc; ++k) {
			fp = freopen(argv[k],"r",stdin);
			if (fp == (FILE*)NULL) {
				fprintf(stderr, "\n%s Open failure on file [%s]\n", ERROR_PREFIX, argv[k]);
				perror("perror() says");
			} else {
				the_filename = argv[k];
				doparse();
				fclose(fp);
			}
		}
    } else {
		printf("No input file specified\n");
		exit(1);
    }
    
    fclose(outfile);
    
    return 0;
}

int nextchar () {
    int c;
    c = getchar();
    if (YYDEBUG)
		putchar (c);
    return (c);
}

void recognize(const char *s) {	/* Used while debugging */
    if (YYDEBUG) {
		printf("[%s]\n", s);
		printf("\t%s\n", yytext);
	}
}

void yyerror(const char *s) {
    fflush(stdout);
    fprintf(stderr,"%s \"%s\", line %ld: %s\tNext token = \"%s\"\n",
		  ERROR_PREFIX, the_filename, line_number, s, yytext);
    fflush(stderr);
}

void yywarning(const char *s) {
    fflush(stdout);
    fprintf(stderr,"%s %s\tNext token = \"%s\"\n",
		  WARNING_PREFIX, s, yytext);
    fflush(stderr);
}
