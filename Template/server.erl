-module(server).
-export([start/0]).

start() ->
  global:register_name(server,self()),
  io:format("Io sono il server~n",[]),
  receive
    M -> io:format("Messaggio ricevuto: ~p~n",[M])
  end,
  start().
