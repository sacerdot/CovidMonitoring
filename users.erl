-module(users).
-export([start/0]).

start() ->
    io:format("CIAO SONO IL GESTORE DEI USER~n"),
    [ spawn(fun users_init/0) || _ <- lists:seq(1,10) ].


users_init() ->
    process_flag(trap_exit, true),

    PidUser = self(),
    PidHospital = global:whereis_name(hospital),
    PidServer = global:whereis_name(server),
	  link(PidServer),
    PidServer ! {ciao, da, utente, PidUser},

    %% spawn attori ausiliari
    PidVisit = spawn_link(fun() -> process_flag(trap_exit, true), visit(PidUser,[]) end),
    PidTester = spawn_link(fun () -> get_tested(PidUser, PidHospital) end),
    PidAskPlaces = spawn_link(fun() -> ask_more_places(PidUser, PidServer) end),

    PidServer ! {get_places, self()},
    user_loop([], PidVisit, PidTester, PidAskPlaces, PidServer, PidHospital).


user_loop(UPlaces, PidVisit, PidTester, PidAskPlaces, PidServer, PidHospital) ->
    receive

        %% messaggi dei protocolli

        positive ->
            io:format("Sono positivo (~p)~n", [self()]),
            exit(positive);

        negative ->
            io:format("Sono negativo (~p)~n", [self()]),
            user_loop(UPlaces, PidVisit, PidTester, PidAskPlaces, PidServer, PidHospital);

        {places, Places} ->
            case length(Places) < 3 of
                true -> PidAskPlaces ! {ask_more_places};
                false -> ok
            end,
            ChosenPlaces = choose_places(Places -- UPlaces, UPlaces, 3 - length(UPlaces)),
            PidVisit ! {place_list, ChosenPlaces},
            user_loop(ChosenPlaces, PidVisit, PidTester, PidAskPlaces, PidServer, PidHospital);

        {contact, PidUContact} ->
            link(PidUContact),
            user_loop(UPlaces, PidVisit, PidTester, PidAskPlaces, PidServer, PidHospital);

        %% messaggi di gestione morte attori

        {'DOWN', _ , process, PidPlace, _} -> % un luogo che stavamo monitorando muore, quindi ne chiediamo un altro
            PidServer ! {get_places, self()},
            user_loop(UPlaces -- [PidPlace], PidVisit, PidTester, PidAskPlaces, PidServer, PidHospital);

        {'EXIT', _ , Reason} when Reason =:= positive; Reason =:= quarantena->
            io:format("Entro in quarantena ~p~n",[self()]),
            exit(quarantena);

        %TODO : vedere a che serve questo, se no togli
        {'EXIT', Pid , normal} ->
            io:format("Exit normal di ~p~n", [Pid]),
            user_loop(UPlaces, PidVisit, PidTester, PidAskPlaces, PidServer, PidHospital);

        {'EXIT', PidVisit, _ } ->
            io:format("Morte irregolare di visit~n"),
            PidUser = self(),
            NewPidVisit = spawn_link(fun() -> process_flag(trap_exit, true), visit(PidUser, UPlaces) end),
            user_loop(UPlaces, NewPidVisit, PidTester, PidAskPlaces, PidServer, PidHospital);

        {'EXIT', PidTester, _ } ->
            io:format("Morte irregolare di get_tested~n"),
            PidUser = self(),
            NewPidTester = spawn_link(fun () -> get_tested(PidUser, PidHospital) end),
            user_loop(UPlaces, PidVisit, NewPidTester, PidAskPlaces, PidServer, PidHospital);

        {'EXIT', PidAskPlaces, _ } ->
            io:format("Morte irregolare di ask_more_places~n"),
            PidUser = self(),
            NewPidAskPlaces = spawn_link(fun() -> ask_more_places(PidUser, PidServer) end),
            user_loop(UPlaces, PidVisit, PidTester, NewPidAskPlaces, PidServer, PidHospital);

        {'EXIT', _ , Reason} ->
            io:format("L'utente sta per morire per ragione ~p~n", [Reason]),
            exit(Reason) %nel caso in cui qualuno a cui siamo linkati termini per un'altra ragione, anche noi terminiamo con la stessa reason
    end.

%%% ATTORI AUSILIARI

%% Attore gestione visita

visit(PidUser, []) -> receive {place_list, ChosenPlaces} -> visit(PidUser, ChosenPlaces) end;
visit(PidUser, ListPlaces) ->
    receive {place_list, ChosenPlaces} -> visit(PidUser, ChosenPlaces) after 0 -> ok end, %se è cambiata la lista dei posti dell'utente, la riceviamo e ci richiamiamo con la nuova lista
    util:sleep(util:rand_in_range(3000, 5000)),
    Ref = make_ref(),
    PidPlaceToVisit = util:rand_in_list(ListPlaces),
    PidPlaceToVisit ! {begin_visit, PidUser, Ref},
    receive
        {'EXIT', _ , Reason} ->
            PidPlaceToVisit ! {end_visit, PidUser, Ref}, %se moriamo durante la visita, prima di morire, usciamo dalla visita
            exit(Reason)
    after util:rand_in_range(5000,10000) -> ok end,
    PidPlaceToVisit ! {end_visit, PidUser, Ref},
    visit(PidUser, ListPlaces).


%% Attore che richiede il test all'ospedale

get_tested(PidUser, PidHospital) ->
    util:sleep(30000),
    case util:probability(25) of
        true -> PidHospital ! {test_me, PidUser};
        false -> ok
    end,
    get_tested(PidUser, PidHospital).


%% Attore che chiede altri posti in caso l'utente mantiene < 3 posti

ask_more_places(PidUser, PidServer) ->
    receive
    %TODO: cancella questo messaggio NOTA: vengono aggiunti in coda msg ask a ogni morte di luogo (se nascono nuovi luoghi facciamo un paio di giri in piu')
        {ask_more_places} ->
            util:sleep(10000),
            PidServer ! {get_places, PidUser},
            ask_more_places(PidUser, PidServer)
    end.


%%% FUNZIONI AUSILIARIE

%% choose_places(ListPlaces, ReturnPlaces, N) -> sceglie N posti da ListPlaces e li aggiunge alla lisata ReturnPlaces, ritornandola
choose_places([], ReturnPlaces, _) -> ReturnPlaces;
choose_places(_, ReturnPlaces, N) when N =< 0 -> ReturnPlaces;
choose_places(ListPlaces, ReturnPlaces, N) ->
    Choice = util:rand_in_list(ListPlaces),
    monitor(process, Choice),
    choose_places(ListPlaces -- [Choice], [Choice|ReturnPlaces], N - 1).
