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
  compile:file(server),
  compile:file(ospedale),
  compile:file(luoghi),
  compile:file(utenti),
  spawn(fun()->os:cmd('werl -name server -s server start') end),
  spawn(fun()->os:cmd('werl -name ospedale -s ospedale start') end),
  spawn(fun()->os:cmd('werl -name luoghi -s luoghi start') end),
  spawn(fun()->os:cmd('werl -name luoghi2 -s luoghi start') end),
  spawn(fun()->os:cmd('werl -name luoghi3 -s luoghi start') end),
  spawn(fun()->os:cmd('werl -name luoghi4 -s luoghi start') end),
  spawn(fun()->os:cmd('werl -name utenti -s utenti start') end),
  spawn(fun()->os:cmd('werl -name utenti2 -s utenti start') end).


