-module(utenti).
-export([start/0, loop/1, do_test/1, perform_visit/1, reminder/2, place_manager/2, place_observer/2, sleep/1, sleep_random/2, sample/2]).

-record(status,{visiting = -1,
		visitor_pid = -1,
		visiting_ref = -1,
    place_pid = -1,
		places = []}).

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

check_and_exit(Manager, Reason) ->
    Manager ! {ask_status, self()},
    receive
        {status, Status}  ->
            perform_exit(Status, Reason)
    end.

perform_exit(Status, Reason) when Status#status.visiting /= -1 ->
    Luogo = Status#status.place_pid,
    Luogo ! {end_visit, Status#status.visitor_pid, Status#status.visiting_ref},
    exit(Reason);
perform_exit(_, Reason) ->
    exit(Reason).

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
            Visit_time = rand:uniform(5) + 5,
            spawn_link(?MODULE, reminder, [self(), Visit_time]),
            receive_contact(Manager),
            update_status(Manager, {update_visit, -1, -1, -1, -1}),
            Manager ! {debug, end_visit},
            Place ! {end_visit, self(), Ref}
    end,
    sleep_random(3,5),
    perform_visit(Manager).

reminder(Pid, Visit_time) ->
    receive after Visit_time*1000 -> Pid ! done_visit end.

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

receive_contact(Manager) ->
    receive
        {contact, Pid} ->
            link(Pid),
            Manager ! {debug, {received_contact, Pid}},
            receive_contact(Manager);
        done_visit -> ok
    end.

debug({places_list, Places}) -> io:format("~p: Lista dei luoghi = ~p~n", [self(), Places]);
debug(no_places) -> io:format("~p: Non ci sono posti da visitare, dormo.~n", [self()]);
debug(begin_visit) -> io:format("~p: Sto per iniziare una visita ~n", [self()]);
debug(end_visit) -> io:format("~p: Sto per concludere una visita~n", [self()]);
debug(negative_test) -> io:format("~p: Sono negativo.~n", [self()]);
debug(positive_test) -> io:format("~p: Sono positivo.~n", [self()]);
debug({received_contact, Pid}) -> io:format("~p: Ricevuto contatto da ~p~n", [self(), Pid]);
debug(no_test) -> io:format("~p: Non mi sono testato~n", [self()]);
debug(yes_test) -> io:format("~p: Mi sto per testare, incrociamo le dita~n", [self()]).

loop(Status) ->
    receive
        {debug, Message} ->
%            debug(Message),
            loop(Status);

        {update_status, Pid} ->
            Pid ! {status, Status},
            receive
                {status_updated, NewStatus} -> loop(NewStatus)
            end;

        {ask_status, Pid} ->
            Pid ! {status, Status},
            loop(Status);

        {'EXIT', _, positive} ->
            io:format("~p: Entro in quarantena~n", [self()]),
            perform_exit(Status, quarantena);

       {'EXIT', _, quarantena} ->
            io:format("~p: Entro in quarantena~n", [self()]),
            perform_exit(Status, quarantena);

        Other ->
            io:format("Messaggio inaspettato: ~p~n", [Other]),
            loop(Status)
    end.


utente() ->
    io:format("Ciao io sono l'utente ~p~n", [self()]),
    Status = #status{ visiting = -1,
                      places = []},

    Server = global:whereis_name(server),
    erlang:link(Server),

    erlang:spawn_link(?MODULE, do_test, [self()]),
    Pid_observer = erlang:spawn_link(?MODULE, place_observer, [self(), []]),
    erlang:spawn_link(?MODULE, place_manager, [self(), Pid_observer]),
    erlang:spawn_link(?MODULE, perform_visit, [self()]),
    loop(Status).


start() ->
    [ spawn(fun utente/0) || _ <- lists:seq(1,30) ].

%-------------- PROTOCOLS --------------%


%---------------- UTILS ----------------%

sample(N, L)->
    sample([], N, L).

sample(L,0,_) -> L;
sample(L,_,[]) -> L;
sample(L1, N, L2) ->
    %io:format("Lista = ~p~n", [L2]),
    X = case length(L2) of
            1 ->
                [_X | _] = L2,
                _X;
            Length ->
                lists:nth(rand:uniform(Length-1), L2)
        end,
    sample(L1 ++ [X], N-1, [Y || Y <- L2, Y/= X]).

sleep(N) ->
    receive after N*1000 -> ok end.

sleep_random(I, S) ->
    X = rand:uniform(S-I),
    sleep(I+X).
