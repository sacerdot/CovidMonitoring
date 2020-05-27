%%%-------------------------------------------------------------------
%%% @doc Modulo utenti per il progetto del corso di Paradigmi emergenti.
%%% @end
%%%-------------------------------------------------------------------

-module(utenti).
-export([start/0]).

-record(status,{visiting = -1,
		visitor_pid = -1,
		visiting_ref = -1,
    place_pid = -1,
		places = []}).

start() ->
  [ spawn(fun utente/0) || _ <- lists:seq(1,30) ].

utente() ->
  io:format("Ciao io sono l'utente ~p~n", [self()]),
  Status = #status{ visiting = -1,
                    places = []},
  Server = global:whereis_name(server),
  erlang:link(Server),
  process_flag(trap_exit, true),
  Manager = self(),
  erlang:spawn_link(fun() -> do_test(Manager) end),
  Pid_observer = erlang:spawn_link(fun() -> place_observer(Manager, []) end),
  erlang:spawn_link(fun() -> place_manager(Manager, Pid_observer) end),
  erlang:spawn_link(fun() ->perform_visit(Manager) end),
  loop(Status, Server).

%%--------------------------------------------------------------------
%% @doc Il loop principale mantiene lo status dell'utente, distribuisce
%% informazioni agli altri attori (ad esempio all'attore che fa visite),
%% ed effettua la exit se qualcuno degli utenti a cui e' linkato muore.
%% @end
%%--------------------------------------------------------------------
loop(Status, Server) ->
  receive
    {debug, Message} ->
      debug(Message),
      loop(Status, Server);

    {update_status, Pid} ->
      Pid ! {status, Status},
      receive
        {status_updated, NewStatus} -> loop(NewStatus, Server)
      end;

    {ask_status, Pid} ->
      Pid ! {status, Status},
      loop(Status, Server);

    {'EXIT', _, positive} ->
      io:format("~p: Entro in quarantena~n", [self()]),
      perform_exit(Status, quarantena);

    {'EXIT', _, quarantena} ->
      io:format("~p: Entro in quarantena~n", [self()]),
      perform_exit(Status, quarantena);

    {'EXIT', Server, _} ->
      io:format("Server crash~n"),
      exit(server_crash);
    Other ->
      io:format("Messaggio inaspettato: ~p~n", [Other]),
      loop(Status, Server)
  end.


%%--------------------------------------------------------------------
%% @doc Il place manager ogni 10 secondi controlla che l'utente
%% abbia almeno 3 luoghi da visitare, in caso positivo si rimette
%% a dormire, in caso negativo chiede al server dei luoghi
%% e ne aggiunge di nuovi se disponibili.
%% @end
%%--------------------------------------------------------------------
place_manager(Manager, Pid_observer) ->
  Manager ! {ask_status, self()},
  Status = receive {status, RStatus} -> RStatus end,
  Places = Status#status.places,
  Manager ! {debug, {places_list, Places}},
  case length(Places) < 3 of
    false -> ok;
    true ->
      global:send(server, {get_places, self()}),
      AllPlaces = receive {places, Pidlist} -> Pidlist end,
      NewPlaces = erlang:subtract(AllPlaces, Places),
      PlacesUpdated = sample(3 - length(Places), NewPlaces),
      [ Pid_observer ! {start_monitor, Place_pid} || Place_pid <- PlacesUpdated],
      update_status(Manager, {update_places, PlacesUpdated ++ Places})
  end,
  sleep(2),
  place_manager(Manager, Pid_observer).

%%--------------------------------------------------------------------
%% @doc Il place manager monitora i luoghi che l'utente ha nella lista,
%% in caso di morte di uno di questi provvede a rimuoverlo.
%% @end
%%--------------------------------------------------------------------
place_observer(Manager, Places) ->
  receive
    {start_monitor, NewPlace } ->
      monitor(process, NewPlace),
      place_observer(Manager, Places ++ [NewPlace]);
    {'DOWN', _, process, Pid, normal} ->
      NewPlaces = Places -- [Pid],
      update_status(Manager, {update_places, NewPlaces}),
      place_observer(Manager, NewPlaces)
  end.

%%--------------------------------------------------------------------
%% @doc do_test ogni 30 secondi con probabilita' 1/4 esegue il test,
%% se il test risulta positivo viene eseguita una exit, se una visita
%% e' in corso questa viene terminata
%% @end
%%--------------------------------------------------------------------
do_test(Manager) ->
  case rand:uniform(4) of
    1 ->
      Manager ! {debug, yes_test},
      global:send(hospital, {test_me, self()}),
      receive
        positive ->
          Manager ! {debug, positive_test},
          check_and_exit(Manager, positive);
        negative ->
          Manager ! {debug, negative_test}
      end;
    _ ->
      Manager ! {debug, no_test}
  end,
  sleep(10),
  do_test(Manager).

%%--------------------------------------------------------------------
%% @doc perform_visit richiede la lista dei posti al manager principale,
%% se almeno un posto e' presente viene effettuata la visita
%% @end
%%--------------------------------------------------------------------
perform_visit(Manager) ->
  Manager ! {ask_status, self()},
  Status = receive {status, RStatus} -> RStatus end,
  Places = Status#status.places,

  case length(Places) > 0 of
    false ->
      Manager ! {debug, no_places};
    true ->
      [Place | _] = sample(1, Places),
      Ref = erlang:make_ref(),
      Manager ! {debug, begin_visit},
      Place ! {begin_visit, self(), Ref},
      update_status(Manager, {update_visit, self(), Ref, 1, Place}),
      VisitTime = rand:uniform(5) + 5,
      PlaceManager = self(),
      spawn_link(fun() -> reminder(PlaceManager, VisitTime) end),
      receive_contact(Manager),
      update_status(Manager, {update_visit, -1, -1, -1, -1}),
      Manager ! {debug, end_visit},
      Place ! {end_visit, self(), Ref}
  end,
  sleep_random(3,5),
  perform_visit(Manager).

%%--------------------------------------------------------------------
%% @doc Viene richiesto al manager principale lo status dell'utente
%% e poi viene performata la exit.
%% @end
%%--------------------------------------------------------------------
check_and_exit(Manager, Reason) ->
  Manager ! {ask_status, self()},
  receive
    {status, Status}  ->
      perform_exit(Status, Reason)
  end.

%%--------------------------------------------------------------------
%% @doc Effettua la exit, se l'utente sta effettuando una visita
%% questa viene prima terminata
%% @end
%%--------------------------------------------------------------------
perform_exit(Status, Reason) when Status#status.visiting /= -1 ->
  Luogo = Status#status.place_pid,
  Luogo ! {end_visit, Status#status.visitor_pid, Status#status.visiting_ref},
  exit(Reason);
perform_exit(_, Reason) ->
  exit(Reason).

%%--------------------------------------------------------------------
%% @doc Il reminder manda un messaggio al manager della visita
%% notificandogli che la visita e' terminata
%% @end
%%--------------------------------------------------------------------
reminder(Pid, VisitTime) ->
  receive after VisitTime*1000 -> Pid ! done_visit end.

%%--------------------------------------------------------------------
%% @doc Aggiorna lo status dell'utente in due possibili modi:
%% - viene aggiornata la lista dei posti disponibili
%% - viene aggioranto lo status di visita dell'utente
%% @end
%%--------------------------------------------------------------------
update_status(Manager, Update) ->
  Manager ! {update_status, self()},
  Status = receive {status, RStatus} -> RStatus end,
  NewStatus = case Update of
                {update_places, Places} ->
                  Status#status{places = Places};
                {update_visit, Pid, Ref, Visiting, Place} ->
                  Status#status{visiting = Visiting, visitor_pid = Pid, visiting_ref = Ref, place_pid = Place};
                Other ->
                  io:format("Tupla non prevista: ~p~n", [Other]),
                  Status
              end,

  Manager ! {status_updated, NewStatus}.

%%--------------------------------------------------------------------
%% @doc receive_contact si occupa di ricevere il contatto da parte di
%% altri utenti durante la visita di un luogo, il reminder si occupa
%% di terminare la visita
%% @end
%%--------------------------------------------------------------------
receive_contact(Manager) ->
  receive
    {contact, Pid} ->
      link(Pid),
      Manager ! {debug, {received_contact, Pid}},
      receive_contact(Manager);
    done_visit -> ok
  end.

  %---------------- UTILS ----------------%

debug({places_list, Places}) -> io:format("~p: Lista dei luoghi = ~p~n", [self(), Places]);
debug(no_places) -> io:format("~p: Non ci sono posti da visitare, dormo.~n", [self()]);
debug(begin_visit) -> io:format("~p: Sto per iniziare una visita ~n", [self()]);
debug(end_visit) -> io:format("~p: Sto per concludere una visita~n", [self()]);
debug(negative_test) -> io:format("~p: Sono negativo.~n", [self()]);
debug(positive_test) -> io:format("~p: Sono positivo.~n", [self()]);
debug({received_contact, Pid}) -> io:format("~p: Ricevuto contatto da ~p~n", [self(), Pid]);
debug(no_test) -> io:format("~p: Non mi sono testato~n", [self()]);
debug(yes_test) -> io:format("~p: Mi sto per testare, incrociamo le dita~n", [self()]).

%%--------------------------------------------------------------------
%% @doc Data una lista L restituisce N elementi casuali, se |L| <= N
%% restituisce L.
%% @end
%%--------------------------------------------------------------------
sample(N, L)->
  sample([], N, L).

sample(L,0,_) -> L;
sample(L,_,[]) -> L;
sample(L1, N, L2) ->
  X = case length(L2) of
        1 ->
          [_X | _] = L2,
          _X;
        Length ->
          lists:nth(rand:uniform(Length-1), L2)
      end,
  sample(L1 ++ [X], N-1, [Y || Y <- L2, Y/= X]).

%%--------------------------------------------------------------------
%% @doc Dorme per N secondi.
%% @end
%%--------------------------------------------------------------------
sleep(N) ->
  receive after N*1000 -> ok end.

%%--------------------------------------------------------------------
%% @doc Dorme per un numero random di secondi compreso tra I e S.
%% @end
%%--------------------------------------------------------------------
sleep_random(I, S) ->
  X = rand:uniform(S-I),
  sleep(I+X).
