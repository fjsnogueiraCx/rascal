module experiments::Compiler::Examples::Tst3

import String;

public str functionPath(str fname, str namespace="") =
    "aaa" when namespace=="";
    
    
value main() = functionPath("broken");