%%%-------------------------------------------------------------------
%%% @author Federico Bertani
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 01. May 2020 11:11
%%%-------------------------------------------------------------------
-module(hospital).
-author("Federico Bertani").

%% API
-export([run/0]).

run() ->
  io:format("hospital started pid=~p ~n",[self()]),
  global:register_name(hospital,self()),
  io:format("hospital registered~n"),
  receive
    % an user want to be tested
    {test_me, PID} ->
      io:format("process ~p want to be tested ~n",[PID]),
      % answer with probability 25% to be positive
      case (rand:uniform(4)==1) of
        true ->
          PID ! positive;
        false ->
          PID ! negative
      end,
      run()
  end.
