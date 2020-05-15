-module(places).
-export([place_init/0]).



contacts(_, []) -> ok; %qualcosa per ritornare ok?
contacts(PID, [{FirstPid, _}|OtherVistiors]) ->  %HO TOLTO I REF
%contacts(PID, [FirstPid|OtherVistiors]) ->  %HO TOLTO I REF
    FirstPid ! {contact, PID},
    PID ! {contact, FirstPid},
    contacts(PID, OtherVistiors).


place(Visitors) ->
    %io:format("i miei (~p) visitatori: ~p~n", [self(),Visitors]),
    receive
        {begin_visit, PID_VISITOR, REF} ->
            %io:format("è iniziata la vista di ~p in ~p con ref ~p ~n", [PID_VISITOR, self(), REF]),
            case util:probability(100) of
                true ->
                    io:format("il luogo ~p sta morendo~n", [self()]),
                    exit(normal);
                false -> ok
            end,
            case util:probability(4) of
                true -> contacts(PID_VISITOR, Visitors);
                false -> ok
            end,
            place([{PID_VISITOR, REF}|Visitors]);
            %place([PID_VISITOR|Visitors]);

        {end_visit, PID_VISITOR, REF} ->
            %io:format("è finita la vista di ~p in ~p con ref ~p ~n", [PID_VISITOR, self(), REF]),
            place(Visitors -- [{PID_VISITOR, REF}])
            %place(Visitors -- [PID_VISITOR])
    end.

place_init() ->
    %comunica al server la propria esistenza
    Pid_Server=global:whereis_name(server),
    link(Pid_Server),
    Pid_Server ! {new_place, self()},
    place([]).
