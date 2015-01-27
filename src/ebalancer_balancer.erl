-module(ebalancer_balancer).

-behaviour(gen_server).

%% API
-export([start_link/0, receive_data/2, self_as_worker/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {balanced_nodes = 0,
    flush_timeout = 10000,
    buffer_size = 20,
    workers = queue:new(),
    counter = 0,
    buffer = []}).


%%%-----------------------------------------------------------------------------
%%% API functions
%%%-----------------------------------------------------------------------------

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

receive_data(From, Data) ->
    gen_server:cast(?MODULE, {receive_data, From, Data}).

%% Calling this offers the calling process as a worker to a locally registered balancer on a given node.
self_as_worker(NodeName) ->
    gen_server:cast({?MODULE, NodeName}, {register_worker, self()}).


%%%-----------------------------------------------------------------------------
%%% gen_server callbacks
%%%-----------------------------------------------------------------------------

init([]) ->
    {ok, #state{}}.


handle_call(_Request, _From, State) ->
    {reply, ok, State}.


handle_cast({receive_data, _From, Data}, State = #state{buffer = List, buffer_size = Limit}) when length(List) >= Limit - 1 ->
    NewState = dispatch(State#state{buffer = [Data | List]}),
    {noreply, NewState};
handle_cast({receive_data, _From, Data}, State = #state{buffer = List}) ->
    {noreply, State#state{buffer = [Data | List]}, State#state.flush_timeout};

handle_cast({register_worker, Pid}, State = #state{workers = Workers}) ->
    case queue_contains(Pid, Workers) of
        false ->
            error_logger:info_report([{"Balancer registered a new worker", Pid}]),
            {noreply, State#state{workers = queue:in(Pid, Workers)}, State#state.flush_timeout};
        true ->
            {noreply, State, State#state.flush_timeout}
    end.


handle_info(timeout, State) ->
    NewState = dispatch(State),
    {noreply, NewState};
%% discard messages caused by worker timeouts that were just late with the reply
handle_info({Ref, _}, State) when is_reference(Ref) ->
    {noreply, State}.


terminate(_Reason, _State) ->
    ok.


code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


%%%-----------------------------------------------------------------------------
%%% private functions
%%%-----------------------------------------------------------------------------

dispatch(State = #state{buffer = Buffer}) when length(Buffer) == 0 ->
    State;
dispatch(State) ->
    Counter = State#state.counter,
    case queue:out(State#state.workers) of
        {{value, Worker}, Q} ->
            try ebalancer_worker:receive_batch(Worker, {Counter, State#state.buffer}) of
                ok ->
                    State#state{buffer = [], workers = queue:in(Worker, Q), counter = Counter + 1}
            catch
                exit:{Reason, _Stack} ->
                    error_logger:info_report([{"Balancer dropping worker", Worker}, {"Reason", Reason}]),
                    dispatch(State#state{workers = Q})
            end;
        {empty, _Q} ->
            error_logger:warning_report(["Balancer has no registered workers, buffering input",
                {"Buffer size", length(State#state.buffer)}]),
            State
    end.

queue_contains(Term, Q) ->
    lists:any(fun(X) -> X =:= Term end, queue:to_list(Q)).