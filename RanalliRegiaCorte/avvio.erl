-module(avvio).
-export([avvio/0, start/0]).

%Il file è stato creato per compilare e lanciare automaticamente tutti i nodi
%che saranno necessari per l'esecuzione dell'intero progetto.
avvio () ->
  compile:file(server),
  compile:file(ospedale),
  compile:file(luogo),
  compile:file(utente).
  
sleep(N)->
	receive
	after N->ok
	end.
  
start()->  
  spawn(fun()->os:cmd('werl -name server -s server') end),
  spawn(fun()->os:cmd('werl -name ospedale -s ospedale') end),
  sleep(5000),
  spawn(fun()->os:cmd('werl -name luoghi -s luogo') end),
  sleep(5000),
  spawn(fun()->os:cmd('werl -name utenti1 -s utente') end),
  spawn(fun()->os:cmd('werl -name utenti2 -s utente') end).
  
