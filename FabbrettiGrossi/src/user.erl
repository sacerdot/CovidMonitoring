-module(user).
-include("user.hrl").
-export([init/0, loop/1, do_test/1, perform_visit/1, place_manager/1]).


place_manager(Manager) ->
    Manager ! {update_status, self()},
    receive {status, Status} ->
	    Places = Status#status.places,
	    case length(Places) < 3 of
		false -> Manager ! {status_updated, Status};
		true -> server ! {get_places, self()},
			AllPlaces = receive {places, Pidlist} -> Pidlist end,
			NewPlaces = erlang:subtract(AllPlaces, Places),
			PlacesUpdated = utils:sample(NewPlaces, 3 - length(Places)),
			Status#status{places = PlacesUpdated},
			Manager ! {status_updated, Status}
	    end
    end,			
    utils:sleep(10),
    place_manager(Manager).


do_test(Manager) ->
    hospital ! {test_me, self()},
    receive
	positive -> 
            io:format("Sono positivo.~n"),
	    Manager ! {update_status, self()},
	    receive
		{status, Status} when Status#status.visiting /= -1-> 
		    Luogo = Status#status.visiting,
		    Luogo ! {end_visit, Status#status.visitor_pid, Status#status.visiting_ref}
	    end,
            exit(positive);
	negative -> 
	    io:format("Sono negativo.~n")
    end,
    utils:sleep(30),
    do_test(Manager).

perform_visit(Manager) ->
    Manager ! {ask_places, self()},
    Places = receive {status, Status} -> Status#status.places end,
    case length(Places) > 0 of
	false ->
	    io:format("Non ci sono posti da visitare, dormo.~n");
	true ->
	    Place = utils:sample(Places, 1),
	    Ref = erlang:make_ref(),
	    Place ! {begin_visit, self(), Ref},
	    utils:sleep_random(5,10),
	    Place ! {end_visit, self(), Ref}
    end,
    utils:sleep_random(3,5).


loop(Status) ->
    receive
	{update_status, Pid} ->
	    Pid ! {status, Status},
	    receive
		{status_updated, NewStatus} -> loop(NewStatus)
	    end;
	{ask_status, Pid} -> 
	    Pid ! {status, Status},
	    loop(Status)
    end.


init() ->
    Status = #status{ visiting = -1,
		      places = []},
    erlang:link(server),
    erlang:spawn_link(?MODULE, do_test, [self()]),
    erlang:spawn_link(?MODULE, place_manager, [self()]),
    erlang:spawn_link(?MODULE, perform_visit, [self()]),
    loop(Status).

