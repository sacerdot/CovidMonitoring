-module(ospedale).
-export([start/0]).

start() ->
  io:format("Io sono l'ospedale~n",[]),
  Server = global:whereis_name(server),
  Server ! {ciao,da,ospedale}.
