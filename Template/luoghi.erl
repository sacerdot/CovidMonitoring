-module(luoghi).
-export([start/0]).

luogo() ->
  io:format("Io sono il luogo ~p~n",[self()]),
  Server = global:whereis_name(server),
  Server ! {ciao,da,luogo,self()}.

start() ->
  [ spawn(fun luogo/0) || _ <- lists:seq(1,10) ].
