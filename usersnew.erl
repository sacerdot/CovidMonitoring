-module(usersnew).
-export([users_init/0, visit/2, getTested/1]).


users_init() ->
    process_flag(trap_exit, true),
	io:format("New User ~p~n",[self()]),
	link(global:whereis_name(server)),
    MyPid = self(),
    getPlaces(MyPid),
    PidVisit = spawn_link(fun() -> process_flag(trap_exit, true), visit(MyPid,[]) end),
%    PidVisit = spawn_link(?MODULE, visit, [MyPid, []]),
    PidTester = spawn_link(?MODULE, getTested, [MyPid]),
 	user([], PidVisit). %user(UPlaces, PidVisit)

user(UPlaces, PidVisit) ->
    %io:format("io ~p, ho luoghi ~p~n", [self(), UPlaces]),
    receive
        {places, Places} ->
            ChoosenPlaces = choosePlaces(Places -- UPlaces, UPlaces, 3 - length(UPlaces)),
            PidVisit ! {place_list, ChoosenPlaces},
            user(ChoosenPlaces, PidVisit);

        {contact, PidUContact} ->
            io:format("Io ~p sono in contatto con ~p~n", [self(), PidUContact]),
            link(PidUContact),
            user(UPlaces, PidVisit); 

        {test_result, Result} ->
            case Result of
                positive ->
                    io:format("Sono positivo (~p)~n", [self()]), %togliere stampa pid
                    exit(positive);
                negative ->
                    io:format("Sono negativo (~p)~n", [self()]), %togliere stampa pid
                    user(UPlaces, PidVisit)
            end;

        {'DOWN', _ , process, PidPlace, Reason } -> %{'DOWN', Reference, process, Pid, Reason} ->
            %io:format(" Il luogo ~p e' morto nell'utente  ~p con reason ~p~n", [PidPlace, self(), Reason]),
            getPlaces(self()),
            user(UPlaces -- [PidPlace], PidVisit);

        {'EXIT',Pid, Reason} -> %il trattino sarebbe Pid
            case Reason of
                positive -> io:format("I (~p) received positive form ~p, exit quarantena~n", [self(), Pid]),  exit(quarantena);
                quarantena -> io:format("I (~p) received quarantena form ~p, exit quarantena~n", [self(), Pid]), exit (quarantena);
                _ -> exit(Reason) %nel caso in cui qualuno a cui siamo linkati termini per un'altra ragione, anche noi terminiamo con la stessa reason
            end

    end.


visit(PidUser, []) -> receive {place_list, ChoosenPlaces} -> visit(PidUser, ChoosenPlaces) end;
visit(PidUser, ListPlaces) ->
    receive {place_list, ChoosenPlaces} ->
        %io:format("In ~p Nuovi luoghi mentre in visita: ~p~n", [PidUser, ChoosenPlaces]),
        visit(PidUser, ChoosenPlaces) 
    after util:rand_in_range(3000, 5000) -> ok end, %se arrivano i messaggi prima che io mi metto in attesa di riceverli, che succede?
    Ref = make_ref(),
    PidChoice = lists:nth(rand:uniform(length(ListPlaces)), ListPlaces),
    io:format("Io ~p inizio la visita in ~p~n", [PidUser, PidChoice]),
    PidChoice ! {begin_visit, PidUser, Ref},
    receive
        {'EXIT',Pid, Reason} ->
            PidChoice ! {end_visit, PidUser, Ref},
            io:format("Io ~p sono morto mentre stavo visitando. Pid exit ~p~n", [PidUser, Pid]),
            exit(Reason)
    after util:rand_in_range(5000,10000) -> 
        PidChoice ! {end_visit, PidUser, Ref},
        io:format("Io ~p termino la visita in ~p~n", [PidUser, PidChoice]),
        visit(PidUser, ListPlaces)
    end.

getTested(PidUser) ->
    util:sleep(30000),
    case util:probability(4) of
        true -> 
            HospitalPid = global:whereis_name(hospital),
            HospitalPid ! {test_me, PidUser};   
        false ->
            ok
    end,
    getTested(PidUser).


getPlaces(UserPid) ->
    PidServer = global:whereis_name(server),
    PidServer ! {get_places, UserPid}.

choosePlaces(_, ReturnPlaces, 0) -> ReturnPlaces;
choosePlaces([], ReturnPlaces, _) -> io:format("Non abbiamo 3 posti in lista~n"), ReturnPlaces;
choosePlaces(ListPlaces, ReturnPlaces, N) ->
    Choice = lists:nth(rand:uniform(length(ListPlaces)), ListPlaces),
    monitor(process, Choice),
    choosePlaces(ListPlaces -- [Choice], [Choice|ReturnPlaces], N - 1).
