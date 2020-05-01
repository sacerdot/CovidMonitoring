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
  global:register_name(hospital,self()),
  receive
    % an user want to be tested
    {test_me, PID} ->
      % answer with probability 25% to be positive
      case (rand:uniform()=<0.25) of
        true -> PID ! positive;
        false -> PID ! negative
      end
  end.
