-module(utenti).
-export([start/0, loop/1, do_test/1, perform_visit/1, place_manager/1, sleep/1, sleep_random/2, sample/2]).

-record(status,{visiting = -1,
		visitor_pid = -1,
		visiting_ref = -1,
		places = []}).

place_manager(Manager) ->
    Manager ! {update_status, self()},
    receive {status, Status} ->
	    Places = Status#status.places,
	    case length(Places) < 3 of
		false -> Manager ! {status_updated, Status};
		true -> server ! {get_places, self()},
			AllPlaces = receive {places, Pidlist} -> Pidlist end,
			NewPlaces = erlang:subtract(AllPlaces, Places),
			PlacesUpdated = sample(NewPlaces, 3 - length(Places)),
			NewStatus = Status#status{places = PlacesUpdated},
			Manager ! {status_updated, NewStatus}
	    end
    end,			
    sleep(10),
    place_manager(Manager).


do_test(Manager) ->
    global:send(hospital, {test_me, self()}),
    receive
	positive -> 
            io:format("Sono positivo.~n"),
	    Manager ! {ask_status, self()},
	    receive
		{status, Status} when Status#status.visiting /= -1 -> 
		    io:format("Response received ~n"),
		    Luogo = Status#status.visiting,
		    Luogo ! {end_visit, Status#status.visitor_pid, Status#status.visiting_ref},		      
		    exit(positive);
		{status, _} -> 
		    exit(positive)
	    end;
     	negative -> 
	    io:format("Sono negativo.~n")
    end,
    sleep(1),
    do_test(Manager).

perform_visit(Manager) ->
    Manager ! {ask_places, self()},
    Places = receive {status, Status} -> Status#status.places end,
    case length(Places) > 0 of
	false ->
	    io:format("Non ci sono posti da visitare, dormo.~n");
	true ->
	    Place = sample(Places, 1),
	    Ref = erlang:make_ref(),
	    Place ! {begin_visit, self(), Ref},
	    Visit_time = rand:uniform(5) + 5,
	    spawn(?MODULE, fun (Pid) -> receive after Visit_time -> Pid ! done_visit end end, [self()]),
	    receive_contact(),
	    Place ! {end_visit, self(), Ref}
    end,
    sleep_random(3,5),
    perform_visit(Manager).

receive_contact() ->
    receive 
	{contact, Pid} -> 
	    link(Pid),
	    receive_contact();
	done_visit -> ok
    end.		        

loop(Status) ->
    receive
	{update_status, Pid} ->
	    Pid ! {status, Status},
	    receive
		{status_updated, NewStatus} -> loop(NewStatus)
	    end;
	{ask_status, Pid} -> 
	    Pid ! {status, Status},
	    loop(Status);
	{'EXIT', _, quarantena} ->
	    io:format("Entro in quarantena~n"),
	    exit(quarantena)
    end.


start() ->
    Status = #status{ visiting = -1,
		      places = []},
    process_flag(trap_exit, true),
    erlang:spawn_link(?MODULE, do_test, [self()]),
    loop(Status).
       	    %erlang:spawn_link(?MODULE, place_manager, [self()]),
            %erlang:spawn_link(?MODULE, perform_visit, [self()]),
	    %erlang:link(server),




%---------------- UTILS ----------------%

sample(N, L)->
    sample([], N, L).

sample(L,0,_) -> L;
sample(L1, N, L2) ->
    X = lists:nth(rand:uniform(length(L2)), L2),
    sample(L1 ++ X, N-1, [Y || Y <- L2, Y/= X]).

sleep(N) ->
    receive after N*1000 -> ok end.

sleep_random(I, S) ->
    X = rand:uniform(S-I),
    sleep(I+X).
