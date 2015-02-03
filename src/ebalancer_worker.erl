-module(ebalancer_worker).

-behaviour(gen_server).

%% API
-export([start_link/0, receive_work/2]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {}).

%%%-----------------------------------------------------------------------------
%%% API functions
%%%-----------------------------------------------------------------------------

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

receive_work(VC, NFD) ->
    gen_server:cast(?MODULE, {receive_work, VC, NFD}).


%%%-----------------------------------------------------------------------------
%%% gen_server callbacks
%%%-----------------------------------------------------------------------------

init([]) ->
    {ok, #state{}}.

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast({receive_work, VC, {Node, From, Data}}, State) ->
    Processed = dummy_function(Data),
    ebalancer_collector:collect(VC, Node, From, Processed),
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


%%%-----------------------------------------------------------------------------
%%% Internal functions
%%%-----------------------------------------------------------------------------

dummy_function(Binary) ->
    re:split(Binary, " ", [{return, binary}]).