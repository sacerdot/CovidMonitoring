%%%-------------------------------------------------------------------
%%% @author Lorenzo_Stacchio, Federico Bertani, Teresa Signati
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 01. May 2020 11:14
%%%-------------------------------------------------------------------
-module(server).
-author("Federico Bertani").

%% API
-export([start/0, server_loop/1]).

server_loop(PLACES)->
  timer:sleep(1000),
  io:format("SERVER PLACES ~p~n",[PLACES]),
  receive
  % remove from places list dead place
    {'EXIT',PLACE, _} ->
      case lists:member(PLACE,PLACES) of
        true->
          io:format("DEATH OF PLACE ~p ~n",[PLACE]),
          server_loop(PLACES--[PLACE]);
        false-> ok
      end;
  % a new place is registering
    {new_place,P} ->
      io:format("NEW PLACE ~p ~n",[P]),
      server_loop(PLACES ++ [P]);
  % user requested list of places
    {get_places, PID_GETTER} ->
      PID_GETTER ! {places, PLACES},
      server_loop(PLACES)
  end.

start() ->
  io:format("SERVER STARTED~n"),
  % register central server name
  global:register_name(server,self()),
  process_flag(trap_exit, true),
  server_loop([]).
