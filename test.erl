-module(test).
-export([test/0]).

sleep(N) -> receive after N -> ok end.



% user(REF) ->
%     sleep(rand:uniform(1000)),
%     global:send(server, {get_places, self()}),
%     receive
%         {places, Places} -> io:format("User ~p receive places: ~p~n", [self(),Places]),
%                             case Places of
%                                 [H|_] ->
%                                     sleep(rand:uniform(1000)),
%                                     H ! {begin_visit, self(), REF},
%                                     receive
%                                         {contact, User_Pid} -> io:format("Io (~p) contatto con ~p~n", [self(), User_Pid])
%                                     after 5000 ->
%                                         H ! {end_visit, self(), REF}
%                                     end;
%                                 [] -> ok
%                             end
%     end.

create_users(Num) ->
    case Num of
        0 -> ok;
        _ ->    spawn(users, users_init, []),
                create_users(Num-1)
    end.

create_places(Num) ->
    case Num of
        0 -> ok;
        _ ->    spawn(places, place_init, []),
                create_places(Num-1)
    end.

test() ->
%    Luogo = spawn(?MODULE, place_init, []),
%    register(luogo, Luogo),
    spawn(server, server_init, []),
    create_places(3),
    create_users(10).
