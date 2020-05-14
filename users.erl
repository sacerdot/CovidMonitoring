-module(users).
-export([users_init/0, fget_places/3, visit/2, test_virus/1, visit_place/3]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%                          init                             %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

users_init() ->
	%io:format("New User ~p~n",[self()]),
	link(global:whereis_name(server)),
    PidPlaces = spawn_link(?MODULE, fget_places, [3, self(), []]),
    PidTest = spawn_link(?MODULE, test_virus, [self()]),
%  	user([], [], PidVisit, PidTest, PidPlaces).
 	user([], [], 0, PidTest, PidPlaces).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%                          user                             %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

user(UPlaces, UContacts, PidVisit, PidTest, PidPlaces) ->
  %io:format("Io ~p ho questi luoghi: ~p~n", [self(), UPlaces]),
  %io:format("Io ~p sono in contatto con : ~p~n", [self(), UContacts]),
  receive
    {contact, Pid} ->
		%%Probabilmente il try catch si può rimuovere era per sicurezza
        try
		 	link(Pid),
			RemovePid = UContacts--[Pid], %Questo trick e' molto brutto per non avere doppioni, se si fa inline non funziona
			NewPidList =  RemovePid++[Pid],
			user(UPlaces, NewPidList, PidVisit, PidTest, PidPlaces)
		catch _ ->
			io:format("Io ~p sto cercando di connettermi a un Pid morto ~p~n",[self(), Pid])
		end
    ;
    {places, Places} ->
		PidPlaces ! {places_list, UPlaces, Places},
		user(UPlaces, UContacts, PidVisit, PidTest, PidPlaces)
	;
	%Non riesco a capite perché come era fatto prima fosse bloccante e inchiodasse gli user
	%così è brutto perché abbiamo rimesso in user messaggi non del prof
	{place_usr, Places} ->
		%io:format("Io ~p ho i seguenti luoghi ~p~n", [self(), Places]),
		case PidVisit of
			0 ->
				PidNewVisit = spawn_link(?MODULE, visit, [self(), Places]),
				user(Places, UContacts, PidNewVisit, PidTest, PidPlaces);
			_ ->
				PidVisit ! {new_places, Places},
				user(Places, UContacts, PidVisit, PidTest, PidPlaces)
		end

    ;
    {test_result, RESULT} ->
        PidTest ! {test_result_u, RESULT},
		user(UPlaces, UContacts, PidVisit, PidTest, PidPlaces)
  end.





%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%                    protocol workers                       %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

test_virus(Pid) ->
	util:sleep(30000),
	case util:probability(4) of
		false -> test_virus(Pid);
		true ->
			global:send(hospital, {test_me, Pid}),
			receive
				{test_result_u, RESULT} ->
					%%io:format("ho ricevuto il risultato ~p~n", [self()]),
					case RESULT of
						positive ->
							%io:format("Sono positivo ~p~n", [Pid]),
							exit(positive);
						negative ->
							%io:format("Sono negativo ~p~n", [Pid]),
							test_virus(Pid)
					end
			end
	end.

visit(Pid, Places) ->
	MyPid = self(),
	PidVisit = spawn_link(fun() -> process_flag(trap_exit, true), visit_place(Pid, Places, MyPid) end),
	receive
		{new_places, NewPlaces} ->
			PidVisit ! {exit_visit},
			visit(Pid, NewPlaces);
		{end_visit, _} ->
			visit(Pid, Places)
	end.

visit_place(_, [], _) -> ok;
visit_place(Pid, UPlaces, PidVisit) -> %... oppure qui creo un altro attore che mi aspetta l'aggiornamento dei luoghi se necessario
	util:sleep(util:rand_in_range(3000,5000)),
    Ref = make_ref(),
    Place = lists:nth(rand:uniform(length(UPlaces)), UPlaces),
    Place ! {begin_visit, Pid, Ref},
    receive
		{'EXIT',Pid, Reason} ->
			Place ! {end_visit, Pid, Ref},
			exit(Reason);
		{exit_visit} ->
			Place ! {end_visit, Pid, Ref}
	after util:rand_in_range(5000,10000) -> %fare la recive del messaggio exit positive?
        Place ! {end_visit, Pid, Ref},
		PidVisit ! {end_visit, self()} %%Ci serve mandargli il pid?
		%%io:format("Io ~p ho finito la visita in ~p con ref ~p~n", [Pid, Place, Ref])
    end.



%%capire come chiedere ogni 10 secondi se tutti i luoghi sono vivi
fget_places(N, Pid, PidPlace) ->
	case N of
		0 -> ok;
		_ -> global:send(server, {get_places, Pid})
	end,
	receive
		{places_list, UPlaces, Places} ->
			ListPlaces = get_list(Places -- UPlaces, UPlaces, N)++UPlaces--PidPlace,
			Pid ! {place_usr, ListPlaces},
			fget_places(0, Pid, []);
		{'DOWN', _ , process, PidPlace, _ } ->
			%io:format("Morto luogo ~p collegato a utente ~p~n", [PidPlace, Pid]),
			fget_places(1, Pid, [PidPlace])
	end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%% da spostare in utils %%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


get_list(_, List ,  0) -> List;
get_list([], List, _) -> ok; %io:format("Non ho (~p) più posti ~p~n", [self(), List]),  List ;
get_list(Places, List, N) ->
   % %io:format("In get list il ~p places è : ~p e list è ~p ~n",[N, Places, List]),
   X = lists:nth(rand:uniform(length(Places)), Places),
   monitor(process,X),
   get_list(Places -- [X], [X|List], N - 1).   %controllare che non viene tolto dal server

% sleep(N) -> receive after N -> ok end.
