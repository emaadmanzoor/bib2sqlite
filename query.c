#include <stdio.h>
#include <stdlib.h>
#include "sqlite3.h"
 
static int callback(void *NotUsed, int argc, char **argv, char **azColName){
	int i;
	printf("\n");
	for(i=0; i<argc; i++){
		printf("%s = %s\n", azColName[i], argv[i] ? argv[i] : "NULL");
	}
	printf("\n");
	return 0;
}
 
int main(int argc, char **argv){
	sqlite3 *db;
	char *zErrMsg = 0;
	int rc;
	
	if( argc!=2 ){
	    fprintf(stderr, "Usage: %s \"SQL-QUERY\"\n", argv[0]);
	    exit(1);
	}
	
	rc = sqlite3_open("bibtex.db", &db);
	if( rc ){
		fprintf(stderr, "Can't open database: %s\n", sqlite3_errmsg(db));
		sqlite3_close(db);
		exit(1);
	}
	rc = sqlite3_exec(db, argv[1], callback, 0, &zErrMsg);
	if( rc!=SQLITE_OK ){
		fprintf(stderr, "SQL error: %s\n", zErrMsg);
		sqlite3_free(zErrMsg);
	}
	sqlite3_close(db);
	return 0;
}

