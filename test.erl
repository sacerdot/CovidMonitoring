-module(test).
-export([test/0]).



create_users(Num) ->
    case Num of
        0 -> ok;
        _ ->    %spawn(users, users_init, []),
                spawn(usersnew, users_init, []),
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
    spawn(server, server_init, []), %la server_init fa ache lei la spown del server, forse qui basta fare la chiamata alla server init
    util:sleep(1000),
    hospital:hospital_init(),
    create_places(10),
%    sleep(5000),
    create_users(10).
