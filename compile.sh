flex lex.l
bison -d parser.y
gcc -ll -o parser lex.yy.c parser.tab.c ast.c