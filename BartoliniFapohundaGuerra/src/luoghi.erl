-module(luoghi).
-export([start/0, luogo/0, init_luogo/1, visit_place/2]).
-import(utils, [sleep/1, set_subtract/2, make_probability/1, check_service/1]).

%%%%%%%%%%%%%%%%%%%%%%%%%%% PROTOCOLLO DI INIZIALIZZAZIONE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
init_luogo(Prob) ->
  PidServer = check_service(server),
  PidServer ! {ciao, da, luogo, self()},
  link(PidServer),
  process_flag(trap_exit, true),
  PidServer ! {new_place, self()},
  visit_place([], Prob).

%%%%%%%%%%%%%%%%%%%%%%%%%%% PROTOCOLLO DI VISITA DEI LUOGHI %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
visit_place(L, Probs) ->
  receive
    {begin_visit, PID, Ref} ->
      MRef = monitor(process, PID),
      % PidOldUser can die
      [contact(PID, PidOldUser, Probs(contact_tracing)) || {PidOldUser, _, _} <- L],
      check_for_closing(Probs(check_for_closing)),
      visit_place([{PID, Ref, MRef} | L], Probs);
    {end_visit, PID, Ref} ->
      case [MR || {Pid, _, MR} <- L, Pid =:= PID] of
        [MRef] ->
          demonitor(MRef),
          visit_place(set_subtract(L, [{PID, Ref, MRef}]), Probs);
        _ -> visit_place(L, Probs)
      end;
    {'DOWN', MRef, process, PidExit, Reason} ->
      case [{R, MR} || {Pid, R, MR} <- L, Pid =:= PidExit] of
        [{Ref, MRef}] ->
          io:format("[Luogo] ~p Utente ~p con Ref  ~p morto per ~p ~n", [self(), PidExit, Ref, Reason]),
          visit_place(set_subtract(L, [{PidExit, Ref, MRef}]), Probs);
        _ ->
          io:format("[Luogo] ~p Utente ~p non presente in lista~n", [self(), PidExit]),
          visit_place(L, Probs)
      end
  end.

%%%%%%%%%%%%%%%%%%%%%%%%%%% PROTOCOLLO DI RILEVAMENTO DEI CONTATTI %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
contact(NewUser, PidOldUser, Prob) ->
  case Prob() of
    true ->
      NewUser ! {contact, PidOldUser},
      io:format("[Luogo] ~p Contatto da ~p a ~p~n", [self(), NewUser, PidOldUser]);
    false -> ok
  end.

%%%%%%%%%%%%%%%%%%%%%%%%%%% CICLO DI VITA %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
check_for_closing(Prob) ->
  case Prob() of
    true -> exit(normal);
    false -> ok
  end.

get_probs() ->
  Probs = #{contact_tracing => make_probability(25), check_for_closing => make_probability(10)},
  fun(X) ->
    maps:get(X, Probs)
  end.

luogo() ->
  io:format("Io sono il luogo ~p~n", [self()]),
  init_luogo(get_probs()).

start() ->
  [spawn(fun luogo/0) || _ <- lists:seq(1, 1000)].