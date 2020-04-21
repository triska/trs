# Reasoning about Term Rewriting Systems in Prolog

This program implements the **Knuth-Bendix completion** procedure.

Project page: **https://www.metalevel.at/trs/**

As one possible application, consider the *group&nbsp;axioms*:

    group([e*X = X,
           i(X)*X = e,
           A*(B*C)= (A*B)*C]).

To obtain a convergent TRS for these equations, use:

    ?- group(Es), equations_trs(Es, Rs), maplist(portray_clause, Rs).

In this case, you obtain the *oriented* rewrite rules:

    i(A*B)==>i(B)*i(A).
    A*i(A)==>e.
    i(i(A))==>A.
    A*e==>A.
    A*B*C==>A*(B*C).
    i(A)*A==>e.
    e*A==>A.
    i(A)*(A*B)==>B.
    i(e)==>e.
    A*(i(A)*B)==>B.

You can use these rewrite&nbsp;rules to decide the *word&nbsp;problem*
in groups: determining whether two&nbsp;terms are *equal*.

You can apply these rules with `normal_form/3`. For example:

    ?- group(Es),
       equations_trs(Es, Rs),
       normal_form(Rs, e*i(i(e)), NF).
    ...
    NF = e .
