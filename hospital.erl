-module(hospital).
-export([hospital_init/0, hospital/0]).

hospital() ->
    receive
        {test_me, Pid_User} ->
            case util:probability(4) of
                true -> Pid_User ! {test_result, positive}; 
                false -> Pid_User ! {test_result, negative}
            end
    end,
    hospital().  

%Vedere l'interfaccia del prof, se dobbiamo fare una funzione start, fare la spawn dell'hospital lì non qui.
hospital_init() ->
    HospitalPid = spawn_link(?MODULE, hospital, []),
    ServerPid = global:whereis_name(server),
    link(ServerPid),
    global:register_name(hospital,HospitalPid).
