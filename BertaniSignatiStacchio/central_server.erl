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

sleep(N) -> receive after N -> ok end.

start_loop(PLACES)->
  sleep(1000),
  io:format("Set flag to trap exit ~p~n",[PLACES]),
  process_flag(trap_exit, true),
  receive
  % remove from places list dead place
    {'DOWN', _, process, PID_EXIT, _} ->
      case lists:member(PID_EXIT,PLACES) of
        true-> io:format("Place ~p is dead ~n",[PID_EXIT]),
          start_loop(PLACES--[PID_EXIT]);
        false-> ok
      end;
  % a new place is registering
    {new_place,NEW_PID} ->
      monitor(process, NEW_PID),
      io:format("Place ~p want to register ~n",[NEW_PID]),
      start_loop(PLACES ++ [NEW_PID]);
  % user requested list of places
    {get_places, PID_GETTER} ->
      io:format("User ~p requested places list ~n",[PID_GETTER]),
      PID_GETTER ! {places, PLACES},
      start_loop(PLACES)
  end.

start() ->
  io:format("Central server started pid=~p ~n",[self()]),
  % register central server name
  global:register_name(server,self()),
  io:format("Registered server global name ~n"),
  % trapping exit signal from users
  start_loop([]).
