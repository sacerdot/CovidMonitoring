-module(users).
-export([users_init/0, timer_visit/1]).


get_list(_, List ,  0) -> List;
get_list([], List, _) -> io:format("Non abbiamo più posti ~n"),  List ;
get_list(Places, List, N) ->
   % io:format("In get list il ~p places è : ~p e list è ~p ~n",[N, Places, List]),
   X = lists:nth(rand:uniform(length(Places)), Places),
   monitor(process,X),
   get_list(Places -- [X], [X|List], N - 1).   %controllare che non viene tolto dal server

fget_places(N, UPlaces) ->
  %io:format("In fget places il mio pid è : ~p~n",[self()]),
  global:send(server, {get_places, self()}),
  receive
    {places, Places} ->
      % io:format("In fget_places ~p c'è la lista: ~p~n",[N, UPlaces]),
      % io:format("places - UPlaces ~p~n", [Places -- UPlaces] ),
      get_list(Places -- UPlaces, UPlaces, N)   %meglio lista vuota qui o UPlaces?
  end.

timer_visit(Pid) -> receive after crypto:rand_uniform(3000,5000) -> Pid ! {usr_start_vist} end.   %PROBLEMA?

sleep() -> receive after crypto:rand_uniform(5000,10000) -> ok end.   %Problema?

make_visit(UPlaces) ->
  Ref = make_ref(),
  Place = lists:nth(rand:uniform(length(UPlaces)), UPlaces),
  io:format("Io ~p Vognlio visitare il luogo ~p con ref ~p~n", [self(), Place, Ref]),
  Place ! {begin_visit, self(), Ref},
  sleep(),
  Place ! {end_visit, self(), Ref}.

user(UPlaces) ->
  io:format("Places in User ~p~n",[UPlaces]),
  %io:format("In user il mio pid è : ~p~n",[self()]),
  spawn(?MODULE, timer_visit, [self()]),
  receive
    {'DOWN', _ , process, Pid, _ } ->
      io:format("Qualcuno è morto :( ~p~n",[Pid]),
      user(fget_places(1, UPlaces -- [Pid]));
    {usr_start_vist} -> make_visit(UPlaces), user(UPlaces)

  end.


users_init() ->
  global:send(server, {new_usr, self()}),
  user(fget_places(3, [])).
