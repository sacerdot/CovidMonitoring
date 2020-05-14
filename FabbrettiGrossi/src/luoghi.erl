-module(luoghi).
-export([start/0]).


place_manager() ->
  receive
    new_visitor ->
      Result = rand:uniform(10),
      case Result of
        10 -> exit(normal);   % close place
        _ -> place_manager()  % keep open
      end
  end.


contact(NEW_VISITOR, [VISITOR | OTHER_VISITORS]) ->
  Result = rand:uniform(4),
  case Result of
    4 ->
      NEW_VISITOR ! {contact, VISITOR},
      VISITOR ! {contact, NEW_VISITOR},
      contact(NEW_VISITOR, OTHER_VISITORS);

    _ -> contact(NEW_VISITOR, OTHER_VISITORS)
  end.


contact_manager() ->
  receive
    {find_contacts, NEW_VISITOR, VISITORS_LIST} ->
      contact(NEW_VISITOR, VISITORS_LIST)
  end,
  contact_manager().


update_visitors(VISITORS_LIST) ->
  receive
    % VISIT PROTOCOL/1: begin visit
    {begin_visit, PID_VISITATORE, REF} ->
      % CONTACT PROTOCOL
      CM_pid = global:whereis_name(cm),
      CM_pid ! {find_contacts, PID_VISITATORE, VISITORS_LIST},

      % LIFE CYCLE
      PM_pid = global:whereis_name(pm),
      PM_pid ! new_visitor,

      % notify begin visit
      update_visitors([{REF, PID_VISITATORE} | VISITORS_LIST]);

    % VISIT PROTOCOL/2: end visit
    {end_visit, PID_VISITATORE, REF} ->
      % notify end visit
      update_visitors(VISITORS_LIST -- [{REF, PID_VISITATORE}])
  end.


luogo() ->
  io:format("Io sono il luogo ~p~n",[self()]),
  Server = global:whereis_name(server),
  % INIT PROTOCOL/1: link to server
  link(Server),
  % INIT PROTOCOL/2: notify server
  Server ! {new_place, self()},
  % contact manager
  CM_pid = spawn_link(fun contact_manager/0),
  global:register_name(cm, CM_pid),
  % place manager
  PM_pid = spawn_link(fun place_manager/0),
  global:register_name(pm, PM_pid),
  % update visitors
  update_visitors([]).


start() ->
  [ spawn(fun luogo/0) || _ <- lists:seq(1,10) ].
