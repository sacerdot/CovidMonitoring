-module(places).
-export([start/0]).



handler_contacts(_, []) -> ok;
handler_contacts(PID, [{FirstPid, _}| OtherVisitors]) ->  %HO TOLTO I REF
%contacts(PID, [FirstPid|OtherVistiors]) ->  %HO TOLTO I REF
    FirstPid ! {contact, PID},
    PID ! {contact, FirstPid},
    handler_contacts(PID, OtherVisitors).


place(Visitors) ->
    %io:format("i miei (~p) visitatori: ~p~n", [self(),Visitors]),
    receive
        {begin_visit, PID_VISITOR, REF} ->
            %io:format("è iniziata la vista di ~p in ~p con ref ~p ~n", [PID_VISITOR, self(), REF]),
            case util:probability(10) of
                true ->
                    io:format("il luogo ~p sta morendo~n", [self()]),
                    exit(normal);
                false -> ok
            end,
            case util:probability(25) of
                true -> handler_contacts(PID_VISITOR, Visitors);
                %TODO ipotesi: [send_contact_msg(Pid1, PID_VISITOR) | {Pid1, _} <- Visitors ]
                false -> ok
            end,
            place([{PID_VISITOR, REF}|Visitors]);

        {end_visit, PID_VISITOR, REF} ->
            place(Visitors -- [{PID_VISITOR, REF}])

    end.

place_init() ->
    ServerPid =global:whereis_name(server),
    link(ServerPid),
    ServerPid ! {msg_ping, "ciao da luogo", self()},
    ServerPid ! {new_place, self()},
    place([]).

start() ->
    io:format("CIAO SONO IL GESTORE DEI LUOGHI~n"),
    [ spawn(fun place_init/0) || _ <- lists:seq(1,10) ].