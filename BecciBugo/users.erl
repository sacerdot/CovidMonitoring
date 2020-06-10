-module(users).
-export([start/0]).

-define(NUSERS, 5).                % numero utenti
-define(NUSERPLACES, 3).            % numero posti mantenuti da ogni utente
-define(WAITVISIT, {3000, 5000}).   % attesa prima di visitare un luogo (range in ms)
-define(TIMEVISIT, {5000,10000}).   % durata della visita (range in ms)
-define(TIMETEST, 30000).           % attesa prima di farsi testare (ms)
-define(PROBTEST, 25).              % probabilita' di farsi testare (%)
-define(TIMEASKPLACES, 10000).      % attesa prima di richiedere nuovi posti (ms)


start() ->
    io:format("CIAO SONO IL GESTORE DEI USER~n"),
    [ spawn(fun users_init/0) || _ <- lists:seq(1,?NUSERS) ].


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

    %% parte user_loop
    get_places(PidUser, PidServer),
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
            case length(Places) < ?NUSERPLACES of
                true -> wake_ask_places(PidAskPlaces);
                false -> ok
            end,
            ChosenPlaces = choose_places(Places -- UPlaces, UPlaces, ?NUSERPLACES - length(UPlaces)),
            send_places_to_visit(PidVisit, ChosenPlaces),
            user_loop(ChosenPlaces, PidVisit, PidTester, PidAskPlaces, PidServer, PidHospital);

        {contact, PidUContact} ->
            link(PidUContact),
            user_loop(UPlaces, PidVisit, PidTester, PidAskPlaces, PidServer, PidHospital);

        %% messaggi di gestione morte attori

        {'DOWN', _ , process, PidPlace, _} -> % un luogo che stavamo monitorando muore, quindi ne chiediamo un altro
            get_places(self(), PidServer),
            user_loop(UPlaces -- [PidPlace], PidVisit, PidTester, PidAskPlaces, PidServer, PidHospital);

        {'EXIT', _ , Reason} when Reason =:= positive; Reason =:= quarantena->
            io:format("Entro in quarantena ~p~n",[self()]),
            exit(quarantena);

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

        {'EXIT', _ , Reason} when Reason =/= normal ->
            io:format("L'utente sta per morire per ragione ~p~n", [Reason]),
            exit(Reason); %nel caso in cui qualcuno a cui siamo linkati termini per un'altra ragione, anche noi terminiamo con la stessa reason

        _ -> user_loop(UPlaces, PidVisit, PidTester, PidAskPlaces, PidServer, PidHospital)

    end.

%%% ATTORI AUSILIARI

%% Attore gestione visita

visit(PidUser, []) -> receive {place_list, ChosenPlaces} -> visit(PidUser, ChosenPlaces) end;
visit(PidUser, ListPlaces) ->
    receive {place_list, ChosenPlaces} -> visit(PidUser, ChosenPlaces) after 0 -> ok end, %se è cambiata la lista dei posti dell'utente, la riceviamo e ci richiamiamo con la nuova lista
    util:sleep(util:rand_in_range(?WAITVISIT)),
    Ref = make_ref(),
    PidPlaceToVisit = util:rand_in_list(ListPlaces),
    in_place(PidPlaceToVisit, PidUser, Ref),
    visit(PidUser, ListPlaces).

%% Attore che richiede il test all'ospedale

get_tested(PidUser, PidHospital) ->
    util:sleep(?TIMETEST),
    case util:probability(?PROBTEST) of
        true -> PidHospital ! {test_me, PidUser};
        false -> ok
    end,
    get_tested(PidUser, PidHospital).


%% Attore che chiede altri posti in caso l'utente mantiene < 3 posti

ask_more_places(PidUser, PidServer) ->
    receive
        ask_more_places ->
            util:sleep(?TIMEASKPLACES),
            get_places(PidUser, PidServer),
            ask_more_places(PidUser, PidServer)
    end.


%%% FUNZIONI DI COMUNICAZIONE

%% chiediamo i luoghi al server
get_places(PidUser, PidServer) ->
    PidServer ! {get_places, PidUser}.

%% svegliamo ask more places
wake_ask_places(PidAskPlaces) ->
    PidAskPlaces ! ask_more_places.

% mandiamo all'attore vist la nuova lista dei posti
send_places_to_visit(PidVisit, ChosenPlaces) ->
    PidVisit ! {place_list, ChosenPlaces}.

%% iniziamo e terminiamo la visita dell'utente PidUser nel luogo PidPlaceToVisit
in_place(PidPlaceToVisit, PidUser, Ref) ->
    PidPlaceToVisit ! {begin_visit, PidUser, Ref},
    receive
        {'EXIT', _ , Reason} ->
            PidPlaceToVisit ! {end_visit, PidUser, Ref}, %se moriamo durante la visita, prima di morire, usciamo dalla visita
            exit(Reason)
    after util:rand_in_range(?TIMEVISIT) -> ok end,
    PidPlaceToVisit ! {end_visit, PidUser, Ref}.



%%% FUNZIONI AUSILIARIE

%% choose_places(ListPlaces, ReturnPlaces, N) -> sceglie N posti da ListPlaces e li aggiunge alla lisata ReturnPlaces, ritornandola
choose_places([], ReturnPlaces, _) -> ReturnPlaces;
choose_places(_, ReturnPlaces, N) when N =< 0 -> ReturnPlaces;
choose_places(ListPlaces, ReturnPlaces, N) ->
    Choice = util:rand_in_list(ListPlaces),
    monitor(process, Choice),
    choose_places(ListPlaces -- [Choice], [Choice|ReturnPlaces], N - 1).
