%%%-------------------------------------------------------------------
%%% @author Federico Bertani
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 15. mag 2020 11:44
%%%-------------------------------------------------------------------
-module(launchL).

-export([launch/0]).

launch () ->
  compile:file(central_server),
  compile:file(hospital),
  compile:file(place),
  compile:file(user),
  spawn(fun()->os:cmd('xterm -hold -e "erl -sname server -s central_server start"') end),
  spawn(fun()->os:cmd('xterm -hold -e "erl -sname hospital -s hospital start"') end),
  spawn(fun()->os:cmd('xterm -hold -e "erl -sname place -s place start"') end),
  spawn(fun()->os:cmd('xterm -hold -e "erl -sname place2 -s place start"') end),
  spawn(fun()->os:cmd('xterm -hold -e "erl -sname place3 -s place start"') end),
  spawn(fun()->os:cmd('xterm -hold -e "erl -sname user -s user start"') end).


