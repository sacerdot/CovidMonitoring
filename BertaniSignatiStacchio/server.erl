%%%-------------------------------------------------------------------
%%% @author Federico Bertani
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 01. May 2020 11:14
%%%-------------------------------------------------------------------
-module(server).
-author("Federico Bertani").

%% API
-export([start/0, start_loop/1]).

sleep(N) -> receive after N -> ok end.

start_loop(PLACES)->
  sleep(1000),
  io:format("SERVER PLACES ~p~n",[PLACES]),
  process_flag(trap_exit, true),
  receive
  % remove from places list dead place
    {'DOWN', _, process, PID_EXIT, _} ->
      case lists:member(PID_EXIT,PLACES) of
        true-> io:format("DEATH OF PLACE ~p ~n",[PID_EXIT]),
          start_loop(PLACES--[PID_EXIT]);
        false-> ok
      end;
  % a new place is registering
    {new_place,NEW_PID} ->
      monitor(process, NEW_PID),
      io:format("NEW PLACE ~p REGISTRATION ~n",[NEW_PID]),
      start_loop(PLACES ++ [NEW_PID]);
  % user requested list of places
    {get_places, PID_GETTER} ->
      PID_GETTER ! {places, PLACES},
      start_loop(PLACES)
  end.

start() ->
  io:format("SERVER STARTED~n"),
  % register central server name
  global:register_name(server,self()),
  start_loop([]).
