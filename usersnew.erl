-module(usersnew).
-export([users_init/0, visit/2]).

users_init() ->
	io:format("New User ~p~n",[self()]),
	link(global:whereis_name(server)),
    MyPid = self(),
    getPlaces(MyPid),
    PidVisit = spawn_link(?MODULE, visit, [MyPid, []]),
 	user([], PidVisit). %user(UPlaces, PidVisit)

user(UPlaces, PidVisit) ->
    io:format("io ~p, ho luoghi ~p~n", [self(), UPlaces]),
    receive
        {places, Places} ->
            ChoosenPlaces = choosePlaces(Places -- UPlaces, UPlaces, 3 - length(UPlaces)),
            PidVisit ! {place_list, ChoosenPlaces},
            user(ChoosenPlaces, PidVisit);

        {'DOWN', _ , process, PidPlace, Reason } -> %{'DOWN', Reference, process, Pid, Reason} ->
                io:format(" Il luogo ~p e' morto nell'utente  ~p ~n", [PidPlace, self()]),
                getPlaces(self()),
                user(UPlaces -- [PidPlace], PidVisit)
    end.


visit(PidUser, []) -> receive {place_list, ChoosenPlaces} -> visit(PidUser, ChoosenPlaces) end;
visit(PidUser, ListPlaces) ->
    receive {place_list, ChoosenPlaces} ->
        io:format("In ~p Nuovi luoghi mentre in visita: ~p~n", [PidUser, ChoosenPlaces]),
        visit(PidUser, ChoosenPlaces) after util:rand_in_range(3000, 5000) -> ok end, %se arrivano i messaggi prima che io mi metto in attesa di riceverli, che succede?
    Ref = make_ref(),
    PidChoice = lists:nth(rand:uniform(length(ListPlaces)), ListPlaces),
    PidChoice ! {begin_visit, PidUser, Ref},
    util:sleep(util:rand_in_range(5000,10000)),
    PidChoice ! {end_visit, PidUser, Ref},
    visit(PidUser, ListPlaces).




getPlaces(UserPid) ->
    PidServer = global:whereis_name(server),
    PidServer ! {get_places, UserPid}.

choosePlaces(_, ReturnPlaces, 0) -> ReturnPlaces;
choosePlaces([], ReturnPlaces, _) -> io:format("Non abbiamo 3 posti in lista~n"), ReturnPlaces;
choosePlaces(ListPlaces, ReturnPlaces, N) ->
    Choice = lists:nth(rand:uniform(length(ListPlaces)), ListPlaces),
    monitor(process, Choice),
    choosePlaces(ListPlaces -- [Choice], [Choice|ReturnPlaces], N - 1).
