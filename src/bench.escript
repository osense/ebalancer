#!/usr/bin/env escript
%%! -pa ebin

%% Meant to be called from the parent directory.

-mode(compile).

-include("bench.hrl").

-define(TRIALS, 1000000).

main(_) ->
    test_increment(),
    test_increment_large(),
    test_merge_small(),
    test_compare_small(),
    test_merge_large(),
    test_compare_large().

make_vc(Size) ->
    NodeId = fun(Int) -> list_to_atom("vc" ++ integer_to_list(Int)) end,
    lists:foldl(fun(A, B) -> evc:merge(B, A, 0) end, evc:new(NodeId(Size div 2)), [evc:new(NodeId(X)) || X <- lists:seq(1, Size)]).

increment_all({List, Ts, Id}) ->
    {lists:map(fun ({Node, Cnt}) -> {Node, Cnt+1} end, List), Ts, Id}.


test_increment() ->
    VC = make_vc(4),
    bench("increment-small", fun() -> evc:increment(VC) end, ?TRIALS).

test_increment_large() ->
    VC = make_vc(10),
    bench("increment-large", fun() -> evc:increment(VC) end, ?TRIALS).

test_merge_small() ->
    VC1 = make_vc(4),
    VC2 = increment_all(VC1),
    bench("merge-small", fun() -> evc:merge(VC1, VC2, 0) end, ?TRIALS).

test_compare_small() ->
    VC1 = make_vc(4),
    VC2 = increment_all(VC1),
    bench("compare-small", fun() -> evc:compare(VC1, VC2) end, ?TRIALS).

 test_merge_large() ->
     VC1 = make_vc(10),
     VC2 = increment_all(VC1),
     bench("merge-large", fun() -> evc:merge(VC1, VC2, 0) end, ?TRIALS).

 test_compare_large() ->
     VC1 = make_vc(10),
     VC2 = increment_all(VC1),
     bench("compare-large", fun() -> evc:compare(VC1, VC2) end, ?TRIALS).
