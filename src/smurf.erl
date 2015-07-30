%%%-------------------------------------------------------------------
%%% @author Heinz Nikolaus Gies <heinz@licenser.net>
%%% @copyright (C) 2014, Heinz Nikolaus Gies
%%% @doc
%%% A Erlang wrapper around the solaris svcs and svcadm commands to
%%% help automating serivce tasks from within a erlang program.
%%% @end
%%% Created : 27 Jan 2014 by Heinz Nikolaus Gies <heinz@licenser.net>
%%%-------------------------------------------------------------------
-module(smurf).

-export([list/0, list/1,
         status/1, status/2,

         enable/1, enable/2,
         disable/1, disable/2,
         restart/1, restart/2,
         refresh/1, refresh/2,
         clear/1, clear/2,
         maintainance/1, maintainance/2,
         degrade/1, degrade/2,
         mark/3
        ]).

-define(SVCS, "/usr/bin/svcs").
-define(SVCADM, "/usr/sbin/svcadm").

-define(OPTS, [{line, 512}, binary, exit_status]).

-type service_state() :: {Servie::binary(), State::binary(), StartTime::binary()}.
-type service() :: binary() | string().
-type zone() :: binary() | string().
%%--------------------------------------------------------------------
%% @doc Lists all SMF services in the current zone.
%% @end
%%--------------------------------------------------------------------

-spec list() ->
                  {ok, [service_state()]} |
                  {error, N::pos_integer()}.

list() ->
    P = svcs(["-a", "-H"]),
    compile_list(P, []).


%%--------------------------------------------------------------------
%% @doc Lists all SMF services for a given zone.
%%
%% This must be executed from the solaris global zone.
%% @end
%%--------------------------------------------------------------------

-spec list(Zone::zone()) ->
                  {ok, [service_state()]} |
                  {error, N::pos_integer()}.
list(Zone) ->
    P = svcs(["-a", "-H", "-z", Zone]),
    compile_list(P, []).

%%--------------------------------------------------------------------
%% @doc Retrives the status of a single service.
%%
%% @end
%%--------------------------------------------------------------------

-spec status(Service::service()) ->
                    service_state() |
                    {error, disabigius} |
                    {error, N::pos_integer()}.
status(Service) ->
    P = svcs(["-H", Service]),
    case compile_list(P, []) of
        {ok, [E]} -> {ok, E};
        {ok, _} -> {error, disabigius};
        E -> E
    end.

%%--------------------------------------------------------------------
%% @doc Retrives the status of a single service.
%%
%% This must be executed from the solaris global zone.
%% @end
%%--------------------------------------------------------------------

-spec status(Zone::zone(), Service::service()) ->
                    service_state() |
                    {error, disabigius} |
                    {error, N::pos_integer()}.

status(Zone, Service) ->
    P = svcs(["-H", "-z", Zone, Service]),
    case compile_list(P, []) of
        {ok, [E]} -> {ok, E};
        {ok, _} -> {error, disabigius};
        E -> E
    end.

-spec enable(Service :: service()) -> ok | {error, N::pos_integer()}.
enable(Service) ->
    enable(Service, []).

-type svcs_opt() :: {zone, Zone::zone()}.
-type enable_opt() :: recursive | temporary | syncronous.
-type disable_opt() :: temporary | syncronous.
-type mark_opt() :: immediate | temporary.
-type arg() :: string() | binary().

-spec enable(Service :: service(),
             Opts :: [svcs_opt() | enable_opt()]) ->
                    ok | {error, N::pos_integer()}.
enable(Service, Opts) ->
    svcadm(svcadm_opts(Opts,["enable" | enable_opts(Opts, [Service])])).

-spec enable_opts([enable_opt() | term()], [arg()]) -> [arg()].

enable_opts([recursive | R] , Args) ->
    enable_opts(R, ["-r" | Args]);
enable_opts([temporary | R] , Args) ->
    enable_opts(R, ["-t" | Args]);
enable_opts([syncronous | R] , Args) ->
    enable_opts(R, ["-s" | Args]);
enable_opts([_ | R] , Args) ->
    enable_opts(R, Args);
enable_opts([] , Args) ->
    Args.


-spec disable(Service :: service()) -> ok | {error, N::pos_integer()}.
disable(Service) ->
    disable(Service, []).

-spec disable(Service :: service(),
              Opts :: [svcs_opt() | disable_opt()]) ->
                     ok | {error, N::pos_integer()}.
disable(Service, Opts) ->
    svcadm(svcadm_opts(Opts,["disable" | disable_opts(Opts, [Service])])).

-spec disable_opts([enable_opt() | term()], [arg()]) -> [arg()].

disable_opts([temporary | R] , Args) ->
    disable_opts(R, ["-t" | Args]);
disable_opts([syncronous | R] , Args) ->
    disable_opts(R, ["-s" | Args]);
disable_opts([_ | R] , Args) ->
    disable_opts(R, Args);
disable_opts([] , Args) ->
    Args.

-spec restart(Service :: service()) -> ok | {error, N::pos_integer()}.
restart(Service) ->
    restart(Service, []).

-spec restart(Service :: service(),
              Opts :: [svcs_opt()]) ->
                     ok | {error, N::pos_integer()}.
restart(Service, Opts) ->
    svcadm(svcadm_opts(Opts, ["restart", Service])).


-spec refresh(Service :: service()) -> ok | {error, N::pos_integer()}.
refresh(Service) ->
    refresh(Service, []).

-spec refresh(Service :: service(),
              Opts :: [svcs_opt()]) ->
                     ok | {error, N::pos_integer()}.
refresh(Service, Opts) ->
    svcadm(svcadm_opts(Opts, ["refresh", Service])).

-spec clear(Service :: service()) -> ok | {error, N::pos_integer()}.
clear(Service) ->
    clear(Service, []).

-spec clear(Service :: service(),
            Opts :: [svcs_opt()]) ->
                   ok | {error, N::pos_integer()}.
clear(Service, Opts) ->
    svcadm(svcadm_opts(Opts, ["clear", Service])).


-spec maintainance(Service :: service()) -> ok | {error, N::pos_integer()}.
maintainance(Srevice) ->
    maintainance(Srevice, []).

-spec maintainance(Service :: service(),
                   Opts :: [svcs_opt() | mark_opt()]) ->
                          ok | {error, N::pos_integer()}.
maintainance(Service, Opts) ->
    mark(Service, maintenance, Opts).

-spec degrade(Service :: service()) -> ok | {error, N::pos_integer()}.
degrade(Service) ->
    degrade(Service, []).
-spec degrade(Service :: service(),
              Opts :: [svcs_opt() | mark_opt()]) ->
                     ok | {error, N::pos_integer()}.
degrade(Service, Opts) ->
    mark(Service, degraded, Opts).

-spec mark(Service :: service(),
           State :: degraded | maintenance,
           Opts :: [svcs_opt() | mark_opt()]) ->
                  ok | {error, N::pos_integer()}.
mark(Service, degraded, Opts) ->
    degrade(svcadm_opts(Opts, ["mark" | mark_opts(Opts, ["degraded", Service])]));
mark(Service, maintenance, Opts) ->
    degrade(svcadm_opts(Opts, ["mark" | mark_opts(Opts, ["maintenance", Service])])).

-spec mark_opts([mark_opt() | term()], [arg()]) -> [arg()].

mark_opts([immediate | R] , Args) ->
    mark_opts(R, ["-I" | Args]);
mark_opts([temporary | R] , Args) ->
    mark_opts(R, ["-t" | Args]);
mark_opts([_ | R] , Args) ->
    mark_opts(R, Args);
mark_opts([] , Args) ->
    Args.

svcadm_opts([{zone, Zone} | R] , Args) ->
    svcadm_opts(R, ["-z", Zone | Args]);
svcadm_opts([_ | R] , Args) ->
    svcadm_opts(R,  Args);
svcadm_opts([] , Args) ->
    Args.

svcadm(Args) ->
    P = erlang:open_port({spawn_executable, ?SVCADM}, [{args, Args} | ?OPTS]),
    read_result(P).

svcs(Args) ->
    erlang:open_port({spawn_executable, ?SVCS}, [{args, Args} | ?OPTS]).

compile_list(P, L) ->
    receive
        {P, {data, {eol, E}}} ->
            [State, Date, Srv] = re:split(E, "\s+"),
            compile_list(P, [{Srv, State, Date}| L]);
        {P,{exit_status, 0}} -> {ok, L};
        {P,{exit_status, N}} -> {error, N}
    end.

read_result(P) ->
    receive
        {P, {data, _}} ->
            read_result(P);
        {P,{exit_status, 0}} -> ok;
        {P,{exit_status, N}} -> {error, N}
    end.
