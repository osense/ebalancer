-module(ebalancer_app).
-author("osense").

-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).


%%%-----------------------------------------------------------------------------
%%% Application callbacks
%%%-----------------------------------------------------------------------------

start(_StartType, _StartArgs) ->
    ebalancer_balancer:start_link().

stop(_State) ->
    ok.
