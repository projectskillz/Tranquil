%{
	#include <Tranquil.h>
	#include <stdlib.h>
	#include "y.tab.h"
	#define UPDATE_LOC { yylloc->first_line = yylloc->last_line = yylineno; yylloc->last_column += yyleng; }
	#define RESET_COL { yylloc->last_column = 0; }
%}

/*%option reentrant*/
%option yylineno
%option bison-bridge
%option bison-locations

%%
\\[^\r\n]*                          { /* Do nothing */ }
class                               { UPDATE_LOC return tCLASS; }
end                                 { UPDATE_LOC return tEND; }
return                              { UPDATE_LOC return tRETURN; }
\.?[0-9]+(\.[0-9]+)?(e[0-9]+)?      {
                                    	UPDATE_LOC
                                    	yylval->dbl = atof(yytext);
                                    	return tNUMBER;
                                    }
\"[^\"]*\"|'[^']'                   {
                                    	UPDATE_LOC
                                    	yylval->cStr = strndup(yytext+1, yyleng-2);
                                    	return tSTRING;
                                    }
[a-zA-Z_][a-zA-Z_0-9]*              {
                                    	UPDATE_LOC
                                    	yylval->cStr = strndup(yytext, yyleng);
                                    	return tIDENTIFIER;
                                    }
[.\,=\.:\{\}\(\)\|<>\#\+\-]             { UPDATE_LOC return *yytext; }
\n                                  { RESET_COL  return *yytext; }
%%
