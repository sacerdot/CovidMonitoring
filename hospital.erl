-module(hospital).
-export([hospital_init/0, hospital/0]).

hospital() ->
    % io:format("Stiamo nell'ospedale ~n"),
    receive
        {test_me, Pid_User} ->
            case util:probability(4) of
                true -> Pid_User ! {test_result, negative}; %forse bisogna fare solo positive o negative TODO rimetti positive
                false -> Pid_User ! {test_result, negative}
            end
    end,
    hospital().   %la facciamo qui o nel recive?

%Vedere l'interfaccia del prof, se dobbiamo fare una funzione start, fare la spawn dell'hospital lì non qui.
hospital_init() ->
    % ci dobbiamo linkare al server?
    HospitalPid = spawn_link(?MODULE, hospital, []),
    ServerPid = global:whereis_name(server),
    link(ServerPid),
    global:register_name(hospital,HospitalPid).
