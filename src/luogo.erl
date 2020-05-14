-module(luogo).
-export([main/0, init_luogo/0, visit_place/1, sleep/1, user/1, set_subtract/2]).
-import(server, [init/1]).

sleep(T) ->
  receive after T -> ok end.

set_subtract(L1, L2) ->
  lists:filter(fun(X) -> not lists:member(X, L2) end, L1).

init_luogo() ->
  io:format("Luogo pid: ~p~n", [self()]),
  PID = global:whereis_name(server),
  case PID of
    undefined -> exit(server_not_registered);
    P -> link(P)
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
  case rand:uniform(1) of
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

user(Luogo) ->
  R = make_ref(),
  Luogo ! {begin_visit, self(), R},
  sleep(rand:uniform(5000)),
  Luogo ! {end_visit, self(), R}.

%pretty_print(Msg) -> 
%    io:format("[~p] ~p ~n", [?MODULE, Msg]).

main() ->
  L = [],
  S = spawn(server, init, [L]),
  global:register_name(server, S),
  Luogo = spawn(?MODULE, init_luogo, []),
  U1 = spawn(?MODULE, user, [Luogo]),
  io:format("[Luogo] Pid utente1 ~p ~n", [U1]),
  U2 = spawn(?MODULE, user, [Luogo]),
  io:format("[Luogo] Pid utente2 ~p ~n", [U2]),
  U3 = spawn(?MODULE, user, [Luogo]),
  io:format("[Luogo] Pid utente3 ~p ~n", [U3]).


