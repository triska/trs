# Reasoning about Term Rewriting Systems

Consider the group axioms:

    group([e*X = X,
           i(X)*X = e,
           A*(B*C)= (A*B)*C]).

To obtain a convergent TRS for these equations, use:

    ?- group(Es), equations_trs(Es, Rs), maplist(writeln, Rs).

You obtain the rewrite rules:

    i(X1*X2)==>i(X2)*i(X1)
    X3*i(X3)==>e
    i(i(X4))==>X4
    X5*e==>X5
    X6*X7*X8==>X6* (X7*X8)
    i(X9)*X9==>e
    e*X9==>X9
    i(X10)* (X10*X11)==>X11
    i(e)==>e
    X12* (i(X12)*X13)==>X13

You can apply these rules with `normal_form/3`:

    ?- group(Es), equations_trs(Es, Rs), normal_form(Rs, e*i(i(e)), NF).
    ...
    NF = e .
