-module(wes_SUITE).

-export([suite/0,
         init_per_suite/1,
         end_per_suite/1,
         init_per_group/2,
         end_per_group/2,
         init_per_testcase/2,
         end_per_testcase/2,
         groups/0,
         all/0]).

-export([test_ets/0, test_ets/1,
         test_stop/0, test_stop/1,
         test_counters/0, test_counters/1,
         test_add_actor/0, test_add_actor/1,
         test_start_running_actor/0, test_start_running_actor/1,
         test_lock_restart/0, test_lock_restart/1,
         test_bad_command/0, test_bad_command/1,
         test_two_actors/0, test_two_actors/1,
         test_same_actor_twice/0, test_same_actor_twice/1,
         test_message_timeout/0, test_message_timeout/1,
         test_not_message_timeout/0, test_not_message_timeout/1,
         test_ensure_actor/0, test_ensure_actor/1,
         test_stop_actor/0, test_stop_actor/1,
         test_no_channel/0, test_no_channel/1
        ]).

-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").

%%--------------------------------------------------------------------
%% @spec suite() -> Info
%% Info = [tuple()]
%% @end
%%--------------------------------------------------------------------
suite() ->
    [{timetrap,{seconds,30}}].

%%--------------------------------------------------------------------
%% @spec init_per_suite(Config0) ->
%%     Config1 | {skip,Reason} | {skip_and_save,Reason,Config1}
%% Config0 = Config1 = [tuple()]
%% Reason = term()
%% @end
%%--------------------------------------------------------------------
init_per_suite(Config) ->
    error_logger:tty(false),
    ok = application:set_env(wes, actors, [
        [
            {id, counter},
            {lock_mod, wes_lock_ets},
            {lock_conf, []},
            {cb_mod, wes_example_count},
            {db_mod, wes_db_ets},
            {db_conf, []}
        ],
        [
            {id, null_counter},
            {lock_mod, wes_lock_ets},
            {lock_conf, []},
            {cb_mod, wes_example_count},
            {db_mod, wes_db_null},
            {db_conf, []}
        ]
    ]),
    ok = application:set_env(wes, channels, [
        [
            {id, session},
            {lock_mod, wes_lock_ets},
            {lock_conf, []},
            {lock_timeout_interval, 1000},
            {message_timeout, 50000},
            {stats_mod, wes_stats_ets}
        ],
        [
            {id, message_timeout_session},
            {lock_mod, wes_lock_ets},
            {lock_conf, []},
            {lock_timeout_interval, 2000},
            {message_timeout, 750},
            {stats_mod, wes_stats_ets}
        ]
    ]),
    Config.

%%--------------------------------------------------------------------
%% @spec end_per_suite(Config0) -> void() | {save_config,Config1}
%% Config0 = Config1 = [tuple()]
%% @end
%%--------------------------------------------------------------------
end_per_suite(_Config) ->
    ok.

%%--------------------------------------------------------------------
%% @spec init_per_group(GroupName, Config0) ->
%%               Config1 | {skip,Reason} | {skip_and_save,Reason,Config1}
%% GroupName = atom()
%% Config0 = Config1 = [tuple()]
%% Reason = term()
%% @end
%%--------------------------------------------------------------------
init_per_group(_GroupName, Config) ->
    Config.

%%--------------------------------------------------------------------
%% @spec end_per_group(GroupName, Config0) ->
%%               void() | {save_config,Config1}
%% GroupName = atom()
%% Config0 = Config1 = [tuple()]
%% @end
%%--------------------------------------------------------------------
end_per_group(_GroupName, _Config) ->
    ok.

%%--------------------------------------------------------------------
%% @spec init_per_testcase(TestCase, Config0) ->
%%               Config1 | {skip,Reason} | {skip_and_save,Reason,Config1}
%% TestCase = atom()
%% Config0 = Config1 = [tuple()]
%% Reason = term()
%% @end
%%--------------------------------------------------------------------
init_per_testcase(_TestCase, Config) ->
    application:start(wes),
    wes_db_ets:start([]),
    wes_stats_ets:start_link(),
    {ok, _} = wes_lock_ets:start(1000),
    Config.

%%--------------------------------------------------------------------
%% @spec end_per_testcase(TestCase, Config0) ->
%%               void() | {save_config,Config1} | {fail,Reason}
%% TestCase = atom()
%% Config0 = Config1 = [tuple()]
%% Reason = term()
%% @end
%%--------------------------------------------------------------------
end_per_testcase(_TestCase, _Config) ->
    ok = application:stop(wes),
    catch wes_lock_ets:stop(),
    catch wes_stats_ets:stop(),
    catch wes_db_ets:stop([]),
    ok.

%%--------------------------------------------------------------------
%% @spec groups() -> [Group]
%% Group = {GroupName,Properties,GroupsAndTestCases}
%% GroupName = atom()
%% Properties = [parallel | sequence | Shuffle | {RepeatType,N}]
%% GroupsAndTestCases = [Group | {group,GroupName} | TestCase]
%% TestCase = atom()
%% Shuffle = shuffle | {shuffle,{integer(),integer(),integer()}}
%% RepeatType = repeat | repeat_until_all_ok | repeat_until_all_fail |
%%              repeat_until_any_ok | repeat_until_any_fail
%% N = integer() | forever
%% @end
%%--------------------------------------------------------------------
groups() ->
    [].

%%--------------------------------------------------------------------
%% @spec all() -> GroupsAndTestCases | {skip,Reason}
%% GroupsAndTestCases = [{group,GroupName} | TestCase]
%% GroupName = atom()
%% TestCase = atom()
%% Reason = term()
%% @end
%%--------------------------------------------------------------------
all() ->
    [test_counters,
     test_lock_restart,
     test_counters,
     test_ets,
     test_lock_restart,
     test_stop,
     test_bad_command,
     test_add_actor,
     test_two_actors,
     test_same_actor_twice,
     test_start_running_actor,
     test_message_timeout,
     test_not_message_timeout,
     test_ensure_actor,
     test_stop_actor,
     test_no_channel
    ].

test_counters() ->
    [].

test_counters(_Config) ->
    Channel = {session, test},
    Actor = {null_counter, one},
    Spec = {create, Actor, []},
    ?assertEqual([], wes_stats_ets:all_stats()),
    ?assertMatch({ok, _}, wes:create_channel(Channel, Spec)),
    ?assertEqual([{{start, actor}, 1},
                  {{start, channel}, 1}], wes_stats_ets:all_stats()),
    ?assertEqual(ok, wes:command(Channel, incr, [])),
    ?assertEqual([{{command, incr},1},
                  {{start, actor}, 1},
                  {{start, channel}, 1}], wes_stats_ets:all_stats()),
    ?assertEqual(1, wes:read(Actor, counter)),
    ?assertEqual([{{command, incr},1},
                  {{read, counter}, 1},
                  {{start, actor}, 1},
                  {{start, channel}, 1}], wes_stats_ets:all_stats()),
    ?assertEqual(ok, wes:stop_channel(Channel)),
    ?assertMatch({ok, _}, wes:create_channel(Channel, Spec)),
    ?assertEqual(0, wes:read(Actor, counter)),
    %% Test stats.
    ?assertEqual([{{command, incr},1},
                  {{read, counter}, 2},
                  {{start, actor}, 2},
                  {{start, channel}, 2},
                  {{stop, normal}, 1}], wes_stats_ets:all_stats()),
    ?assertEqual(ok, wes:stop_channel(Channel)).

test_lock_restart() -> [].

test_lock_restart(_Config) ->
    Channel = {session, hej2},
    Actor = {counter, act2},
    {ok, _} = wes:create_channel(Channel, [{create, Actor, []}]),
    ?assertEqual(ok, wes:command(Channel, incr, [])),
    ?assertEqual(1, wes:read(Actor, counter)),
    ?assertEqual(ok, wes:stop_channel(Channel)),
    {ok, _} = wes:create_channel(Channel, [{load, Actor, []}]),
    ?assertEqual(1, wes:read(Actor, counter)),
    ?assertEqual(ok, wes:stop_channel(Channel)).

test_ets() -> [].

test_ets(_Config) ->
    Channel = {session, hej3},
    Actor = {counter, act3},
    {ok, _} = wes:create_channel(Channel, [{create, Actor, []}]),
    ok = wes:command(Channel, incr, []),
    error_logger:error_msg("before sleep tab ~p",
                           [ets:tab2list(wes_lock_ets_srv)]),
    timer:sleep(1000),
    ?assertEqual(1, wes:read(Actor, counter)),
    ok = wes:stop_channel(Channel),
    {ok, _} = wes:create_channel(Channel, [{load, Actor, []}]),
    io:format("tab ~p", [ets:tab2list(wes_lock_ets_srv)]),
    ?assertEqual(1, wes:read(Actor, counter)),
    ?assertEqual(ok, wes:stop_channel(Channel)).

test_stop() -> [].

test_stop(_Config) ->
    Channel = {session, hej4},
    Actor = {counter, act4},
    Specs = [{create, Actor, []}],
    {ok, _Pid} = wes:create_channel(Channel, Specs),
    ok = wes:command(Channel, incr, []),
    ?assertEqual(1, wes:read(Actor, counter)),
    io:format("tab ~p", [ets:tab2list(wes_lock_ets_srv)]),
    ?assertMatch({ok, _Pid}, wes:status(Channel)),
    %% This should generate a stop by the actor.
    ok = wes:command(Channel, incr, [0]),
    ?assertMatch({error, not_found}, wes:status(Channel)).

test_bad_command() -> [].

test_bad_command(_Config) ->
    Channel = {session, hej4},
    Actor = {counter, act4},
    Specs = [{create, Actor, []}],
    {ok, _Pid} = wes:create_channel(Channel, Specs),
    ok = wes:command(Channel, incr, []),
    ?assertEqual({error, {negative_increment, -1}},
                 wes:command(Channel, incr, [-1])),
    ?assertMatch({error, not_found}, wes:status(Channel)).

test_two_actors() -> [].

test_two_actors(_Config) ->
    Channel = {session, session1},
    Actor1 = {counter, act1},
    Actor2 = {counter, act2},
    Specs = [{create, Actor1, []}, {create, Actor2, []}],
    {ok, _Pid} = wes:create_channel(Channel, Specs),
    ok = wes:command(Channel, incr, []),
    ?assertEqual(1, wes:read(Actor1, counter)),
    ?assertEqual(1, wes:read(Actor2, counter)),
    ?assertEqual(ok, wes:stop_channel(Channel)).

test_same_actor_twice() -> [].

test_same_actor_twice(_Config) ->
    Channel1 = {session, session1},
    Channel2 = {session, session2},
    Actor = {counter, act1},
    Specs = [{create, Actor, []}],
    {ok, _} = wes:create_channel(Channel1, Specs),
    ?assertMatch({error, _}, wes:create_channel(Channel2, Specs)),
    ?assertEqual(ok, wes:stop_channel(Channel1)),
    ?assertMatch({error, not_found}, wes:status(Channel2)).

test_start_running_actor() -> [].

test_start_running_actor(_Config) ->
    Channel1 = {session, session1},
    Channel2 = {session, session2},
    Actor = {counter, act1},
    Specs = [{create, Actor, []}],
    {ok, _} = wes:create_channel(Channel1, Specs),
    {ok, _} = wes:create_channel(Channel2, []),
    ?assertMatch(
       {error, {error_registering_actor,already_locked}},
       wes:create_actor(Channel2, {create, Actor, []})),
    ?assertEqual(ok, wes:stop_channel(Channel1)),
    ?assertMatch({error, not_found}, wes:status(Channel2)).

test_add_actor() -> [].

test_add_actor(_Config) ->
    Channel = {session, hej5},
    Actor = {counter, act5},
    {ok, _} = wes:create_channel(Channel, []),
    ok = wes:create_actor(Channel, {create, Actor, []}),
    ok = wes:command(Channel, incr, []),
    ?assertEqual(1, wes:read(Actor, counter)),
    ?assertEqual(ok, wes:stop_channel(Channel)).

test_message_timeout() -> [].

test_message_timeout(_Config) ->
    Channel = {message_timeout_session, hej6},
    Actor = {counter, act6},
    Specs = [{create, Actor, []}],
    {ok, Ref} = wes:create_channel(Channel, Specs),
    ok = wes:command(Channel, incr, []),
    error_logger:error_msg("before sleep tab ~p",
                           [ets:tab2list(wes_lock_ets_srv)]),
    ?assertMatch({ok, Ref}, wes:status(Channel)),
    timer:sleep(1000),
    ?assertMatch({error, not_found}, wes:status(Channel)).

test_not_message_timeout() ->  [].

test_not_message_timeout(_Config) ->
    Channel = {message_timeout_session, hej6},
    Actor = {counter, act6},
    Specs = [{create, Actor, []}],
    {ok, Ref} = wes:create_channel(Channel, Specs),
    ok = wes:command(Channel, incr, []),
    error_logger:error_msg("before sleep tab ~p",
                           [ets:tab2list(wes_lock_ets_srv)]),
    ?assertMatch({ok, Ref}, wes:status(Channel)),
    timer:sleep(600),
    ?assertEqual(1, wes:read(Actor, counter)),
    timer:sleep(600),
    ?assertMatch({ok, Ref}, wes:status(Channel)),
    ?assertEqual(ok, wes:stop_channel(Channel)).

test_ensure_actor() -> [].

test_ensure_actor(_Config) ->
    Channel = {session, hej7},
    Actor = {counter, act7},
    Specs = [{create, Actor, []}],
    {ok, _Pid} = wes:create_channel(Channel, []),
    ok = wes:create_actor(Channel, Specs),
    ok = wes:ensure_actor(Channel, Specs),
    ?assertEqual(0, wes:read(Actor, counter)),
    ?assertEqual(ok, wes:stop_channel(Channel)).

test_stop_actor() -> [].

test_stop_actor(_Config) ->
    Channel = {session, hej4},
    Actor = {counter, act4},
    Specs = [{create, Actor, []}],
    {ok, _Pid} = wes:create_channel(Channel, Specs),
    ?assertEqual(0, wes:read(Actor, counter)),
    ?assertEqual(ok, wes:command(Channel, incr, [100])),
    ?assertError(actor_not_active, wes:read(Actor, counter)),
    ?assertEqual(ok, wes:stop_channel(Channel)).

test_no_channel() -> [].

test_no_channel(_Config) ->
    ?assertError(channel_not_started,
                 wes:command({session, hej4}, incr, [100])).
