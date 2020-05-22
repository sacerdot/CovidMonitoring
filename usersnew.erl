-module(usersnew).
-export([users_init/0, visit/2, getTested/1, askMorePlaces/1]).


users_init() ->
    process_flag(trap_exit, true),
	io:format("New User ~p~n",[self()]),

    ServerPid = global:whereis_name(server),
	link(ServerPid),
    HospitalPid = global:whereis_name(hospital),
    GetPids = setGlobal(self(), ServerPid, HospitalPid),

    getPlaces(GetPids),

    PidVisit = spawn_link(fun() -> process_flag(trap_exit, true), visit(GetPids,[]) end),
    PidTester = spawn_link(?MODULE, getTested, [GetPids]),
    PidAskPlaces = spawn_link(?MODULE, askMorePlaces, [GetPids]),
    
 	user([], PidVisit, PidAskPlaces, GetPids). 


user(UPlaces, PidVisit, PidAskPlaces, GetPids) ->
    receive
        {places, Places} ->
            case length(Places) < 3 of
                true -> PidAskPlaces ! {ask_more_places};
                false -> ok
            end,
            ChoosenPlaces = choosePlaces(Places -- UPlaces, UPlaces, 3 - length(UPlaces)),
            PidVisit ! {place_list, ChoosenPlaces},
            user(ChoosenPlaces, PidVisit, PidAskPlaces, GetPids);

        {contact, PidUContact} ->
            link(PidUContact),
            user(UPlaces, PidVisit, PidAskPlaces, GetPids);


        {test_result, positive} ->
            io:format("Sono positivo (~p)~n", [self()]), %togliere stampa pid
            exit(positive);
            
        {test_result, negative} -> 
            io:format("Sono negativo (~p)~n", [self()]), %togliere stampa pid
            user(UPlaces, PidVisit, PidAskPlaces, GetPids);

        % {test_result, Result} ->
        %     case Result of
        %         positive ->
        %             io:format("Sono positivo (~p)~n", [self()]), %togliere stampa pid
        %             exit(positive);
        %         negative ->
        %             io:format("Sono negativo (~p)~n", [self()]), %togliere stampa pid
        %             user(UPlaces, PidVisit, PidAskPlaces, GetPids)
        %     end;

        {'DOWN', _ , process, PidPlace, _} -> %{'DOWN', Reference, process, Pid, Reason} ->
            getPlaces(GetPids),
            user(UPlaces -- [PidPlace], PidVisit, PidAskPlaces, GetPids);


        {'EXIT', _ , Reason} when Reason =:= positive; Reason =:= quarantena-> 
            io:format("Entro in quarantena~n"),
            exit(quarantena);

        {'EXIT', _ , normal} -> 
             user(UPlaces, PidVisit, PidAskPlaces, GetPids);
        
        {'EXIT', _ , Reason} ->     
            io:format("L'utente sta per mprire per ragione ~p~n", [Reason]), 
            exit(Reason) %nel caso in cui qualuno a cui siamo linkati termini per un'altra ragione, anche noi terminiamo con la stessa reason
            
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% ATTORE: VISITA %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

visit(GetPids, []) -> receive {place_list, ChoosenPlaces} -> visit(GetPids, ChoosenPlaces) end;
visit(GetPids, ListPlaces) ->
    PidUser = maps:get(user, GetPids(visit)),
    receive {place_list, ChoosenPlaces} ->
        visit(GetPids, ChoosenPlaces)
    after util:rand_in_range(3000, 5000) -> ok end, %se arrivano i messaggi prima che io mi metto in attesa di riceverli, che succede?
    Ref = make_ref(),
    PidChoice = util:rand_in_list(ListPlaces),
    PidChoice ! {begin_visit, PidUser, Ref},
    receive
        {'EXIT', _ , Reason} ->
            PidChoice ! {end_visit, PidUser, Ref},
            exit(Reason)
    after util:rand_in_range(5000,10000) ->
        PidChoice ! {end_visit, PidUser, Ref},
        visit(GetPids, ListPlaces)
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% ATTORE: TEST %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

getTested(GetPids) ->
    util:sleep(30000),
    case util:probability(4) of
        true ->
            PidHospital = maps:get(hospital, GetPids(get_tested)),
            PidUser = maps:get(user, GetPids(get_tested)),
            PidHospital ! {test_me, PidUser};
        false ->
            ok
    end,
    getTested(GetPids).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% ATTORE: RICHIESTA POSTI OGNI 10 s %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

askMorePlaces(GetPids) ->
    receive 
    %NOTA: vengono aggiunti in coda msg ask a ogni morte di luogo (se nascono nuovi luoghi facciamo un paio di giri in piu')
        {ask_more_places} -> 
            util:sleep(10000),
            io:format("Abbiamo chiesto altri posti~n"),
            getPlaces(GetPids),
            askMorePlaces(GetPids)
    end.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% FUNZIONI AUSILIARIE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

getPlaces(GetPids) ->
    PidServer = maps:get(server, GetPids(get_places)),
    PidUser = maps:get(user, GetPids(get_places)),
    PidServer ! {get_places, PidUser}.

setGlobal(UsrPid, ServerPid, HospitalPid) -> 
    fun (T) -> 
        case T of 
            visit -> #{user => UsrPid}; 
            get_tested -> #{user => UsrPid, hospital => HospitalPid}; 
            ask_more_places -> #{user => UsrPid, server => ServerPid};
            get_places -> #{user => UsrPid, server => ServerPid};
            _ -> #{} 
        end 
    end. 

choosePlaces(_, ReturnPlaces, 0) -> ReturnPlaces;
choosePlaces([], ReturnPlaces, _) -> ReturnPlaces;
choosePlaces(ListPlaces, ReturnPlaces, N) ->
    Choice = util:rand_in_list(ListPlaces),
    monitor(process, Choice),
    choosePlaces(ListPlaces -- [Choice], [Choice|ReturnPlaces], N - 1).
