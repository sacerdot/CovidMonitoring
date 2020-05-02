-module(places).
-export([place_init/0]).



contacts(_, []) -> []; %qualcosa per ritornare ok?
contacts(PID, [{FirstPid, _}|OtherVistiors]) ->
    FirstPid ! {contact, PID},
    PID ! {contact, FirstPid},
    contacts(PID, OtherVistiors).


place(Visitors) ->
    io:format("i miei (~p) visitatori: ~p~n", [self(),Visitors]),
    receive
        {begin_visit, PID_VISITOR, REF} ->
            io:format("è iniziata la vista di ~p in ~p con ref ~p ~n", [PID_VISITOR, self(), REF]),
            P = rand:uniform(4),
            case P of
                1 -> contacts(PID_VISITOR, Visitors);
                %negli altri casi non dobbiamo fare nulla
                %dobbiamo fare il caso default _ ?
                _ -> ok
            end,
            place([{PID_VISITOR, REF}|Visitors]);

        {end_visit, PID_VISITOR, REF} ->
            io:format("è finita la vista di ~p in ~p con ref ~p ~n", [PID_VISITOR, self(), REF]),
            place(Visitors -- [{PID_VISITOR, REF}])
    end.

place_init() ->
    %si linka al server
    %link(server),
    %comunica al server la propria esistenza
    global:send(server, {new_place, self()}),

    %Morte del luoghi
    % P = rand:uniform(2),
    % case P of
    %    1 -> receive after 100 ->
    %            io:format("I (worker ~p) will die now ...~n", [self()]),
    %            exit(no_activity)
    %        end;
    %    _ -> ok
    % end,

     place([]).
