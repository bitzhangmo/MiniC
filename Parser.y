%error-verbose
%locations
%{
#include "stdio.h"
#include "math.h"
#include "string.h"
#include "def.h"
extern int yylineno;
extern char *yytext;
extern FILE *yyin;
void yyerror(const char* fmt, ...);
void display(struct node *,int);
%}

%union {
	int    type_int;
	float  type_float;
        char   type_char;
	char   type_id[32];
	struct node *ptr;
};

//  %type 定义非终结符的语义值类型
%type  <ptr> program ExtDefList ExtDef  Specifier ExtDecList FuncDec CompSt VarList VarDec ParamDec Stmt StmList DefList Def DecList Dec Exp Args IntList

//% token 定义终结符的语义值类型
%token <type_int> INT              //指定INT的语义值是type_int，有词法分析得到的数值
%token <type_id> ID RELOP TYPE  //指定ID,RELOP 的语义值是type_id，有词法分析得到的标识符字符串
%token <type_float> FLOAT         //指定ID的语义值是type_id，有词法分析得到的标识符字符串
%token <type_char> CHAR                 // 制定CHAR的语义值是type_char，有词法分析得到的字符

%token LP RP LC RC SEMI COMMA LB RB   //用bison对该文件编译时，带参数-d，生成的exp.tab.h中给这些单词进行编码，可在lex.l中包含parser.tab.h使用这些单词种类码
%token PLUS MINUS STAR DIV ASSIGNOP AND OR NOT IF ELSE WHILE RETURN SELFPLUS SELFMINUS PLUSASS MINUSASS STARASS DIVASS NMINUS FOR

%left ASSIGNOP
%left OR
%left AND
%left RELOP
%left SELFPLUS SELFMINUS
%left PLUSASS MINUSASS
%left PLUS MINUS
%left STARASS DIVASS
%left STAR DIV
%right UMINUS NOT

%nonassoc LOWER_THEN_ELSE
%nonassoc ELSE

%%
/*显示语法树,语义分析*/
program: ExtDefList    { display($1,0);}     
         ; 
/*外部定义列表*/
ExtDefList: {$$=NULL;}
          | ExtDef ExtDefList {$$=mknode(EXT_DEF_LIST,$1,$2,NULL,yylineno);}   //每一个EXTDEFLIST的结点，其第1棵子树对应一个外部变量声明或函数
          ;  
/*外部变量与函数声明*/
ExtDef:   Specifier ExtDecList SEMI   {$$=mknode(EXT_VAR_DEF,$1,$2,NULL,yylineno);}   //该结点对应一个外部变量声明
         |Specifier FuncDec CompSt    {$$=mknode(FUNC_DEF,$1,$2,$3,yylineno);}         //该结点对应一个函数定义
         | error SEMI   {$$=NULL; }
         ;
/*类型标识符*/
Specifier:  TYPE    {$$=mknode(TYPE,NULL,NULL,NULL,yylineno);strcpy($$->type_id,$1);$$->type=!strcmp($1,"int")?INT:FLOAT;}   
           ;   
/**/   
ExtDecList:  VarDec      {$$=$1;}       /*每一个EXT_DECLIST的结点，其第一棵子树对应一个变量名(ID类型的结点),第二棵子树对应剩下的外部变量名*/
           | VarDec COMMA ExtDecList {$$=mknode(EXT_DEC_LIST,$1,$3,NULL,yylineno);}
           ;
/*变量与数组声明*/  
VarDec:  ID          {$$=mknode(ID,NULL,NULL,NULL,yylineno);strcpy($$->type_id,$1);}   //ID结点，标识符符号串存放结点的type_id
        | VarDec LB IntList RB {$$=mknode(ARRAY,$1,$3,NULL,yylineno);strcpy($$->type_id,$1);}   // 数组
         ;
IntList: INT            {$$=mknode(INT,NULL,NULL,NULL,yylineno);$$->type_int=$1;$$->type=INT;}
        ;
/*函数声明与参数表列*/
FuncDec: ID LP VarList RP   {$$=mknode(FUNC_DEC,$3,NULL,NULL,yylineno);strcpy($$->type_id,$1);}//函数名存放在$$->type_id
	|ID LP RP   {$$=mknode(FUNC_DEC,NULL,NULL,NULL,yylineno);strcpy($$->type_id,$1);}//函数名存放在$$->type_id

        ;  

VarList: ParamDec  {$$=mknode(PARAM_LIST,$1,NULL,NULL,yylineno);}
        | ParamDec COMMA  VarList  {$$=mknode(PARAM_LIST,$1,$3,NULL,yylineno);}
        ;
ParamDec: Specifier VarDec         {$$=mknode(PARAM_DEC,$1,$2,NULL,yylineno);}
         ;

CompSt: LC DefList StmList RC    {$$=mknode(COMP_STM,$2,$3,NULL,yylineno);}
       ;
StmList: {$$=NULL; }  
        | Stmt StmList  {$$=mknode(STM_LIST,$1,$2,NULL,yylineno);}
        ;
Stmt:   Exp SEMI    {$$=mknode(EXP_STMT,$1,NULL,NULL,yylineno);}
      | CompSt      {$$=$1;}      //复合语句结点直接最为语句结点，不再生成新的结点
      | RETURN Exp SEMI   {$$=mknode(RETURN,$2,NULL,NULL,yylineno);}
      | IF LP Exp RP Stmt %prec LOWER_THEN_ELSE   {$$=mknode(IF_THEN,$3,$5,NULL,yylineno);}
      | IF LP Exp RP Stmt ELSE Stmt   {$$=mknode(IF_THEN_ELSE,$3,$5,$7,yylineno);}
      | WHILE LP Exp RP Stmt {$$=mknode(WHILE,$3,$5,NULL,yylineno);}
      | FOR LP Exp SEMI Exp SEMI Exp RP Stmt {$$=mknode(FOR,$5,$9,NULL,yylineno);}
      | FOR LP DecList SEMI Exp SEMI Exp RP Stmt {$$=mknode(FOR,$5,$9,NULL,yylineno);}
      | FOR LP SEMI Exp SEMI Exp RP Stmt {$$=mknode(FOR,$4,$8,NULL,yylineno);}
      | FOR LP SEMI Exp SEMI RP Stmt {$$=mknode(FOR,$4,$7,NULL,yylineno);}
      ;
  
DefList: {$$=NULL; }
        | Def DefList {$$=mknode(DEF_LIST,$1,$2,NULL,yylineno);}
        ;
Def:    Specifier DecList SEMI {$$=mknode(VAR_DEF,$1,$2,NULL,yylineno);}
        ;
DecList: Dec  {$$=mknode(DEC_LIST,$1,NULL,NULL,yylineno);}
       | Dec COMMA DecList  {$$=mknode(DEC_LIST,$1,$3,NULL,yylineno);}
       | VarDec  {$$=$1;}
	   ;
Dec:    VarDec ASSIGNOP Exp {$$=mknode(ASSIGNOP,$1,$3,NULL,yylineno);strcpy($$->type_id,"ASSIGNOP");}           // 已有变量赋值
       | Specifier VarDec ASSIGNOP Exp {$$=mknode(ASSIGNOP,$1,$2,$4,yylineno);strcpy($$->type_id,"ASSIGNOP")}   // 声明变量并赋值
       ;

/*一切算术运算*/
Exp:    Exp ASSIGNOP Exp {$$=mknode(ASSIGNOP,$1,$3,NULL,yylineno);strcpy($$->type_id,"ASSIGNOP");}      // $$结点type_id空置未用，正好存放运算符
      | Exp AND Exp   {$$=mknode(AND,$1,$3,NULL,yylineno);strcpy($$->type_id,"AND");}                   // 与
      | Exp OR Exp    {$$=mknode(OR,$1,$3,NULL,yylineno);strcpy($$->type_id,"OR");}                     // 或
      | Exp RELOP Exp {$$=mknode(RELOP,$1,$3,NULL,yylineno);strcpy($$->type_id,$2);}                    // 词法分析关系运算符号自身值保存在$2中
      | Exp PLUS Exp  {$$=mknode(PLUS,$1,$3,NULL,yylineno);strcpy($$->type_id,"PLUS");}                 // 加
      | Exp SELFPLUS  {$$=mknode(SELFPLUS,$1,NULL,NULL,yylineno);strcpy($$->type_id,"SELFPLUS");}       // 自增
      | SELFPLUS Exp  {$$=mknode(SELFPLUS,$2,NULL,NULL,yylineno);strcpy($$->type_id,"SELFPLUS");}       // 自增
      | Exp PLUSASS Exp   {$$=mknode(PLUSASS,$1,$3,NULL,yylineno);strcpy($$->type_id,"PLUSASS");}       // 复合加
      | Exp MINUS Exp {$$=mknode(MINUS,$1,$3,NULL,yylineno);strcpy($$->type_id,"MINUS");}               // 减
      | Exp SELFMINUS {$$=mknode(SELFMINUS,$1,NULL,NULL,yylineno);strcpy($$->type_id,"SELFMINUS");}     // 自减
      | Exp MINUSASS Exp  {$$=mknode(MINUSASS,$1,$3,NULL,yylineno);strcpy($$->type_id,"MINUSASS");}     // 复合减
      | SELFMINUS Exp {$$=mknode(SELFMINUS,$2,NULL,NULL,yylineno);strcpy($$->type_id,"SELFMINUS");}     // 自减
      | Exp STAR Exp  {$$=mknode(STAR,$1,$3,NULL,yylineno);strcpy($$->type_id,"STAR");}                 // 乘
      | Exp DIV Exp   {$$=mknode(DIV,$1,$3,NULL,yylineno);strcpy($$->type_id,"DIV");}                   // 除
      | Exp STARASS Exp {$$=mknode(STARASS,$1,$3,NULL,yylineno);strcpy($$->type_id,"STARASS");}         // 复合乘
      | Exp DIVASS Exp  {$$=mknode(DIVASS,$1,$3,NULL,yylineno);strcpy($$->type_id,"DIVASS");}           // 复合除
      | LP Exp RP     {$$=$2;}                                                                          // 括号
      | MINUS Exp %prec UMINUS   {$$=mknode(UMINUS,$2,NULL,NULL,yylineno);strcpy($$->type_id,"UMINUS");}// 减优先级高于负
      | NOT Exp       {$$=mknode(NOT,$2,NULL,NULL,yylineno);strcpy($$->type_id,"NOT");}                 // 非
      | ID LP Args RP {$$=mknode(FUNC_CALL,$3,NULL,NULL,yylineno);strcpy($$->type_id,$1);}              // 有参数函数
      | ID LP RP      {$$=mknode(FUNC_CALL,NULL,NULL,NULL,yylineno);strcpy($$->type_id,$1);}            // 无参数函数
      | ID            {$$=mknode(ID,NULL,NULL,NULL,yylineno);strcpy($$->type_id,$1);}                   // 数据类型
      | INT           {$$=mknode(INT,NULL,NULL,NULL,yylineno);$$->type_int=$1;$$->type=INT;}
      | FLOAT         {$$=mknode(FLOAT,NULL,NULL,NULL,yylineno);$$->type_float=$1;$$->type=FLOAT;}
      | CHAR          {$$=mknode(CHAR,NULL,NULL,NULL,yylineno);$$->type_char=$1,$$->type=CHAR;}
      ;
/**/
Args:    Exp COMMA Args    {$$=mknode(ARGS,$1,$3,NULL,yylineno);}
       | Exp               {$$=mknode(ARGS,$1,NULL,NULL,yylineno);}
       ;
       
%%

int main(int argc, char *argv[]){
	yyin=fopen(argv[1],"r");
	if (!yyin) return 0;
	yylineno=1;
	yyparse();
	return 0;
	}

#include<stdarg.h>
void yyerror(const char* fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    fprintf(stderr, "Grammar Error at Line %d Column %d: ", yylloc.first_line,yylloc.first_column);
    vfprintf(stderr, fmt, ap);
    fprintf(stderr, ".\n");
}	
