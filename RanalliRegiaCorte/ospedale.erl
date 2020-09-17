-module(ospedale).
-export([start/0]).
  
  
%protocollo di test  
risposta_positivita()->
	receive {test_me, PID}->io:format("L'utente ~p sta effettuando il tampone", [PID]),
							Pos=rand:uniform(4),
							 case Pos of
								1 -> io:format(" -> È POSITIVO ~n"), PID ! {positive};
								_ -> io:format(" -> È NEGATIVO ~n"), PID ! {negative}
							end
	end,						
	risposta_positivita().


%protocollo di mantenimento topologia
start() ->
  io:format("Io sono l'ospedale~n",[]),
  global:register_name(hospital, self()),
  risposta_positivita().