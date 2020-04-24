-module(places).
-export([main/0, place_birth/0, user/1, counter/1]).

counter(N) ->
    receive
        {inc} -> io:format("counter ~p ~n", [N]), counter(N+1)
    end.
    

contacts(_, []) -> []; %qualcosa per ritornare ok?
contacts(PID, [{FirstPid, _}|OtherVistiors]) ->
    io:format("in contacts ~p ~n", [PID] ),
    FirstPid ! {contact, PID},
    PID ! {contact, FirstPid},
    contacts(PID, OtherVistiors).


place(Visitors) ->
    receive 
        {begin_visit, PID_VISITOR, REF} -> 
            P = rand:uniform(4),
            case P of
                1 -> contacts(PID_VISITOR, Visitors), counter ! {inc};
                %negli altri casi non dobbiamo fare nulla
                %dobbiamo fare il caso default _ ?
                _ -> ok
            end,
            place([{PID_VISITOR, REF}|Visitors]);

        {end_visit, PID_VISITOR, REF} ->
            place(Visitors -- [{PID_VISITOR, REF}])
    end.

place_birth() ->
    %si linka al server
    %link(server),
    %comunica al server la propria esistenza
    %server ! {new_place, self()},
    place([]).

sleep(N) -> receive after N -> ok end.

user(REF) ->
    sleep(rand:uniform(1000)),
    luogo ! {begin_visit, self(), REF},
    sleep(rand:uniform(1000)),
    luogo ! {end_visit, self(), REF}.

create_users(Num) ->
    case Num of
        0 -> ok;
        _ ->    spawn(?MODULE, user, [make_ref()]),
                create_users(Num-1)
    end.


main() ->
    Luogo = spawn(?MODULE, place_birth, []),
    register(luogo, Luogo),
    Counter = spawn(?MODULE, counter, [0]),
    register(counter, Counter),
    create_users(100).
    
