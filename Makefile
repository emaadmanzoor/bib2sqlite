CC			= gcc
CFLAGS      =  $(DEFINES) $(INCLUDES) $(OPT)
BIBYYLMAX	= 131072
DEFINES		=  -DBIBYYLMAX=$(BIBYYLMAX)
INCLUDES	=
LIBS		= -lfl  -ly
LEX			= flex -l
YACC		= bison -d
MV			= mv -f
RM			= rm -f
OPT			= #-g -O0 -Wall

compiler: compiler.y compiler.l
	$(YACC) compiler.y				
	$(MV) compiler.tab.c compiler.c 		
	$(CC) $(CFLAGS) -c compiler.c	
	$(LEX) -o compiler.c compiler.l
	$(CC) $(CFLAGS) -o compiler compiler.o compiler.c $(LIBS)
	@-$(RM) compiler.o

sqlite3:
	$(CC) -o sqlite3 shell.c sqlite3.c -lpthread -ldl

sqlite3.o: 
	$(CC) $(OPT) -o sqlite3.o -c sqlite3.c
	$(CC) $(OPT) -o query sqlite3.o query.c -lpthread -ldl

bibtex.db: out.sql
	cat out.sql | ./sqlite3 bibtex.db
	
query: sqlite3 sqlite3.o bibtex.db
	
clean:
	-$(RM) compiler compiler.c compiler.tab.h sqlite3 query bibtex.db out.sql
	-$(RM) *.i
	-$(RM) *.o
	-$(RM) *~
	-$(RM) \#*
	-$(RM) compiler.tmp
	-$(RM) compiler.output
	-$(RM) core
	-$(RM) lex.yy.c
	-$(RM) y.output
	-$(RM) yacc.h
