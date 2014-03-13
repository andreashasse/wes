-module(wes_locker).

-behaviour(wes_lock).

%% API
-export([start/6]).

%% {via, , }  api.
-export([send/2,
         whereis_name/1,
         unregister_name/1,
         register_name/2]).

%% Actor stuff
-export([register_actor/3,
         actor_timeout/3,
         unregister_actor/3,
         channel_for_actor/1]).

%% Channel stuff
-export([channel_timeout/1]).

%% ---------------------------------------------------------------------------
%% User API

start(PrimaryNodes, Replicas, W, LeaseExpireInterval, LockExpireInterval,
      PushTransInterval) ->
    Locker = {wes_locker,
              {locker, start_link,
               [W, LeaseExpireInterval, LockExpireInterval,
                PushTransInterval]},
              permanent, 2000, worker, [locker]},
    {ok, _} = supervisor:start_child(wes_sup, Locker),
    ok = locker:set_nodes(PrimaryNodes, PrimaryNodes, Replicas).

%% ---------------------------------------------------------------------------
%% Lib callback

send(Id, Event) ->
    case locker:dirty_read({channel, Id}) of
        {ok, Pid} ->
            Pid ! Event;
        {error, not_found} ->
            exit({badarg, {Id, Event}})
    end.

whereis_name(Id) ->
    case locker:dirty_read({channel, Id}) of
        {ok, Pid} ->
            Pid;
        {error, not_found} ->
            undefined
    end.

unregister_name(Id) ->
    %% Assumed called from user process.
    {ok, _, _, _} = locker:release({channel, Id}, self()),
    ok.

register_name(Id, Pid) ->
    case locker:lock({channel, Id}, Pid, locker_lease_duration()) of
        {ok, _, _, _} ->
            yes;
        {error, no_quorum} ->
            no
    end.

locker_lease_duration() ->
    1000 * 60 * 5. %% FIXME config.

locker_renew_duration() ->
    1000 * 60 * 2. %% FIXME config.

register_actor(Id, ChannelType, ChannelName) ->
    case locker:lock({actor, Id}, {ChannelType, ChannelName},
                     locker_lease_duration()) of
        {ok, _, _, _} ->
            {ok, [{{lock, ChannelType, ChannelName}, locker_renew_duration()}]};
        {error, no_quorum} ->
            {error, no_quorum}
    end.

unregister_actor(Id, ChannelType, ChannelName) ->
    {ok, _, _, _} = locker:release({actor, Id}, {ChannelType, ChannelName}),
    ok.

channel_for_actor(Id) ->
    case locker:dirty_read({actor, Id}) of
        {ok, {ChannelType, ChannelName}} ->
            {ChannelType, ChannelName};
        {error, not_found} ->
            undefined
    end.

actor_timeout(Name, ChannelType, ChannelName) ->
    locker:extend_lease({actor, Name}, {ChannelType, ChannelName},
                        locker_lease_duration()).

channel_timeout(Channel) ->
    locker:extend_lease(Channel, self(), locker_lease_duration()).
