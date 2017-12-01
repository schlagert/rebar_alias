-module(rebar_alias).

-export([init/1]).

-define(PROVIDER, rebar_alias).
-define(DEPS, []).

%% ===================================================================
%% Public API
%% ===================================================================
-spec init(rebar_state:t()) -> {ok, rebar_state:t()}.
init(State) ->
    Aliases = rebar_state:get(State, alias, []),
    lists:foldl(fun({Alias, Cmds}, {ok, StateAcc}) ->
                        init_alias(Alias, Cmds, StateAcc)
                end, {ok, State}, Aliases).

init_alias(Alias, Cmds, State) ->
    Module = list_to_atom("rebar_prv_alias_" ++ atom_to_list(Alias)),

    MF = module(Module),
    EF = exports(),
    FF = do_func(Cmds),

    {ok, _, Bin} = compile:forms([MF, EF, FF]),
    code:load_binary(Module, "none", Bin),

    Provider = providers:create([
            {name, Alias},
            {module, Module},
            {bare, true},
            {deps, []},
            {example, example(Alias)},
            {opts, []},
            {short_desc, desc(Cmds)},
            {desc, desc(Cmds)}
    ]),
    {ok, rebar_state:add_provider(State, Provider)}.

example(Alias) ->
    "rebar3 " ++ atom_to_list(Alias).

desc(Cmds) ->
    "Equivalent to running: rebar3 do "
        ++ rebar_string:join(lists:map(fun to_desc/1, Cmds), ",").

to_desc({Cmd, Args}) ->
    atom_to_list(Cmd) ++ " " ++ Args;
to_desc(Cmd) ->
    atom_to_list(Cmd).

module(Name) ->
    {attribute, 1, module, Name}.

exports() ->
    {attribute, 1, export, [{do, 1}]}.

do_func(Cmds) ->
    {function, 1, do, 1,
     [{clause, 1,
       [{var, 1, 'State'}],
       [],
       [{call, 1,
         {remote, 1, {atom, 1, rebar_prv_do}, {atom, 1, do_tasks}},
         [make_args(Cmds), {var, 1, 'State'}]}]}]}.

make_args(Cmds) ->
    make_list(
      lists:map(fun make_tuple/1,
                lists:map(fun make_arg/1, Cmds))).

make_arg({Cmd, Args}) ->
    {make_string(Cmd), make_list([make_string(A) || A <- split_args(Args)])};
make_arg(Cmd) ->
    {make_string(Cmd), make_list([])}.

make_tuple(Tuple) ->
    {tuple, 1, tuple_to_list(Tuple)}.

make_list(List) ->
    lists:foldr(
      fun(Elem, Acc) -> {cons, 1, Elem, Acc} end,
      {nil, 1},
      List).

make_string(Atom) when is_atom(Atom) ->
    make_string(atom_to_list(Atom));
make_string(String) when is_list(String) ->
    {string, 1, String}.

split_args(Args) ->
    rebar_string:lexemes(
      lists:map(fun($=) -> 32; (C) -> C end, Args),
      " ").
