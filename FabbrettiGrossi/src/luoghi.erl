-module(luoghi).
-export([start/0]).


place_manager() ->
  receive
    new_visitor ->
      Result = rand:uniform(10),
      case Result of
        10 -> 
	      %DEBUG
	      io:format("Il posto chiude normalmente dopo una visita di un utente.~n"),
	      exit(normal);   % close place
        _ -> place_manager()  % keep open
      end
  end.

contact(_, []) -> ok;
contact(NEW_VISITOR, [VISITOR | OTHER_VISITORS]) ->
  Result = rand:uniform(4),
  case Result of
    4 ->
      {_, PID_VISITOR} = VISITOR,
      NEW_VISITOR ! {contact, PID_VISITOR},
      PID_VISITOR ! {contact, NEW_VISITOR},
      contact(NEW_VISITOR, OTHER_VISITORS);

    _ -> contact(NEW_VISITOR, OTHER_VISITORS)
  end.


contact_manager() ->
  receive
    {find_contacts, NEW_VISITOR, VISITORS_LIST} ->
      contact(NEW_VISITOR, VISITORS_LIST)
  end,
  contact_manager().


update_visitors(VISITORS_LIST, PID_MANAGER) ->
  receive
      {'DOWN',_, process, _, normal} -> 
	  exit(normal);
      % VISIT PROTOCOL/1: begin visit
      {begin_visit, PID_VISITATORE, REF} ->
      %DEBUG
      io:format("Lista di visitatori nel luogo: ~p~n", [VISITORS_LIST]),
      io:format("Visitatore: ~p ha iniziato la visita di ~p~n", [PID_VISITATORE, self()]),
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
         io:format("Visitatore: ~p ha terminato la visita di ~p~n", [PID_VISITATORE, self()]),
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
  {CM_pid, _} = spawn_monitor(fun contact_manager/0),
  % place manager
  {PM_pid, _} = spawn_monitor(fun place_manager/0),
  % update visitors
  update_visitors([],{pid_manager, CM_pid, PM_pid}).


start() ->
  [ spawn(fun luogo/0) || _ <- lists:seq(1,10) ].
