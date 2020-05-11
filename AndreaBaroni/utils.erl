-module(utils).
-export([controlla/1,remove_dups/1]).


controlla(Pid) when not erlang:is_pid(Pid) -> false; 
controlla(Pid) when erlang:is_pid(Pid) -> %controlla che il processo avente pid Pid risponda
    Ref = erlang:make_ref(),
    Pid ! {ping,Ref,self()},
    receive
        {pong,Ref} -> io:format("Ho ricevuto true ~n"), true
    after 4000 -> false
    end.

remove_dups([])    -> []; % rimuove i duplicati da una lista
remove_dups([H|T]) -> [H | [X || X <- remove_dups(T), X /= H]].

delete_all2(L1,L2)->remove_dups(L2) -- remove_dups(L1). %restituisce una lista dove tutti gli elementi di L1 presenti in L2 vengono eliminati