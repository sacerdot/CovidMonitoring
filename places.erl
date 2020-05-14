-module(places).
-export([place_init/0]).



contacts(_, []) -> ok; %qualcosa per ritornare ok?
% contacts(PID, [{FirstPid, _}|OtherVistiors]) ->  %HO TOLTO I REF
contacts(PID, [FirstPid|OtherVistiors]) ->  %HO TOLTO I REF
    FirstPid ! {contact, PID},
    PID ! {contact, FirstPid},
    contacts(PID, OtherVistiors).


place(Visitors) ->
    %io:format("i miei (~p) visitatori: ~p~n", [self(),Visitors]),
    receive
        {begin_visit, PID_VISITOR, REF} ->
            %io:format("è iniziata la vista di ~p in ~p con ref ~p ~n", [PID_VISITOR, self(), REF]),
            case util:probability(10) of
                true ->
                    io:format("il luogo ~p sta morendo~n", [self()]),
                    exit(debug);
                false -> ok
            end,
            case util:probability(4) of
                true -> contacts(PID_VISITOR, Visitors);
                %negli altri casi non dobbiamo fare nulla
                %dobbiamo fare il caso default _ ?
                false -> ok
            end,
            % place([{PID_VISITOR, REF}|Visitors]);
            place([PID_VISITOR|Visitors]);

        {end_visit, PID_VISITOR, REF} ->
            %io:format("è finita la vista di ~p in ~p con ref ~p ~n", [PID_VISITOR, self(), REF]),
            %place(Visitors -- [{PID_VISITOR, REF}]);
            place(Visitors -- [PID_VISITOR]);

        {death_of_user, PID_USER} -> place(Visitors -- [PID_USER]) % TODO: vedere di accorgersi della morte di un utente durante la visita senza di questo

    end.

place_init() ->
    %comunica al server la propria esistenza
    Pid_Server=global:whereis_name(server),
    link(Pid_Server),
    Pid_Server ! {new_place, self()},
    place([]).
