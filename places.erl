-module(places).
-export([place_init/0]).

   

contacts(_, []) -> []; %qualcosa per ritornare ok?
contacts(PID, [{FirstPid, _}|OtherVistiors]) ->
    FirstPid ! {contact, PID},
    PID ! {contact, FirstPid},
    contacts(PID, OtherVistiors).


place(Visitors) ->
    receive 
        {begin_visit, PID_VISITOR, REF} -> 
            P = rand:uniform(4),
            case P of
                1 -> contacts(PID_VISITOR, Visitors);
                %negli altri casi non dobbiamo fare nulla
                %dobbiamo fare il caso default _ ?
                _ -> ok
            end,
            place([{PID_VISITOR, REF}|Visitors]);

        {end_visit, PID_VISITOR, REF} ->
            place(Visitors -- [{PID_VISITOR, REF}])
    end.

place_init() ->
    %si linka al server
    %link(server),
    %comunica al server la propria esistenza
    global:send(server, {new_place, self()}),

    %Morte del luoghi
    %P = rand:uniform(4),
    %case P of
    %    1 -> receive after 100 ->
    %            io:format("I (worker ~p) will die now ...~n", [self()]),
    %            exit(no_activity)
    %        end;
    %    _ -> ok
    %end,

     place([]).
    
