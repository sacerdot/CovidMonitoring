-module(hospital).
-export([hospital_init/0, hospital/0]).

hospital() ->
    % io:format("Stiamo nell'ospedale ~n"),
    receive
        {test_me, Pid_User} ->
            case util:probability(4) of
                true -> Pid_User ! {test_result, positive};
                false -> Pid_User ! {test_result, negative}
            end
    end,
    hospital().   %la facciamo qui o nel recive?

hospital_init() ->
    % ci dobbiamo linkare al server?
    HospitalPid = spawn(?MODULE, hospital, []),
    global:register_name(hospital,HospitalPid).
