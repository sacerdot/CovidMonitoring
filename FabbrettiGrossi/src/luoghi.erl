-module(luoghi).
-export([start/0, place_manager/1, contact_manager/1]).


place_manager(Manager) ->
    receive
        new_visitor ->
            Result = rand:uniform(10),
            case Result of
                10 ->
                    %DEBUG
                    Manager ! {debug, place_close_normally},
                    exit(normal);   % close place
                _ ->
                    place_manager(Manager)  % keep open
            end
    end.

contact(_, _, []) -> ok;
contact(Manager, NEW_VISITOR, [VISITOR | OTHER_VISITORS]) ->
    Result = rand:uniform(4),
    case Result of
        4 ->
            {_, PID_VISITOR} = VISITOR,
            NEW_VISITOR ! {contact, PID_VISITOR},
            PID_VISITOR ! {contact, NEW_VISITOR},
            contact(Manager, NEW_VISITOR, OTHER_VISITORS);

        _ -> contact(Manager, NEW_VISITOR, OTHER_VISITORS)
  end.


contact_manager(Manager) ->
    receive
        {find_contacts, NEW_VISITOR, VISITORS_LIST} ->
            contact(Manager, NEW_VISITOR, VISITORS_LIST)
    end,
  contact_manager(Manager).

debug(Message) ->
    case Message of
        {contact, Pid1, Pid2} ->
            io:format("~p: Contatto tra ~p e ~p~n", [self(), Pid1, Pid2]);
        place_close_normally ->
            io:format("~p: chiude normalmente dopo una visita di un utente.~n", [self()]);
        {begin_visit, Pid, Visitors} ->
            VisitorList = [ L || {_, L} <- Visitors],
            io:format("~p: Lista di visitatori nel luogo: ~p~n", [self(),VisitorList ++ [Pid]]),
            io:format("~p: visitatore ~p ha iniziato la visita~n", [self(), Pid]);
        {end_visit, Pid, Visitors} ->
            VisitorList = [ L || {_, L} <- Visitors],
            io:format("~p: visitatore ~p ha terminato la visita ~n", [self(), Pid]),
            io:format("~p: Lista di visitatori nel luogo: ~p~n", [self(),VisitorList -- [Pid]])
        end.


update_visitors(VISITORS_LIST, PID_MANAGER) ->
    receive
        {debug, Message} ->
            debug(Message),
            update_visitors(VISITORS_LIST, PID_MANAGER);
        {'DOWN',_, process, _, normal} ->
            exit(normal);
            % VISIT PROTOCOL/1: begin visit
        {begin_visit, PID_VISITATORE, REF} ->
            %DEBUG
            self() ! {debug, {begin_visit, PID_VISITATORE, VISITORS_LIST}},
            % get pid managers
            {pid_manager, CM_pid, PM_pid} = PID_MANAGER,
            % CONTACT PROTOCOL
            CM_pid ! {find_contacts, PID_VISITATORE, VISITORS_LIST},
                                                % LIFE CYCLE
            PM_pid ! new_visitor,

            % notify begin visit
            update_visitors([{REF, PID_VISITATORE} | VISITORS_LIST], PID_MANAGER);

            % VISIT PROTOCOL/2: end visit
        {end_visit, PID_VISITATORE, REF} ->
        %DEBUG
            self() ! {debug, {end_visit, PID_VISITATORE, VISITORS_LIST}},
            % notify end visit
            update_visitors(VISITORS_LIST -- [{REF, PID_VISITATORE}], PID_MANAGER)
  end.


luogo() ->
  io:format("Io sono il luogo ~p~n",[self()]),
  Server = global:whereis_name(server),
  % INIT PROTOCOL/1: link to server
  link(Server),
  % INIT PROTOCOL/2: notify server
  Server ! {new_place, self()},
  % contact manager
  {CM_pid, _} = spawn_monitor(?MODULE, contact_manager, [self()]),
  % place manager
  {PM_pid, _} = spawn_monitor(?MODULE, place_manager, [self()]),
  % update visitors
  update_visitors([],{pid_manager, CM_pid, PM_pid}).


start() ->
  [ spawn(fun luogo/0) || _ <- lists:seq(1,10) ].
