-module(luoghi).
-export([start/0]).

place_manager() ->
    Result = rand:uniform(10),
    case Result of
        10 ->
            exit(normal);   % close place
        _ ->
            ok
    end.

find_contact(_, []) -> ok;
find_contact(NEW_VISITOR, [VISITOR | OTHER_VISITORS]) ->
    Result = rand:uniform(4),
    case Result of
        4 ->
            {_, PID_VISITOR} = VISITOR,
            NEW_VISITOR ! {contact, PID_VISITOR},
            PID_VISITOR ! {contact, NEW_VISITOR},
            find_contact(NEW_VISITOR, OTHER_VISITORS);

        _ -> find_contact(NEW_VISITOR, OTHER_VISITORS)
  end.


debug({contact, Pid1, Pid2}) ->
    io:format("~p: Contatto tra ~p e ~p~n", [self(), Pid1, Pid2]);
debug({end_visit, Pid, Visitors}) ->
    VisitorList = [ L || {_, L} <- Visitors],
    io:format("~p: visitatore ~p ha terminato la visita ~n", [self(), Pid]),
    io:format("~p: Lista di visitatori nel luogo: ~p~n", [self(),VisitorList -- [Pid]]);
debug({begin_visit, Pid, Visitors}) ->
    VisitorList = [ L || {_, L} <- Visitors],
    io:format("~p: Lista di visitatori nel luogo: ~p~n", [self(),VisitorList ++ [Pid]]),
    io:format("~p: visitatore ~p ha iniziato la visita~n", [self(), Pid]).



update_visitors(VISITORS_LIST) ->
    receive
        {debug, Message} ->
            debug(Message),
            update_visitors(VISITORS_LIST);

        {begin_visit, PID_VISITATORE, REF} ->
            %DEBUG
            self() ! {debug, {begin_visit, PID_VISITATORE, VISITORS_LIST}},

            % CONTACT PROTOCOL
            find_contact(PID_VISITATORE, VISITORS_LIST),

            % LIFE CYCLE
            place_manager(),
            update_visitors([{REF, PID_VISITATORE} | VISITORS_LIST]);

        {end_visit, PID_VISITATORE, REF} ->
            self() ! {debug, {end_visit, PID_VISITATORE, VISITORS_LIST}},
            update_visitors(VISITORS_LIST -- [{REF, PID_VISITATORE}]);

        Other ->
            io:format("Messaggio inatteso: ~p~n", [Other]),
            update_visitors(VISITORS_LIST)
  end.


luogo() ->
  io:format("Io sono il luogo ~p~n",[self()]),
  Server = global:whereis_name(server),
  % INIT PROTOCOL/1: link to server
  link(Server),
  % INIT PROTOCOL/2: notify server
  Server ! {new_place, self()},
  % update visitors
  update_visitors([]).


start() ->
  [ spawn(fun luogo/0) || _ <- lists:seq(1,10) ].
