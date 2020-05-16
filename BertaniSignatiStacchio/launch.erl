%%%-------------------------------------------------------------------
%%% @author Federico Bertani
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 15. mag 2020 11:44
%%%-------------------------------------------------------------------
-module(launch).

-export([launch/0]).

launch () ->
  compile:file(central_server),
  compile:file(hospital),
  compile:file(place),
  compile:file(user),
  spawn(central_server,start,[]),
  spawn(hospital,start,[]),
  spawn(place,start,[]),
  spawn(user,start,[]),
  receive {_} -> ko end.


%%  spawn(fun()->os:cmd('werl -name server -s central_server start') end),
%%  spawn(fun()->os:cmd('werl -name hospital -s hospital start') end),
%%  spawn(fun()->os:cmd('werl -name place -s place start') end),
%%  spawn(fun()->os:cmd('werl -name user -s user start') end).