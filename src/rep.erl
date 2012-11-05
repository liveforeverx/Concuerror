%%%----------------------------------------------------------------------
%%% Copyright (c) 2011, Alkis Gotovos <el3ctrologos@hotmail.com>,
%%%                     Maria Christakis <mchrista@softlab.ntua.gr>
%%%                 and Kostis Sagonas <kostis@cs.ntua.gr>.
%%% All rights reserved.
%%%
%%% This file is distributed under the Simplified BSD License.
%%% Details can be found in the LICENSE file.
%%%----------------------------------------------------------------------
%%% Authors     : Alkis Gotovos <el3ctrologos@hotmail.com>
%%%               Maria Christakis <mchrista@softlab.ntua.gr>
%%% Description : Replacement BIFs
%%%----------------------------------------------------------------------

-module(rep).

-export([rep_after_notify/0, rep_demonitor/1, rep_demonitor/2,
         rep_halt/0, rep_halt/1, rep_is_process_alive/1, rep_link/1,
         rep_monitor/2, rep_process_flag/2, rep_receive/2,
         rep_receive_block/0, rep_receive_notify/1,
         rep_receive_notify/2, rep_register/2, rep_send/2,
         rep_send/3, rep_spawn/1, rep_spawn/3, rep_spawn_link/1,
         rep_spawn_link/3, rep_spawn_monitor/1, rep_spawn_monitor/3,
         rep_spawn_opt/2, rep_spawn_opt/4, rep_unlink/1,
         rep_unregister/1, rep_whereis/1, rep_var/4]).

-export([rep_ets_insert_new/2, rep_ets_lookup/2, rep_ets_select_delete/2,
         rep_ets_insert/2, rep_ets_delete/1, rep_ets_delete/2,
         rep_ets_match_object/1, rep_ets_match_object/3,
         rep_ets_match_delete/2, rep_ets_new/2, rep_ets_foldl/3]).

-export([spawn_fun_wrapper/1]).

-export([rep_send_dpor/2]).

-export([rep_spawn_dpor/1, rep_spawn_dpor/3,
         rep_spawn_link_dpor/1, rep_spawn_link_dpor/3]).

-export([rep_link_dpor/1, rep_unlink_dpor/1,
         rep_spawn_monitor_dpor/1, rep_process_flag_dpor/2]).

-export([rep_receive_dpor/2, rep_receive_block_dpor/0,
         rep_after_notify_dpor/0, rep_receive_notify_dpor/3,
         rep_receive_notify_dpor/1]).

-export([rep_ets_insert_dpor/2, rep_ets_new_dpor/2, rep_ets_lookup_dpor/2,
         rep_ets_insert_new_dpor/2, rep_ets_delete_dpor/1]).

-export([rep_register_dpor/2,
         rep_is_process_alive_dpor/1,
         rep_unregister_dpor/1,
         rep_whereis_dpor/1]).

-include("gen.hrl").

%%%----------------------------------------------------------------------
%%% Definitions and Types
%%%----------------------------------------------------------------------

%% Return the calling process' LID.
-define(LID_FROM_PID(Pid), sched:lid_from_pid(Pid)).

%% The destination of a `send' operation.
-type dest() :: pid() | port() | atom() | {atom(), node()}.

%% Callback function mapping.
-define(INSTR_MOD_FUN,
        [{{erlang, demonitor, 1}, fun rep_demonitor/1,
          fun rep_demonitor_dpor/1},
         {{erlang, demonitor, 2}, fun rep_demonitor/2,
          fun rep_demonitor_dpor/2},
         {{erlang, halt, 0}, fun rep_halt/0},
         {{erlang, halt, 1}, fun rep_halt/1},
         {{erlang, is_process_alive, 1}, fun rep_is_process_alive/1,
          fun rep_is_process_alive_dpor/1},
         {{erlang, link, 1}, fun rep_link/1, fun rep_link_dpor/1},
         {{erlang, monitor, 2}, fun rep_monitor/2},
         {{erlang, process_flag, 2}, fun rep_process_flag/2},
         {{erlang, register, 2}, fun rep_register/2,
          fun rep_register_dpor/2},
         {{erlang, spawn, 1}, fun rep_spawn/1, fun rep_spawn_dpor/1},
         {{erlang, spawn, 3}, fun rep_spawn/3, fun rep_spawn_dpor/3},
         {{erlang, spawn_link, 1}, fun rep_spawn_link/1,
          fun rep_spawn_link_dpor/1},
         {{erlang, spawn_link, 3}, fun rep_spawn_link/3,
          fun rep_spawn_link_dpor/3},
         {{erlang, spawn_monitor, 1}, fun rep_spawn_monitor/1},
         {{erlang, spawn_monitor, 3}, fun rep_spawn_monitor/3},
         {{erlang, spawn_opt, 2}, fun rep_spawn_opt/2},
         {{erlang, spawn_opt, 4}, fun rep_spawn_opt/4},
         {{erlang, unlink, 1}, fun rep_unlink/1,
          fun rep_unlink_dpor/1},
         {{erlang, unregister, 1}, fun rep_unregister/1},
         {{erlang, whereis, 1}, fun rep_whereis/1},
         {{ets, insert_new, 2}, fun rep_ets_insert_new/2},
         {{ets, lookup, 2}, fun rep_ets_lookup/2},
         {{ets, select_delete, 2}, fun rep_ets_select_delete/2},
         {{ets, insert, 2}, fun rep_ets_insert/2},
         {{ets, delete, 1}, fun rep_ets_delete/1},
         {{ets, delete, 2}, fun rep_ets_delete/2},
         {{ets, match_object, 1}, fun rep_ets_match_object/1},
         {{ets, match_object, 3}, fun rep_ets_match_object/3},
         {{ets, match_delete, 2}, fun rep_ets_match_delete/2},
         {{ets, new, 2}, fun rep_ets_new/2},
         {{ets, foldl, 3}, fun rep_ets_foldl/3}]).

%%%----------------------------------------------------------------------
%%% Callbacks
%%%----------------------------------------------------------------------

%% Handle Mod:Fun(Args) calls.
-spec rep_var('default' | 'dpor', module(), atom(), [term()]) -> term().

rep_var(Version, Mod, Fun, Args) ->
    Key = {Mod, Fun, length(Args)},
    case lists:keyfind(Key, 1, ?INSTR_MOD_FUN) of
        {Key, Default} ->
            case Version of
                default ->
                    apply(Default, Args);
                dpor ->
                    log:internal("DPOR has no support for ~p yet.\n",[Key])
            end;
        {Key, Default, Dpor} ->
            case Version of
                default ->
                    apply(Default, Args);
                dpor ->
                    apply(Dpor, Args)
            end;
        false -> apply(Mod, Fun, Args)
    end.

%% @spec: rep_demonitor(reference()) -> 'true'
%% @doc: Replacement for `demonitor/1'.
%%
%% Just yield after demonitoring.
-spec rep_demonitor(reference()) -> 'true'.

rep_demonitor(Ref) ->
    Result = demonitor(Ref),
    sched:notify(demonitor, Ref),
    Result.

-spec rep_demonitor_dpor(reference()) -> 'true'.

rep_demonitor_dpor(Ref) ->
    sched:notify(demonitor, Ref),
    demonitor(Ref).

%% @spec: rep_demonitor(reference(), ['flush' | 'info']) -> 'true'
%% @doc: Replacement for `demonitor/2'.
%%
%% Just yield after demonitoring.
-spec rep_demonitor(reference(), ['flush' | 'info']) -> 'true'.

rep_demonitor(Ref, Opts) ->
    Result = demonitor(Ref, Opts),
    sched:notify(demonitor, Ref),
    Result.

-spec rep_demonitor_dpor(reference(), ['flush' | 'info']) -> 'true'.

rep_demonitor_dpor(Ref, Opts) ->
    sched:notify(demonitor, Ref),
    demonitor(Ref, Opts).

%% @spec: rep_halt() -> no_return()
%% @doc: Replacement for `halt/0'.
%%
%% Just send halt message and yield.
-spec rep_halt() -> no_return().

rep_halt() ->
    sched:notify(halt, empty).

%% @spec: rep_halt() -> no_return()
%% @doc: Replacement for `halt/1'.
%%
%% Just send halt message and yield.
-spec rep_halt(non_neg_integer() | string()) -> no_return().

rep_halt(Status) ->
    sched:notify(halt, Status).

%% @spec: rep_is_process_alive(pid()) -> boolean()
%% @doc: Replacement for `is_process_alive/1'.
-spec rep_is_process_alive(pid()) -> boolean().

rep_is_process_alive(Pid) ->
    Result = is_process_alive(Pid),
    sched:notify(is_process_alive, Pid),
    Result.

-spec rep_is_process_alive_dpor(pid()) -> boolean().

rep_is_process_alive_dpor(Pid) ->
    case ?LID_FROM_PID(Pid) of
        not_found -> ok;
        PLid -> sched:notify(is_process_alive, PLid)
    end,
    is_process_alive(Pid).

%% @spec: rep_link(pid() | port()) -> 'true'
%% @doc: Replacement for `link/1'.
%%
%% Just yield after linking.
-spec rep_link(pid() | port()) -> 'true'.

rep_link(Pid) ->
    Result = link(Pid),
    sched:notify(link, Pid),
    Result.

-spec rep_link_dpor(pid() | port()) -> 'true'.

rep_link_dpor(Pid) ->
    sched:notify(link, Pid),
    link(Pid).

%% @spec: rep_monitor('process', pid() | {atom(), node()} | atom()) ->
%%                           reference()
%% @doc: Replacement for `monitor/2'.
%%
%% Just yield after monitoring.
-spec rep_monitor('process', pid() | {atom(), node()} | atom()) ->
                         reference().

rep_monitor(Type, Item) ->
    Ref = monitor(Type, Item),
    NewItem = find_pid(Item),
    sched:notify(monitor, {NewItem, Ref}),
    Ref.

%% @spec: rep_process_flag('trap_exit', boolean()) -> boolean();
%%                        ('error_handler', atom()) -> atom();
%%                        ('min_heap_size', non_neg_integer()) ->
%%                                non_neg_integer();
%%                        ('min_bin_vheap_size', non_neg_integer()) ->
%%                                non_neg_integer();
%%                        ('priority', process_priority_level()) ->
%%                                process_priority_level();
%%                        ('save_calls', non_neg_integer()) ->
%%                                non_neg_integer();
%%                        ('sensitive', boolean()) -> boolean()
%% @doc: Replacement for `process_flag/2'.
%%
%% Just yield after altering the process flag.
-type process_priority_level() :: 'max' | 'high' | 'normal' | 'low'.
-spec rep_process_flag('trap_exit', boolean()) -> boolean();
                      ('error_handler', atom()) -> atom();
                      ('min_heap_size', non_neg_integer()) -> non_neg_integer();
                      ('min_bin_vheap_size', non_neg_integer()) ->
                              non_neg_integer();
                      ('priority', process_priority_level()) ->
                              process_priority_level();
                      ('save_calls', non_neg_integer()) -> non_neg_integer();
                      ('sensitive', boolean()) -> boolean().

rep_process_flag(trap_exit = Flag, Value) ->
    Result = process_flag(Flag, Value),
    sched:notify(process_flag, {Flag, Value}),
    Result;
rep_process_flag(Flag, Value) ->
    process_flag(Flag, Value).

rep_process_flag_dpor(Flag, Value) ->
    process_flag(Flag, Value).

%% @spec rep_receive(fun((function()) -> term())) -> term()
%% @doc: Function called right before a receive statement.
%%
%% If a matching message is found in the process' message queue, continue
%% to actual receive statement, else block and when unblocked do the same.
-spec rep_receive(fun((term()) -> 'block' | 'continue'), boolean()) -> 'ok'.

rep_receive(Fun, _HasTimeout) ->
    case ?LID_FROM_PID(self()) of
        not_found ->
            log:internal("Uninstrumented process enters instrumented receive");
        _Lid ->
            {messages, Mailbox} = process_info(self(), messages),
            case rep_receive_match(Fun, Mailbox) of
                block ->
                    sched:block(),
                    rep_receive_loop(Fun);
                continue -> ok
            end
    end.

rep_receive_loop(Fun) ->
    {messages, Mailbox} = process_info(self(), messages),
    case rep_receive_match(Fun, Mailbox) of
        block ->
            sched:no_wakeup(),
            rep_receive_loop(Fun);
        continue ->
            sched:wakeup()
    end.

%% Blocks forever (used for 'receive after infinity -> ...' expressions).
-spec rep_receive_block() -> no_return().

rep_receive_block() ->
    sched:block(),
    rep_receive_block_loop().

rep_receive_block_loop() ->
    sched:no_wakeup(),
    rep_receive_block_loop().

rep_receive_match(_Fun, []) ->
    block;
rep_receive_match(Fun, [H|T]) ->
    case Fun(H) of
        block -> rep_receive_match(Fun, T);
        continue -> continue
    end.

%% @spec rep_after_notify() -> 'ok'
%% @doc: Auxiliary function used in the `receive..after' statement
%% instrumentation.
%%
%% Called first thing after an `after' clause has been entered.
-spec rep_after_notify() -> 'ok'.

rep_after_notify() ->
    sched:notify('after', empty),
    ok.

%% @spec rep_receive_notify(pid(), term()) -> 'ok'
%% @doc: Auxiliary function used in the `receive' statement instrumentation.
%%
%% Called first thing after a message has been received, to inform the scheduler
%% about the message received and the sender.
-spec rep_receive_notify(pid(), term()) -> 'ok'.

rep_receive_notify(From, Msg) ->
    sched:notify('receive', {From, Msg}),
    ok.

%% @spec rep_receive_notify(term()) -> 'ok'
%% @doc: Auxiliary function used in the `receive' statement instrumentation.
%%
%% Similar to rep_receive/2, but used to handle 'EXIT' and 'DOWN' messages.
-spec rep_receive_notify(term()) -> 'ok'.

rep_receive_notify(Msg) ->
    sched:notify('receive_no_instr', Msg),
    ok.

%%------------------------------------------------------------------------------

-spec rep_receive_dpor(fun((term()) -> 'block' | 'continue'), boolean()) -> 'ok'.

rep_receive_dpor(Fun, HasTimeout) ->
    case ?LID_FROM_PID(self()) of
        not_found ->
            ok; %% log:internal("Uninstrumented process enters instrumented receive");
        _Lid ->
            rep_receive_loop_dpor(poll, Fun, HasTimeout)
    end.

rep_receive_loop_dpor(Act, Fun, HasTimeout) ->
    case Act of
        Resume when Resume =:= ok;
                    Resume =:= continue -> ok;
        poll ->
            {messages, Mailbox} = process_info(self(), messages),
            case rep_receive_match(Fun, Mailbox) of
                block ->
                    NewAct =
                        case HasTimeout of
                            false -> sched:notify('receive', blocked);
                            true ->
                                NewFun =
                                    fun(Msg) ->
                                        case rep_receive_match(Fun, [Msg]) of
                                            block -> false;
                                            continue -> true
                                        end
                                    end,
                                sched:notify('after', NewFun)
                        end,
                    rep_receive_loop_dpor(NewAct, Fun, HasTimeout);
                continue ->
                    Tag =
                        case HasTimeout of
                            false -> unblocked;
                            true -> had_after
                        end,
                    continue = sched:notify('receive', Tag),
                    ok
            end
    end.

-spec rep_receive_block_dpor() -> no_return().

rep_receive_block_dpor() ->
    Fun = fun(_Message) -> block end,
    rep_receive_dpor(Fun, true).

-spec rep_after_notify_dpor() -> 'ok'.

rep_after_notify_dpor() ->
    ok.

-spec rep_receive_notify_dpor(pid(), dict(), term()) -> 'ok'.

rep_receive_notify_dpor(From, CV, Msg) ->
    sched:notify('receive', {From, CV, Msg}, prev),
    ok.

-spec rep_receive_notify_dpor(term()) -> no_return().

rep_receive_notify_dpor(Msg) ->
    ok. %% log:internal("Received uninstrumented message: ~p\n", [Msg]).

%%------------------------------------------------------------------------------

%% @spec rep_register(atom(), pid() | port()) -> 'true'
%% @doc: Replacement for `register/2'.
%%
%% Just yield after registering.
-spec rep_register(atom(), pid() | port()) -> 'true'.

rep_register(RegName, P) ->
    Ret = register(RegName, P),
    %% TODO: Maybe send Pid instead to avoid rpc.
    PLid = ?LID_FROM_PID(P),
    sched:notify(register, {RegName, PLid}),
    Ret.

-spec rep_register_dpor(atom(), pid() | port()) -> 'true'.

%% Stub
rep_register_dpor(RegName, P) ->
    case ?LID_FROM_PID(P) of
        not_found -> ok;
        PLid ->
            sched:notify(register, {RegName, PLid})
    end,
    register(RegName, P).

%% @spec rep_send(dest(), term()) -> term()
%% @doc: Replacement for `send/2' (and the equivalent `!' operator).
%%
%% If the target has a registered LID then instrument the message
%% and yield after sending. Otherwise, send the original message
%% and continue without yielding.
-spec rep_send(dest(), term()) -> term().

rep_send(Dest, Msg) ->
    case ?LID_FROM_PID(self()) of
        not_found -> Dest ! Msg;
        SelfLid ->
            NewDest = find_pid(Dest),
            case ?LID_FROM_PID(NewDest) of
                not_found -> Dest ! Msg;
                _DestLid -> Dest ! {?INSTR_MSG, SelfLid, Msg}
            end,
            sched:notify(send, {NewDest, Msg}),
            Msg
    end.

-spec rep_send_dpor(dest(), term()) -> term().

rep_send_dpor(Dest, Msg) ->
    case ?LID_FROM_PID(self()) of
        not_found ->
            %% Unknown process sends using instrumented code. Allow it.
            %% It will be reported at the receive point.
            Dest ! Msg;
        _SelfLid ->
            NewDest = find_pid(Dest),
            NewLid = ?LID_FROM_PID(NewDest),
            sched:notify(send, {Dest, NewLid, Msg}),
            Dest ! Msg
    end.

%% @spec rep_send(dest(), term(), ['nosuspend' | 'noconnect']) ->
%%                      'ok' | 'nosuspend' | 'noconnect'
%% @doc: Replacement for `send/3'.
%%
%% For now, call erlang:send/3, but ignore options in internal handling.
-spec rep_send(dest(), term(), ['nosuspend' | 'noconnect']) ->
                      'ok' | 'nosuspend' | 'noconnect'.

rep_send(Dest, Msg, Opt) ->
    case ?LID_FROM_PID(self()) of
        not_found -> erlang:send(Dest, Msg, Opt);
        SelfLid ->
            NewDest = find_pid(Dest),
            case ?LID_FROM_PID(NewDest) of
                not_found -> erlang:send(Dest, Msg, Opt);
                _Lid ->
                    erlang:send(Dest,
                                {?INSTR_MSG, SelfLid, Msg}, Opt)
            end,
            sched:notify(send, {NewDest, Msg}),
            Msg
    end.

%% @spec rep_spawn(function()) -> pid()
%% @doc: Replacement for `spawn/1'.
%%
%% The argument provided is the argument of the original spawn call.
%% When spawned, the new process has to yield.
-spec rep_spawn(function()) -> pid().

rep_spawn(Fun) ->
    case ?LID_FROM_PID(self()) of
        not_found -> spawn(Fun);
        _Lid ->
            Pid = spawn(fun() -> sched:wait(), Fun() end),
            sched:notify(spawn, Pid),
            Pid
    end.

-spec rep_spawn_dpor(function()) -> pid().

rep_spawn_dpor(Fun) ->
    case ?LID_FROM_PID(self()) of
        not_found -> spawn(Fun);
        _Lid ->
            sched:notify(spawn, unknown),
            Pid = spawn(fun() -> spawn_fun_wrapper(Fun) end),
            sched:notify(spawned, Pid, prev),
            %% Wait before using the PID to be sure that an LID is assigned
            sched:wait(),
            Pid
    end.

-spec spawn_fun_wrapper(function()) -> term().

spawn_fun_wrapper(Fun) ->
    try
        sched:wait(),
        Fun(),
        exit(normal)
    catch
        exit:normal ->
            MyInfo = find_my_info(),
            sched:notify(exit, {normal, MyInfo});
        Class:Type ->
            sched:notify(error,[Class,Type,erlang:get_stacktrace()]),
            case Class of
                error -> error(Type);
                throw -> throw(Type);
                exit  -> exit(Type)
            end
    end.                    

find_my_info() ->
    MyEts = find_my_ets_tables(),
    MyName = find_my_registered_name(),
    {MyEts, MyName}.        

find_my_ets_tables() ->
    Self = self(),
    [?LID_FROM_PID(TID) ||
        TID <- ets:all(), Self =:= ets:info(TID, owner)].

find_my_registered_name() ->
    Self = self(),
    case process_info(Self, registered_name) of
        [] -> none;
        {registered_name, Name} -> {ok, Name}
    end.

%% @spec rep_spawn(atom(), atom(), [term()]) -> pid()
%% @doc: Replacement for `spawn/3'.
%%
%% See `rep_spawn/1'.
-spec rep_spawn(atom(), atom(), [term()]) -> pid().

rep_spawn(Module, Function, Args) ->
    Fun = fun() -> apply(Module, Function, Args) end,
    rep_spawn(Fun).

-spec rep_spawn_dpor(atom(), atom(), [term()]) -> pid().

rep_spawn_dpor(Module, Function, Args) ->
    Fun = fun() -> apply(Module, Function, Args) end,
    rep_spawn_dpor(Fun).

%% @spec rep_spawn_link(function()) -> pid()
%% @doc: Replacement for `spawn_link/1'.
%%
%% When spawned, the new process has to yield.
-spec rep_spawn_link(function()) -> pid().

rep_spawn_link(Fun) ->
    case ?LID_FROM_PID(self()) of
        not_found -> spawn_link(Fun);
        _Lid ->
            Pid = spawn_link(fun() -> sched:wait(), Fun() end),
            sched:notify(spawn_link, Pid),
            Pid
    end.

-spec rep_spawn_link_dpor(function()) -> pid().

rep_spawn_link_dpor(Fun) ->
    case ?LID_FROM_PID(self()) of
        not_found -> spawn(Fun);
        _Lid ->
            sched:notify(spawn_link, unknown),
            Pid = spawn_link(fun() -> spawn_fun_wrapper(Fun) end),
            sched:notify(spawned, Pid, prev),
            %% Wait before using the PID to be sure that an LID is assigned
            sched:wait(),
            Pid
    end.

%% @spec rep_spawn_link(atom(), atom(), [term()]) -> pid()
%% @doc: Replacement for `spawn_link/3'.
%%
%% See `rep_spawn_link/1'.
-spec rep_spawn_link(atom(), atom(), [term()]) -> pid().

rep_spawn_link(Module, Function, Args) ->
    Fun = fun() -> apply(Module, Function, Args) end,
    rep_spawn_link(Fun).

-spec rep_spawn_link_dpor(atom(), atom(), [term()]) -> pid().

rep_spawn_link_dpor(Module, Function, Args) ->
    Fun = fun() -> apply(Module, Function, Args) end,
    rep_spawn_link_dpor(Fun).

%% @spec rep_spawn_monitor(function()) -> {pid(), reference()}
%% @doc: Replacement for `spawn_monitor/1'.
%%
%% When spawned, the new process has to yield.
-spec rep_spawn_monitor(function()) -> {pid(), reference()}.

rep_spawn_monitor(Fun) ->
    case ?LID_FROM_PID(self()) of
        not_found -> spawn_monitor(Fun);
        _Lid ->
            Ret = spawn_monitor(fun() -> sched:wait(), Fun() end),
            sched:notify(spawn_monitor, Ret),
            Ret
    end.

-spec rep_spawn_monitor_dpor(function()) -> {pid(), reference()}.

%% STUB
rep_spawn_monitor_dpor(Fun) ->
    spawn_monitor(Fun).

%% @spec rep_spawn_monitor(atom(), atom(), [term()]) -> {pid(), reference()}
%% @doc: Replacement for `spawn_monitor/3'.
%%
%% See rep_spawn_monitor/1.
-spec rep_spawn_monitor(atom(), atom(), [term()]) -> {pid(), reference()}.

rep_spawn_monitor(Module, Function, Args) ->
    Fun = fun() -> apply(Module, Function, Args) end,
    rep_spawn_monitor(Fun).

%% @spec rep_spawn_opt(function(),
%%       ['link' | 'monitor' |
%%                   {'priority', process_priority_level()} |
%%        {'fullsweep_after', integer()} |
%%        {'min_heap_size', integer()} |
%%        {'min_bin_vheap_size', integer()}]) ->
%%       pid() | {pid(), reference()}
%% @doc: Replacement for `spawn_opt/2'.
%%
%% When spawned, the new process has to yield.
-spec rep_spawn_opt(function(),
                    ['link' | 'monitor' |
                     {'priority', process_priority_level()} |
                     {'fullsweep_after', integer()} |
                     {'min_heap_size', integer()} |
                     {'min_bin_vheap_size', integer()}]) ->
                           pid() | {pid(), reference()}.

rep_spawn_opt(Fun, Opt) ->
    case ?LID_FROM_PID(self()) of
        not_found -> spawn_opt(Fun, Opt);
        _Lid ->
            Ret = spawn_opt(fun() -> sched:wait(), Fun() end, Opt),
            sched:notify(spawn_opt, {Ret, Opt}),
            Ret
    end.

%% @spec rep_spawn_opt(atom(), atom(), [term()],
%%       ['link' | 'monitor' |
%%                   {'priority', process_priority_level()} |
%%        {'fullsweep_after', integer()} |
%%        {'min_heap_size', integer()} |
%%        {'min_bin_vheap_size', integer()}]) ->
%%       pid() | {pid(), reference()}
%% @doc: Replacement for `spawn_opt/4'.
%%
%% When spawned, the new process has to yield.
-spec rep_spawn_opt(atom(), atom(), [term()],
                    ['link' | 'monitor' |
                     {'priority', process_priority_level()} |
                     {'fullsweep_after', integer()} |
                     {'min_heap_size', integer()} |
                     {'min_bin_vheap_size', integer()}]) ->
                           pid() | {pid(), reference()}.

rep_spawn_opt(Module, Function, Args, Opt) ->
    Fun = fun() -> apply(Module, Function, Args) end,
    rep_spawn_opt(Fun, Opt).

%% @spec: rep_unlink(pid() | port()) -> 'true'
%% @doc: Replacement for `unlink/1'.
%%
%% Just yield after unlinking.
-spec rep_unlink(pid() | port()) -> 'true'.

rep_unlink(Pid) ->
    Result = unlink(Pid),
    sched:notify(unlink, Pid),
    Result.

-spec rep_unlink_dpor(pid() | port()) -> 'true'.

rep_unlink_dpor(Pid) ->
    sched:notify(unlink, Pid),
    unlink(Pid).

%% @spec rep_unregister(atom()) -> 'true'
%% @doc: Replacement for `unregister/1'.
%%
%% Just yield after unregistering.
-spec rep_unregister(atom()) -> 'true'.

rep_unregister(RegName) ->
    Ret = unregister(RegName),
    sched:notify(unregister, RegName),
    Ret.

-spec rep_unregister_dpor(atom()) -> 'true'.

rep_unregister_dpor(RegName) ->
    sched:notify(unregister, RegName),
    unregister(RegName).

%% @spec rep_whereis(atom()) -> pid() | port() | 'undefined'
%% @doc: Replacement for `whereis/1'.
%%
%% Just yield after calling whereis/1.
-spec rep_whereis(atom()) -> pid() | port() | 'undefined'.

rep_whereis(RegName) ->
    Ret = whereis(RegName),
    sched:notify(whereis, {RegName, Ret}),
    Ret.

-spec rep_whereis_dpor(atom()) -> pid() | port() | 'undefined'.

rep_whereis_dpor(RegName) ->
    sched:notify(whereis, RegName),
    whereis(RegName).

%%%----------------------------------------------------------------------
%%% ETS replacements
%%%----------------------------------------------------------------------
%% FIXME: A lot of repeated code here.
rep_ets_insert_new(Tab, Obj) ->
    Ret = ets:insert_new(Tab, Obj),
    sched:notify(ets_insert_new, {Tab, Obj}),
    Ret.

rep_ets_lookup(Tab, Key) ->
    Ret = ets:lookup(Tab, Key),
    sched:notify(ets_lookup, {Tab, Key}),
    Ret.

rep_ets_select_delete(Tab, MatchSpec) ->
    Ret = ets:select_delete(Tab, MatchSpec),
    sched:notify(ets_select_delete, {Tab, MatchSpec}),
    Ret.

rep_ets_insert(Tab, Obj) ->
    Ret = ets:insert(Tab, Obj),
    sched:notify(ets_insert, {Tab, Obj}),
    Ret.

rep_ets_delete(Tab) ->
    Ret = ets:delete(Tab),
    sched:notify(ets_delete, Tab),
    Ret.

rep_ets_delete(Tab, Key) ->
    Ret = ets:delete(Tab, Key),
    sched:notify(ets_delete, {Tab, Key}),
    Ret.

rep_ets_match_object(Continuation) ->
    Ret = ets:match_object(Continuation),
    sched:notify(ets_match_object, {Continuation}),
    Ret.

rep_ets_match_object(Tab, Pattern, Limit) ->
    Ret = ets:match_object(Tab, Pattern, Limit),
    sched:notify(ets_match_object, {Tab, Pattern, Limit}),
    Ret.

rep_ets_match_delete(Tab, Pattern) ->
    Ret = ets:match_delete(Tab, Pattern),
    sched:notify(ets_match_delete, {Tab, Pattern}),
    Ret.

rep_ets_new(Name, Options) ->
    Ret = ets:new(Name, Options),
    sched:notify(ets_new, {Name, Options}),
    Ret.

rep_ets_foldl(Function, Acc0, Tab) ->
    Ret = ets:foldl(Function, Acc0, Tab),
    sched:notify(ets_foldl, {Function, Acc0, Tab}),
    Ret.

%%%----------------------------------------------------------------------
%%% ETS replacements DPOR
%%%----------------------------------------------------------------------

rep_ets_new_dpor(Name, Options) ->
    sched:notify(ets, {new, [unknown, Name, Options]}),
    Tid = ets:new(Name, Options),
    sched:notify(new_tid, Tid, prev),
    sched:wait(),
    Tid.

rep_ets_insert_dpor(Tab, Obj) ->
    sched:notify(ets, {insert, [?LID_FROM_PID(Tab), Tab, Obj]}),
    ets:insert(Tab, Obj).

rep_ets_insert_new_dpor(Tab, Obj) ->
    sched:notify(ets, {insert_new, [?LID_FROM_PID(Tab), Tab, Obj]}),
    ets:insert_new(Tab, Obj).

rep_ets_lookup_dpor(Tab, Key) ->
    sched:notify(ets, {lookup, [?LID_FROM_PID(Tab), Tab, Key]}),
    ets:lookup(Tab, Key).

rep_ets_delete_dpor(Tab) ->
    ets:delete(Tab).

%%%----------------------------------------------------------------------
%%% Helper functions
%%%----------------------------------------------------------------------

find_pid(Pid) when is_pid(Pid) ->
    Pid;
find_pid(Atom) when is_atom(Atom) ->
    whereis(Atom).
