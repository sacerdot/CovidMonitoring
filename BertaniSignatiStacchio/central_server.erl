%%%-------------------------------------------------------------------
%%% @author Federico Bertani
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 01. May 2020 11:14
%%%-------------------------------------------------------------------
-module(central_server).
-author("Federico Bertani").

%% API
-export([run/0]).

run() ->
  % register central server name
  global:register_name/2(server,self()),
  PIDLIST = [],
  receive
    % a new place is registering
    {new_place,Place_pid} ->
      PIDLIST ++ [Place_pid];
    % user requested list of places
    {get_places, Pid} -> Pid ! {places, PIDLIST}
   end.
