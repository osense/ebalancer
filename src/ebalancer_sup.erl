-module(ebalancer_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

%% Helper macro for declaring children of supervisor
-define(CHILD(I, Type), {I, {I, start_link, []}, permanent, infinity, Type, [I]}).


%%%-----------------------------------------------------------------------------
%%% API functions
%%%-----------------------------------------------------------------------------

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%%%-----------------------------------------------------------------------------
%%% supervisor callbacks
%%%-----------------------------------------------------------------------------

init([]) ->
    {ok, {{one_for_one, 10, 5}, [
        ?CHILD(ebalancer_controller, worker),
        ?CHILD(ebalancer_collector, worker),
        ?CHILD(ebalancer_timer, worker)
    ]}}.
