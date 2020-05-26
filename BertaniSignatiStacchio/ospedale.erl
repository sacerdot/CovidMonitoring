%%%-------------------------------------------------------------------
%%% @author Federico Bertani
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 01. May 2020 11:11
%%%-------------------------------------------------------------------
-module(ospedale).
-author("Federico Bertani").
%% API
-export([start/0,start_loop/0]).

start_loop()->
  receive
  % an user wants to be tested
    {test_me, PID} ->
      io:format("USER ~p WANTS TO BE TESTED ~n",[PID]),
      % answer with probability 25% to be positive
      case (rand:uniform(4)==1) of
        true ->
          PID ! positive;
        false ->
          PID ! negative
      end,
      start_loop()
  end.

start() ->
  io:format("Hospital started~n"),
  global:register_name(ospedale,self()),
  start_loop().
