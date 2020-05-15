-module(luoghi).
-export([start/0, luogo/0, init_luogo/0, visit_place/1, sleep/1, set_subtract/2]).
-import(server, [init/1]).

sleep(T) ->
  receive after T -> ok end.

set_subtract(L1, L2) ->
  lists:filter(fun(X) -> not lists:member(X, L2) end, L1).

init_luogo() ->
  PID = global:whereis_name(server),
  case PID of
    undefined -> exit(server_not_registered);
    P -> 
      P ! {ciao,da,luogo,self()},
      link(P)
  end,
  process_flag(trap_exit, true),
  global:send(server, {new_place, self()}),
  visit_place([]).

visit_place(L) ->
  %io:format("[Luogo] ~p Utenti nel luogo: ~p ~n", [self(), L]),
  receive
    {begin_visit, PID, Ref} ->
      MRef = monitor(process, PID),
      %% PidOldUser can die
      contact_tracing(PID, [PidOldUser || {PidOldUser, _, _} <- L]),
      check_for_closing(),
      visit_place([{PID, Ref, MRef} | L]);
    {end_visit, PID, Ref} ->
      %visit_place(lists:delete({PID, Ref}, L))
      [MRef] = [MR || {Pid, _, MR} <- L, Pid =:= PID],
      demonitor(MRef),
      visit_place(set_subtract(L, [{PID, Ref, MRef}]));
    {'DOWN', MRef, process, PidExit, Reason} ->
      [{Ref, MRef}] = [{R,MR} || {Pid, R, MR} <- L, Pid =:= PidExit],
      io:format("[Luogo] ~p User ~p with Ref  ~p died with reason ~p ~n", [self(), PidExit,Ref, Reason]),
      NL = set_subtract(L, [{PidExit, Ref, MRef}]),
%%      io:format("[Luogo] ~p Actual list: ~p ~n", [self(), NL]),
      visit_place(NL)
  end.

contact_tracing(_, []) -> ok;
contact_tracing(NewUser, [PidOldUser | T]) ->
  %io:format("[Luogo] Lancio del dado per il contatto del nuovo utente ~p ~n", [NewUser]),
  case rand:uniform(4) of
    1 -> NewUser ! {contact, PidOldUser};
    %io:format("[Luogo] Contatto avvenuto tra user nuovo ~p e ~p ~n", [NewUser, PidOldUser]);
    _ -> ok
    %io:format("[Luogo] Nessun contatto avvenuto tra user nuovo ~p e ~p ~n", [NewUser, PidOldUser])
  end,
  contact_tracing(NewUser, T).

check_for_closing() ->
  case rand:uniform(10) of
    1 ->
%%      io:format("[Luogo] ~p died with 10% ~n", [self()]),
      exit(normal);
    _ -> ok
  end.

start() ->
  [ spawn(fun luogo/0) || _ <- lists:seq(1,10) ].

luogo() ->
  io:format("Io sono il luogo ~p~n",[self()]),
  %Server = global:whereis_name(server),
  init_luogo().

