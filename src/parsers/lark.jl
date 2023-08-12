#=
Lark转换器
- 基于EBNF、Lark及其对应Julia库Lerche
- 可平替JuNarsese内置的字符串转换器

=#

using Lerche

"""
原Narsese语法
- 原作者：pynars@bowen-xu
- 文件来源：pynars/Narsese/Parser/narsese.lark
"""
const NARSESE_GRAMMAR::String = raw"""

?start: sentence | term    // 迁移者注：此处转换成词项/语句，以示明晰（任务暂不使用）

task : [budget] sentence                                       // (* task to be processed *)
?sentence.0 : (term_nonvar|statement) "." [tense] [truth]  -> judgement   // (* judgement to be absorbed into beliefs *)
        | (term_nonvar|statement) "?" [tense]            -> question    // (* question on truth-value to be answered *)
        | (term_nonvar|statement) "!" [tense] [desire]   -> goal        // (* goal to be realized by operations *)
        | (term_nonvar|statement) "@" [tense]            -> quest       // (* question on desire-value to be answered *)

?statement.0 : "<" term copula term ">"               // (* two terms related to each other *)
        | "(" term copula term ")"                  // (* two terms related to each other, new notation *)
        // | term                                   // (* a term can name a statement *)
        | "(" op ("," term)* ")"             -> statement_operation1    // (* an operation to be executed *)
        | word "(" term ("," term)* ")"            -> statement_operation2 // (* an operation to be executed, new notation *)
?copula : "-->" -> inheritance                                    // (* inheritance *)
        | "<->" -> similarity                                    // (* similarity *)
        | "{--" -> instance                                   // (* instance *)
        | "--]" -> property                                   // (* property *)
        | "{-]" -> instance_property                                    // (* instance-property *)
        | "==>" -> implication                                   // (* implication *)
        | "=/>" -> predictive_implication                                    // (* predictive implication *)
        | "=|>" -> concurrent_implication                                    // (* concurrent implication *)
        | "=\>" -> retrospective_implication                                    // (* retrospective implication *)
        | "<=>" -> equivalence                                    // (* equivalence *)
        | "</>" -> predictive_equivalence                                    // (* predictive equivalence *)
        | "<|>" -> concurrent_equivalence                                    // (* concurrent equivalence *)

?term : variable        -> variable_term                          // (* an atomic variable term *)
        | term_nonvar

?term_nonvar: interval
        | word        -> atom_term                         // (* an atomic constant term *)
        | compound_term   -> compound_term                          // (* a term with internal structure *)
        | statement       -> statement_term                          // (* a statement can serve as a term *)
        | op
        
        

op : "^" word
interval: "+" NUMBER

?compound_term : set
        | multi                                     // (* with prefix or with infix operator *)
        | single                                    // (* with prefix or with infix operator *)
        | ext_image                                 // (* special case, extensional image *)
        | int_image                                  // (* special case, \ intensional image *)
        | negation                                   // (* negation *)

?set : int_set
        | ext_set
        // | list_set
?int_set   : con_int_set term ("," term)* "]"  -> set                               // (* intensional set *)
?ext_set   : con_ext_set term ("," term)* "}"  -> set                               // (* extensional set *)
// list_set: "(" "#" "," term ("," term)+ ")"    

negation  : con_negation term                                                // (* negation *)
        | "(" con_negation "," term ")"                       // (* negation, new notation *)       
int_image : "(" con_int_image "," term ("," term)* ")"                                // (* intensional image *)
ext_image : "(" con_ext_image "," term ("," term)* ")"                                 // (* extensional image *)
?multi : "(" con_multi "," term ("," term)+ ")" -> multi_prefix    // (* with prefix operator *)
        | "(" multi_infix_expr ")"             // (* with infix operator *)
        | "(" term ("," term)+ ")"                                  -> multi_prefix_product// (* product, new notation *)
        | "(" con_product "," term ("," term)* ")"                  -> multi_prefix    // (* with prefix operator *)

?single : "(" con_single "," (term|multi_infix_expr) "," (term|multi_infix_expr) ")"  -> single_prefix   // (* with prefix operator *)
        | "(" (term|multi_infix_expr) con_single (term|multi_infix_expr) ")"          -> single_infix    // (* with infix operator *)

?multi_infix_expr : multi_extint_expr
        | multi_intint_expr
        | multi_parallel_expr
        | multi_sequential_expr
        | multi_conj_expr
        | multi_disj_expr
        | multi_prod_expr

// precedence:
//  "&" > "|" > "&|" > "&/" >  "&&" > "||" > "*"
?multi_prod_expr : term6 ("*" term6)+
?term6 : (term5|multi_disj_expr)
?multi_disj_expr: term5 ("||" term5)+
?term5 : (term4|multi_conj_expr)
?multi_conj_expr: term4 ("&&" term4)+
?term4 : (term3|multi_sequential_expr)
?multi_sequential_expr: term3 ("&/" term3)+
?term3 : (term2|multi_parallel_expr)
?multi_parallel_expr: term2 ("&|" term2)+
?term2 : (term1|multi_intint_expr)
?multi_intint_expr : term1 ("|" term1)+
?term1 : (term|multi_extint_expr)
?multi_extint_expr : term ("&" term)+



?con_multi : "&&"     -> con_conjunction                                // (* conjunction *)
        | "||"        -> con_disjunction                              // (* disjunction *)
        | "&|"        -> con_parallel_events                              // (* parallel events *)
        | "&/"        -> con_sequential_events                // (* sequential events *)
        | "|"         -> con_intensional_intersection              // (* intensional intersection *)
        | "&"         -> con_extensional_intersection                              // (* extensional intersection *)
con_product: "*"                                       // (* product *)


?con_single : "-"     -> con_extensional_difference                             // (* extensional difference *)
        | "~"         -> con_intensional_difference                             // (* intensional difference *)
?con_int_set: "["                                 // (* intensional set *) 
?con_ext_set: "{"                                  // (* extensional set *)

?con_negation : "--"                              // (* negation *)

?con_int_image : /\\/                              // (* intensional image *) // 迁移者注：Lerche用字符串表示反斜杠与Lark存在不一致，需要使用正则表达式进行替代
?con_ext_image : "/"                              // (* extensional image *)

?variable.0 : "$" word -> independent_var              // (* independent variable *)
        | "#" word   -> dependent_var                // (* dependent variable *)
        | "?" word   -> query_var                    // (* query variable in question *)

?tense : ":!" NUMBER ":" -> tense_time
        | ":/:"       -> tense_future                       // (* future event *)
        | ":|:"      -> tense_present                      // (* present event *)
        | ":\:"      -> tense_past                         // (* past event *)

?desire : truth                                                          // (* same format, different interpretations *)
truth : "%" frequency [";" confidence [";" k_evidence]] "%"             // (* two numbers in [0,1]x(0,1) *)
budget.2: "$" priority [";" durability [";" quality]] "$"                // (* three numbers in [0,1]x(0,1)x[0,1] *)

?word : string_raw | string // /[^\ ]+/                                     //(* unicode string *)    
?priority : /([0]?\.[0-9]+|1\.[0]*|1|0)/             //(* 0 <= x <= 1 *)
?durability : /[0]?\.[0]*[1-9]{1}[0-9]*/             // (* 0 <  x <  1 *)
?quality : /([0]?\.[0-9]+|1\.[0]*|1|0)/              // (* 0 <= x <= 1 *)
?frequency : /([0]?\.[0-9]+|1\.[0]*|1|0)/            // (* 0 <= x <= 1 *)
?confidence : /[0]?\.[0]*[1-9]{1}[0-9]*/             // (* 0 <  x <  1 *)
?k_evidence: /[1-9]{1}[0-9]*/                           // (* x > 0 *)

?string: /"[^"]+"/
?string_raw: /[^\-^\+^<^>^=^"^&^|^!^.^?^@^~^%^;^\,^:^\/^\\^*^#^$^\[^\]^\{^\}^\(^\)^\ ]+/

%import common.WS
%import common.SIGNED_INT -> NUMBER
// %import common.INT -> NATURAL_NUMBER
%ignore WS

""";

narsese_parser = Lark(
    narsese_grammar2;
    # parser = "lalr"
)

parse_nse = s -> Lerche.parse(narsese_parser, s)

tree_1 = "<A --> B>." |> parse_nse
@show tree_1

narsese_parser
