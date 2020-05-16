-module(luoghi).
-export([start/0, luogo/0, init_luogo/1, visit_place/2]).
-import(utils, [sleep/1, set_subtract/2, make_probability/1]).

init_luogo(Prob) ->
  PID = global:whereis_name(server),
  case PID of
    undefined ->
      exit(server_not_registered);
    P ->
      P ! {ciao, da, luogo, self()},
      link(P),
      process_flag(trap_exit, true),
      P ! {new_place, self()},
      visit_place([], Prob)
  end.

probs() ->
  Probs = #{contact_tracing => make_probability(25), check_for_closing => make_probability(10)},
  fun(X) ->
    maps:get(X, Probs)
  end.

visit_place(L, Probs) ->
%io:format("[Luogo] ~p Utenti nel luogo: ~p ~n", [self(), L]),
  receive
    {begin_visit, PID, Ref} ->
      MRef = monitor(process, PID),
      % PidOldUser can die
      contact_tracing(PID, [PidOldUser || {PidOldUser, _, _} <- L], Probs(contact_tracing)),
      check_for_closing(Probs(check_for_closing)),
      visit_place([{PID, Ref, MRef} | L], Probs);
    {end_visit, PID, Ref} ->
      [MRef] = [MR || {Pid, _, MR} <- L, Pid =:= PID],
      demonitor(MRef),
      visit_place(set_subtract(L, [{PID, Ref, MRef}]), Probs);
    {'DOWN', MRef, process, PidExit, Reason} ->
      [{Ref, MRef}] = [{R, MR} || {Pid, R, MR} <- L, Pid =:= PidExit],
      io:format("[Luogo] ~p User ~p with Ref  ~p died with reason ~p ~n", [self(), PidExit, Ref, Reason]),
      NL = set_subtract(L, [{PidExit, Ref, MRef}]),
%%      io:format("[Luogo] ~p Actual list: ~p ~n", [self(), NL]),
      visit_place(NL, Probs)
  end.

contact_tracing(_, [], _) -> ok;
contact_tracing(NewUser, [PidOldUser | T], Prob) ->
  %io:format("[Luogo] Lancio del dado per il contatto del nuovo utente ~p ~n", [NewUser]),
  case Prob() of
    1 -> NewUser ! {contact, PidOldUser};
    %io:format("[Luogo] Contatto avvenuto tra user nuovo ~p e ~p ~n", [NewUser, PidOldUser]);
    _ -> ok
    %io:format("[Luogo] Nessun contatto avvenuto tra user nuovo ~p e ~p ~n", [NewUser, PidOldUser])
  end,
  contact_tracing(NewUser, T, Prob).

check_for_closing(Prob) ->
  case Prob() of
    1 -> exit(normal);
    _ -> ok
  end.

start() ->
  % TODO rimettere lists:seq(1,10)
  [spawn(fun luogo/0) || _ <- lists:seq(1, 10)].

luogo() ->
  io:format("Io sono il luogo ~p~n", [self()]),
  init_luogo(probs()).

