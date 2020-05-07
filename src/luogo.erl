-module(luogo).
-export([main/0, init_luogo/0, visit_place/1, sleep/1, user/1]).
-import(server, [init/1]).

sleep(T) ->
  receive after T -> ok end.

init_luogo() ->
   PID = global:whereis_name(server),
   case PID of 
       undefined -> exit(server_not_registered);
       P -> link(P)
   end,
   global:send(server, {new_place, self()}),
   visit_place([]).

visit_place(L) ->
    io:format("[Luogo] Utenti nel luogo: ~p ~n", [L]),
    receive 
        {begin_visit, PID, Ref} ->
            % {Pid, Ref} vs Ref (a cosa serve Ref? Forse perché utente in macchine diverse
            %hanno lo stesso Pid, ma Ref diversi)
            contact_tracing({PID, Ref} , L),
            visit_place([{PID, Ref} | L]);
        {end_visit, PID, Ref} -> 
            visit_place(lists:delete({PID, Ref}, L))
    end.

contact_tracing(_, []) -> ok;
contact_tracing(NewUser = {U, _}, [{P, _} | T]) ->  
    io:format("[Luogo] Lancio del dado per il contatto del nuovo utente ~p ~n", [NewUser]),
    case rand:uniform(4) of
        1 -> U ! {contact, P},
        io:format("[Luogo] Contatto avvenuto tra user nuovo ~p e ~p ~n", [U, P]);
        _ -> ok,
        io:format("[Luogo] Nessun contatto avvenuto tra user nuovo ~p e ~p ~n", [U, P])
    end,
    contact_tracing(NewUser, T).

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


