-module(users).
-export([users_init/0, timer_visit/3]).

rand_in_range(Min, Max) ->
	rand:uniform(Max-Min)+Min.

get_list(_, List ,  0) -> List;
get_list([], List, _) -> io:format("Non ho (~p) più posti ~p~n", [self(), List]),  List ;
get_list(Places, List, N) ->
   % io:format("In get list il ~p places è : ~p e list è ~p ~n",[N, Places, List]),
   X = lists:nth(rand:uniform(length(Places)), Places),
   monitor(process,X),
   get_list(Places -- [X], [X|List], N - 1).   %controllare che non viene tolto dal server

fget_places(N, UPlaces) ->
  %io:format("In fget places il mio pid è : ~p~n",[self()]),
  global:send(server, {get_places, self()}),
  receive
    {places, Places} ->
      % io:format("In fget_places ~p c'è la lista: ~p~n",[N, UPlaces]),
      % io:format("places - UPlaces ~p~n", [Places -- UPlaces] ),
      get_list(Places -- UPlaces, UPlaces, N)   %meglio lista vuota qui o UPlaces?
  end.

timer_visit(Pid, Time, Msg) -> receive after Time -> Pid ! {Msg} end.

wait_for_contacts(Contacts) ->
	receive
		{contact, Pid} ->
			link(Pid),
			wait_for_contacts([Pid|Contacts]);
		{end_wait} -> Contacts
	end.

make_visit(UPlaces) ->
  Ref = make_ref(),
  Place = lists:nth(rand:uniform(length(UPlaces)), UPlaces),
  % io:format("Io ~p Vognlio visitare il luogo ~p con ref ~p~n", [self(), Place, Ref]),
  Place ! {begin_visit, self(), Ref},
	spawn(?MODULE, timer_visit, [self(), rand_in_range(5000,10000), end_wait]),
	NewContacts = wait_for_contacts([]),
	Place ! {end_visit, self(), Ref},
	NewContacts.

test_virus() ->
	%io:format("voglio essere testato ~p~n", [self()]),
	global:send(hospital, {test_me, self()}),
	receive
		{test_result, RESULT} ->
			%io:format("ho ricevuto il risultato ~p~n", [self()]),
			case RESULT of
				positive ->
					io:format("Sono positivo ~p~n", [self()]),
					exit(positive);
				negative -> io:format("Sono negativo ~p~n", [self()])
			end
	end.

user(UPlaces, UContacts) ->
  %io:format("Places in User ~p~n",[UPlaces]),
  %io:format("In user il mio pid è : ~p~n",[self()]),
  %spawn(?MODULE, timer_visit, [self(), rand_in_range(3000,5000), usr_start_vist]),
  io:format("Io ~p sono in contatto con : ~p~n", [self(), UContacts]),
  receive
    {'DOWN', _ , process, Pid, _ } ->
      %io:format("Qualcuno è morto :( ~p~n",[Pid]),
      user(fget_places(1, UPlaces -- [Pid]), UContacts);
    {usr_start_vist} ->
			X = make_visit(UPlaces),
			%io:format("Io ~p sono in contatto con ~p~n",[self(), X ++ UContacts]),
			spawn(?MODULE, timer_visit, [self(), rand_in_range(3000,5000), usr_start_vist]),
			user(UPlaces, X ++ UContacts);
	{usr_test_request} ->
		case util:probability(4) of
			true -> test_virus();
			false -> ok
		end,
		spawn(?MODULE, timer_visit, [self(), 30000 , usr_test_request]),
		user(UPlaces, UContacts)

  end.


users_init() ->
	link(global:whereis_name(server)),
  	%global:send(server, {new_usr, self()}),
  	spawn(?MODULE, timer_visit, [self(), rand_in_range(3000,5000), usr_start_vist]), %possimao fare self perché user init chiama user non lo spowna (?)
	spawn(?MODULE, timer_visit, [self(), 30000 , usr_test_request]),
  	user(fget_places(3, []), []).
