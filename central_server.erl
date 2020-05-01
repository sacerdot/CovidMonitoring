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
  io:format("central server started ~n"),
  % register central server name
  global:register_name/2(server,self()),
  io:format("registered server global name ~n"),
  % trapping exit signal from users
  process_flag(trap_exit, true),
  io:format("set flag to trap exit ~n"),
  PIDLIST = [],
  io:format("created list for PIDs ~n"),
  receive
    % a new place is registering
    {new_place,Place_pid} ->
      io:format("Place ~p want to register ~n",[Place_pid]),
      PIDLIST ++ [Place_pid];
    % user requested list of places
    {get_places, Pid} ->
      io:format("User ~p requested places list ~n",[Pid]),
      Pid ! {places, PIDLIST};
    % remove from places list dead place
    {'EXIT',FromPid,Reason} ->
      io:format("Place ~p is dead ~n",[FromPid]),
      PIDLIST = lists:delete(FromPid,PIDLIST)
   end.
