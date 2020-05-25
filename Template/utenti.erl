-module(utenti).
-export([start/0]).

utente() ->
  io:format("Io sono l'utente ~p~n",[self()]),
  Server = global:whereis_name(server),
  Server ! {ciao,da,utente,self()}.

start() ->
  [ spawn(fun utente/0) || _ <- lists:seq(1,10) ].
