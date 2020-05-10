-module(luogo).
-export([main/0, init_luogo/0, visit_place/1, sleep/1, user/1, set_subtract/2]).
-import(server, [init/1]).

sleep(T) ->
  receive after T -> ok end.

set_subtract(L1, L2) ->
lists:filter(fun(X) -> not lists:member(X, L2) end, L1).

init_luogo() ->
   PID = global:whereis_name(server),
   case PID of 
       undefined -> exit(server_not_registered);
       P -> link(P)
   end,
   global:send(server, {new_place, self()}),
   visit_place([]).

visit_place(L) ->
    %io:format("[Luogo] ~p Utenti nel luogo: ~p ~n", [self(), L]),
    receive 
        {begin_visit, PID, Ref} ->
            contact_tracing(PID , [PidOldUser || {PidOldUser, _} <- L]),
            check_for_closing(),
            visit_place([{PID, Ref} | L]);
        {end_visit, PID, Ref} -> 
            %visit_place(lists:delete({PID, Ref}, L))
            visit_place(set_subtract(L, [{PID, Ref}]))
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
        1 -> exit(normal);
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


