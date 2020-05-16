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
-export([start/0, start_loop/1]).

start_loop(PLACES)->
  process_flag(trap_exit, true),
  io:format("set flag to trap exit ~n"),
  [link(PID) || PID <- PLACES],
  io:format("created list for PIDs ~n"),
  receive
  % remove from places list dead place
    {'EXIT',PID_EXIT,_} ->
      io:format("Place ~p is dead ~n",[PID_EXIT]),
      start_loop(PLACES--[PID_EXIT]);
  % a new place is registering
    {new_place,NEW_PID} ->
      io:format("Place ~p want to register ~n",[NEW_PID]),
      start_loop(PLACES ++ [NEW_PID]);
  % user requested list of places
    {get_places, PID_GETTER} ->
      io:format("User ~p requested places list ~n",[PID_GETTER]),
      PID_GETTER ! {places, PLACES},
      start_loop(PLACES)
  end.

start() ->
  io:format("central server started pid=~p ~n",[self()]),
  % register central server name
  global:register_name(server,self()),
  io:format("registered server global name ~n"),
  % trapping exit signal from users
  start_loop([]).
