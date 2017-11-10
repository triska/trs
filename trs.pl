/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Reason about Term Rewriting Systems.
   Written March 8th 2015 by Markus Triska (triska@metalevel.at)
   Public domain code.

   Motivating example
   ==================

      Consider a set S that is closed under the binary operation *,
      satisfying the equations:

          1) e*X = X
          2) i(X)*X = e
          3) X*(Y*Z) = (X*Y)*Z

      The algebraic structure <S, *> is called a group.

   From these equations, we can infer additional identities, such as:

      e*X = (i(i(X))*i(X))*X =
          = i(i(X))*(i(X)*X) =
          = i(i(X))*e

   Other identities that follow from these equations are i(i(X)) = X,
   i(e) = e, and many others.

   However, it is not immediately clear which identities are implied
   by these equations. In many cases, new terms must be inserted into
   equations in order to derive further identities, and it is not
   clear how far an ongoing derivation must be extended to derive a
   new identity, or if that is possible at all.

   Under certain conditions, we can convert such a set of equations
   into a set of oriented rewrite rules that always terminate and
   reduce identical elements to the same normal form. We call such a
   set of rewrite rules a convergent term rewriting system (TRS).

   For example (see group/1 below):

      ?- group(Gs), equations_trs(Gs, Rs), maplist(writeln, Rs).

   yielding the convergent TRS:

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

   From this, we see that i(i(X)) = X is one of the consequences of
   the equations above. To see whether two terms are identical under
   the given equations, we can now simply check whether they reduce to
   the same normal form under the computed rewrite rules:

      ?- group(Gs), equations_trs(Gs, Rs),
         normal_form(Rs, i(i(X)), NF),
         normal_form(Rs, i(i(i(i(X)))), NF).
      ...
      X = NF .
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Variables in equations and TRS are represented by Prolog variables.

   A major advantage of this representation is that efficient built-in
   Prolog predicates can be used for unification etc. The terms are
   also easier to read and type for users when specifying a TRS.
   However, care must be taken not to accidentally unify variables
   that are supposed to be different. copy_term/2 must be used when
   necessary to prevent this. Conversely, we also must retain all
   bindings that are supposed to hold.

   We use:

      Left ==> Right

   to denote a rewrite rule. A TRS is a list of such rules.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

:- use_module(library(clpfd)).

:- op(800, xfx, ==>).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Perform one rewriting step at the root position, using the first
   matching rule, if any.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

step([L==>R|Rs], T0, T) :-
        (   subsumes_term(L, T0) ->
            copy_term(L-R, T0-T)
        ;   step(Rs, T0, T)
        ).

%?- step([f(a) ==> f(a), f(X) ==> b], f(a), T).
%?- step([g(f(X)) ==> X], g(Y), T).
%?- step([f(X) ==> b, f(a) ==> f(a)], f(a), T).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Reduce to normal form. May not terminate!
   For example: R = { a -> a, f(x) -> b },
   although f(a) does have a normal form!
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

%?- normal_form([f(X) ==> b, a ==> a], f(a), T).
%?- normal_form([a ==> a, f(X) ==> b], f(a), T).

normal_form(Rs, T0, T) :-
        (   var(T0) -> T = T0
        ;   T0 =.. [F|Args0],
            maplist(normal_form(Rs), Args0, Args1),
            T1 =.. [F|Args1],
            (   step(Rs, T1, T2) ->
                normal_form(Rs, T2, T)
            ;   T = T1
            )
        ).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Critical Pairs
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

%?- critical_pairs([X==>a, Y ==> b], Ps).

critical_pairs(Rs, CPs) :-
        phrase(critical_pairs_(Rs, Rs), CPs).

critical_pairs_([], _) --> [].
critical_pairs_([R|Rs], Rules) -->
        rule_cps(R, Rules, []),
        critical_pairs_(Rs, Rules).

rule_cps(T ==> R, Rules, Cs) -->
        (   { var(T) } -> []
        ;   head_cps(Rules, T ==> R, Cs),
            { T =.. [F|Ts] },
            inner_cps(Ts, F, [], R, Rules, Cs)
        ).

head_cps([], _, _) --> [].
head_cps([Head0==>Right0|Rules], T0==>R0, Cs0) -->
        { copy_term(Cs0-T0-R0, Cs-T-R),
          copy_term(Head0-Right0, Head-Right) },
        (   { unify_with_occurs_check(T, Head) } ->
            { foldl(context, Cs, Right, CRight) },
            [R=CRight]
        ;   []
        ),
        head_cps(Rules, T0==>R0, Cs0).

inner_cps([], _, _, _, _, _) --> [].
inner_cps([T|Ts], F, Left0, R, Rules, Cs) -->
        { reverse(Left0, Left) },
        rule_cps(T ==> R, Rules, [conc(F,Left,Ts)|Cs]),
        inner_cps(Ts, F, [T|Left0], R, Rules, Cs).

context(conc(F,Ts1,Ts2), Arg, T) :-
        append(Ts1, [Arg|Ts2], Ts),
        T =.. [F|Ts].

%?- foldl(context, [conc(f,[x],[y]),conc(g,[a],[b])], -, R).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Lexicographic order.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

%?- ord([a,b,c], b, a, Ord).

ord(Fs, F1, F2, Ord) :-
        once((nth0(N1, Fs, F1),
              nth0(N2, Fs, F2))),
        compare(Ord, N1, N2).

lex(Cmp, Xs, Ys, Ord) :- lex_(Xs, Ys, Cmp, Ord).

lex_([], [], _, =).
lex_([X|Xs], [Y|Ys], Cmp, Ord) :-
        ord_call(Cmp, X, Y, Ord0),
        (   Ord0 == (=) -> lex_(Xs, Ys, Cmp, Ord)
        ;   Ord = Ord0
        ).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Multiset order.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

%?- foldl(subtract_element(ord([a,b,c])), [a], [a,a,b,c], Rs).
%?- multiset_diff(ord([a,b,c]), [a,a,b,b], [a,b,c], Ds).

multiset_diff(Cmp, Xs0, Ys, Xs) :-
        foldl(subtract_element(Cmp), Ys, Xs0, Xs).

subtract_element(Cmp, Y, Xs0, Xs) :- subtract_first(Xs0, Y, Cmp, Xs).

subtract_first([], _, _, []).
subtract_first([X|Xs], Y, Cmp, Rs) :-
        (   ord_call(Cmp, X, Y, =) -> Rs = Xs
        ;   Rs = [X|Rest],
            subtract_first(Xs, Y, Cmp, Rest)
        ).

mul(Cmp, Ms, Ns, Ord) :-
        multiset_diff(Cmp, Ns, Ms, NMs),
        multiset_diff(Cmp, Ms, Ns, MNs),
        (   NMs == [], MNs == [] -> Ord = (=)
        ;   forall(member(N, NMs),
                   (   member(M, MNs), ord_call(Cmp, M, N, >))) -> Ord = (>)
        ;   Ord = (<)
        ).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Recursive path order with status.

   Stats is a list of pairs [f-mul, g-lex] etc.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

rpo(Fs, Stats, S, T, Ord) :-
        (   var(T) ->
            (   S == T -> Ord = (=)
            ;   term_variables(S, Vs), member(V, Vs), V == T -> Ord = (>)
            ;   Ord = (<)
            )
        ;   var(S) -> Ord = (<)
        ;   S =.. [F|Ss], T =.. [G|Ts],
            (   forall(member(Si, Ss), rpo(Fs, Stats, Si, T, <)) ->
                ord(Fs, F, G, Ord0),
                (   Ord0 == (>) ->
                    (   forall(member(Ti, Ts), rpo(Fs, Stats, S, Ti, >)) ->
                        Ord = (>)
                    ;   Ord = (<)
                    )
                ;   Ord0 == (=) ->
                    (   forall(member(Ti, Ts), rpo(Fs, Stats, S, Ti, >)) ->
                        memberchk(F-Stat, Stats),
                        ord_call(Stat, rpo(Fs, Stats), Ss, Ts, Ord)
                    ;   Ord = (<)
                    )
                ;   Ord0 == (<) -> Ord = (<)
                )
            ;   Ord = (>)
            )
        ).

% explicit meta-call to detect safety in SWISH
% ord_call/[4,5] can be replaced by call/[4,5] when SWISH improves.

ord_call(ord(Fs), X, Y, Ord) :- ord(Fs, X, Y, Ord).
ord_call(rpo(Fs,Stats), X, Y, Ord) :- rpo(Fs, Stats, X, Y, Ord).

ord_call(lex, Cmp, X, Y, Ord) :- lex(Cmp, X, Y, Ord).
ord_call(mul, Cmp, X, Y, Ord) :- mul(Cmp, X, Y, Ord).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Huet / Knuth-Bendix Completion
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

%?- term_size(f(g(X),y), T).

term_size(T, S) :-
        (   var(T) -> S = 1
        ;   T =.. [_|Args],
            foldl(terms_size, Args, 0, S0),
            S #= S0 + 1
        ).

terms_size(T, S0, S) :-
        term_size(T, TS),
        S #= S0 + TS.

smallest_rule_first(Rs0, Rs) :-
        maplist(term_size, Rs0, Sizes0),
        pairs_keys_values(Pairs0, Sizes0, Rs0),
        keysort(Pairs0, Pairs),
        pairs_keys_values(Pairs, _, Rs).

%?- smallest_rule_first([f(g(X)) ==> c, f(X) ==> b], Rs).

add_rule(Rule, Es0, Ss0, Rs0, Es, [Rule|Ss], Rs) :-
        append([Rule|Rs0], Ss0, Rules),
        simpler(Ss0, Rule, Rules, Es0, [], Es1, Ss),
        simpler(Rs0, Rule, Rules, Es1, [], Es, Rs).

simpler([], _, _, Es, Us, Es, Us).
simpler([G0==>D0|Rs], Rule, Rules, Es0, Us0, Es, Us) :-
        normal_form([Rule], G0, G),
        (   G0 == G ->
            normal_form(Rules, D0, D),
            simpler(Rs, Rule, Rules, Es0, [G==>D|Us0], Es, Us)
        ;   simpler(Rs, Rule, Rules, [G=D0|Es0], Us0, Es, Us)
        ).

orient([], Ss, Rs, _, Ss, Rs).
orient([S0=T0|Es0], Ss0, Rs0, Cmp, Ss, Rs) :-
        append(Rs0, Ss0, Rules),
        normal_form(Rules, S0, S),
        normal_form(Rules, T0, T),
        (   S == T -> orient(Es0, Ss0, Rs0, Cmp, Ss, Rs)
        ;   ord_call(Cmp, S, T, >) ->
            add_rule(S ==> T, Es0, Ss0, Rs0, Es1, Ss1, Rs1),
            orient(Es1, Ss1, Rs1, Cmp, Ss, Rs)
        ;   ord_call(Cmp, T, S, >) ->
            add_rule(T ==> S, Es0, Ss0, Rs0, Es1, Ss1, Rs1),
            orient(Es1, Ss1, Rs1, Cmp, Ss, Rs)
        ;   false /* rule cannot be oriented */
        ).

completion(Es0, Ss0, Rs0, Cmp, Rs) :-
        orient(Es0, Ss0, Rs0, Cmp, Ss1, Rs1),
        (   Ss1 == [] -> Rs = Rs1
        ;   smallest_rule_first(Ss1, [R|Rules]),
            phrase((critical_pairs_([R], Rs1),
                    critical_pairs_(Rs1, [R]),
                    critical_pairs_([R], [R])), CPs),
            completion(CPs, Rules, [R|Rs1], Cmp, Rs)
        ).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Try to find a suitable order to create a convergent TRS from
   a list of equations.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

equations_trs(Es, Rs) :-
        equations_order(Es, Cmp),
        equations_trs(Cmp, Es, Rs).

equations_trs(Cmp, Es, Rs) :-
        completion(Es, [], [], Cmp, Rs).

equations_order(Es, rpo(Sorted,Stats)) :-
        equations_functors(Es, Fs),
        pairs_keys_values(Stats, Fs, Values),
        maplist(ord_status, Values),
        permutation(Fs, Sorted).

ord_status(lex).
ord_status(mul).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Functors occurring in given equations.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

equations_functors(Eqs, Fs) :-
        phrase(eqs_functors_(Eqs), Fs0),
        sort(Fs0, Fs).

eqs_functors_([]) --> [].
eqs_functors_([A=B|Es]) -->
        term_functors(A),
        term_functors(B),
        eqs_functors_(Es).

term_functors(Var) --> { var(Var) }, !.
term_functors(T) -->
        { T =.. [F|Args] },
        [F],
        functors_(Args).

functors_([]) --> [].
functors_([T|Ts]) -->
        term_functors(T),
        functors_(Ts).

%?- group(Gs), equations_functors(Gs, Fs).

%?- group(Gs), equations_trs(Gs, Rs).

%?- group(Gs), permutation([*,e,i], Ord), equations_trs(rpo(Ord, [(*)-lex,e-lex,i-lex]), Gs, Rs), maplist(writeln, Rs).
%?- group(Gs), equations_trs(rpo([*,e,i],[(*)-lex,e-lex,i-lex]), Gs, Rs), maplist(writeln, Rs).

%?- group(Gs), equations_trs(rpo([e,*,i],[(*)-lex,e-lex,i-lex]), Gs, Rs), maplist(writeln, Rs), length(Rs, L).

%?- group(Gs), equations_trs(rpo([*,i,e],[(*)-lex,e-lex,i-lex]), Gs, Rs), maplist(writeln, Rs), length(Rs, L).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Testing
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

rules(1, [f(f(X)) ==> g(X)]).

rules(2, [f(f(X)) ==> f(X),
          g(g(X)) ==> f(X)]).

c(CPs) :-
        rules(_, Rules),
        critical_pairs(Rules, CPs).

group([e*X = X,
       i(X)*X = e,
       A*(B*C) = (A*B)*C]).

orient(A=B, A==>B).

%?- critical_pairs([f(X)*Y*Z==>X*Y*Z], Ps).

%?- critical_pairs([i(X) ==> e, A*B*C ==> (A*B)*C], Ps).

%?- critical_pairs([A*B*C ==> (A*B)*C], Ps).

%?- critical_pairs([A*B*D ==> A*B], Ps).

%?- group(Gs0), maplist(orient, Gs0, Gs), critical_pairs(Gs, Ps), maplist(writeln, Ps), length(Ps, L).

%?- critical_pairs([f(f(X)) ==> a, f(f(X))==>b], Ps).
%?- c(CPs).
%@ CPs = [g(_G9)-g(_G9), g(f(_G22))-f(g(_G22))] ;
%@ CPs = [f(_G41)-f(_G41), f(f(_G57))-f(f(_G57)), f(_G71)-f(_G71), f(g(_G95))-g(f(_G95))].

%?- critical_pairs([f(X,a) ==> X, a ==> b], Ps).

%?- rules(1, Rs), critical_pairs(Rs, Ps).

%?- critical_pairs([f(X,f(X)) ==> a, f(Y,Y) ==> b], Ps).

/** <Examples>

?- group(Gs), equations_trs(Gs, Rs).

?- group(Gs), equations_order(Gs, Cmp), equations_trs(Cmp, Gs, Rs).

?- Es = [X*X = X^2, (X+Y)^2 = X^2 + 2*X*Y + Y^2],
   equations_order(Es, Cmp),
   call_with_inference_limit(equations_trs(Cmp, Es, Rs), 10_000, !).
*/
