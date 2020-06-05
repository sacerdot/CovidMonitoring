%%%-------------------------------------------------------------------
%%% @author Federico Bertani, Teresa Signati
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 15. mag 2020 11:44
%%%-------------------------------------------------------------------
-module(launchL).

-export([launch/0]).

launch () ->
  compile:file(server),
  compile:file(ospedale),
  compile:file(luoghi),
  compile:file(utenti),
  spawn(fun()->os:cmd('xterm -hold -e "erl -sname server -s server start"') end),
  spawn(fun()->os:cmd('xterm -hold -e "erl -sname ospedale -s ospedale start"') end),
  spawn(fun()->os:cmd('xterm -hold -e "erl -sname luoghi -s luoghi start"') end),
  spawn(fun()->os:cmd('xterm -hold -e "erl -sname luoghi2 -s luoghi start"') end),
  spawn(fun()->os:cmd('xterm -hold -e "erl -sname luoghi3 -s luoghi start"') end),
  spawn(fun()->os:cmd('xterm -hold -e "erl -sname utenti -s utenti start"') end),
  spawn(fun()->os:cmd('xterm -hold -e "erl -sname utenti2 -s utenti start"') end).


