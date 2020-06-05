%%%---------------------------------------------------------------------
%%% @doc Modulo server per il progetto del corso di Paradigmi emergenti.
%%% @end
%%%---------------------------------------------------------------------

-module(server).
-export([start/0]).

%%%-------------------------------------------------------------------
%%% @doc PROTOCOLLO DI INIZIALIZZAZIONE:
%%% all'avvio si registra globalmente.
%%% @end
%%%-------------------------------------------------------------------

start() ->
    global:register_name(server,self()),
    io:format("Io sono il server~n",[]),
    process_flag(trap_exit, true),
    update_places([]).

%%%----------------------------------------------------------------------------
%%% @doc PROTOCOLLO DI MANTENIMENTO DELLA TOPOLOGIA:
%%% 1) Mantiene una lista dei luoghi attivi.
%%% 2) Monitora i luoghi attivi, eliminandoli dalla lista quando questi muoiono
%%% 3) Risponde alle richieste (degli utenti) di conoscenza sui luoghi.
%%% @end
%%%----------------------------------------------------------------------------

update_places(PidList) ->
  receive
    {new_place, PidPlace} ->
      update_places([PidPlace | PidList]);

    {get_places, Pid} ->
      Pid ! {places, PidList},
      update_places(PidList);

    {'EXIT', Pid, normal} ->
      io:format("Sto per rimuovere ~p dalla lista dei luoghi~n", [Pid]),
      update_places(PidList -- [Pid]);

    {'EXIT', Pid, positive} ->
      io:format("~p: esce perche' positivo al test~n", [Pid]),
      update_places(PidList);

    {'EXIT', Pid, quarantena} ->
      io:format("~p: esce perche' va in quarantena~n", [Pid]),
      update_places(PidList);

    {'EXIT', Pid, Reason} ->
      io:format("~p exit because ~p~n", [Pid, Reason]),
      update_places(PidList -- [Pid]);

    Other ->
      io:format("Messaggio inaspettato: ~p~n", [Other]),
      update_places(PidList)
  end.
