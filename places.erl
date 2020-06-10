-module(places).
-export([start/0]).

-define(NPLACES, 10).
-define(DEATHPROB, 10).
-define(CONTACTPROB, 25).

start() ->
    io:format("CIAO SONO IL GESTORE DEI LUOGHI~n"),
    [ spawn(fun place_init/0) || _ <- lists:seq(1,?NPLACES) ].

place_init() ->
    ServerPid =global:whereis_name(server),
    link(ServerPid),
    ServerPid ! {ciao, da, luogo, self()},
    ServerPid ! {new_place, self()},
    place_loop([]).


place_loop(Visitors) ->
    receive
        {begin_visit, PID_VISITOR, REF} ->
            case util:probability(?DEATHPROB) of
                true ->
                    io:format("Il luogo ~p sta chiudendo", [self()]), 
                    exit(normal);
                false -> ok
            end,
            case util:probability(?CONTACTPROB) of
                true -> [send_contact_msg(PID_VISITOR, Pid) || {Pid, _ } <- Visitors];
                false -> ok
            end,
            place_loop([{PID_VISITOR, REF}|Visitors]);

        {end_visit, PID_VISITOR, REF} ->
            place_loop(Visitors -- [{PID_VISITOR, REF}])

    end.




%%%  FUNZIONI AUSILIARIE

send_contact_msg(ContactPid, OtherPid) ->
    ContactPid ! {contact, OtherPid},
    OtherPid ! {contact, ContactPid}.
