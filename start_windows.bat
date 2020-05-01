werl -compile central_server.erl
werl -compile hospital.erl
start cmd /k "erl -noshell -s hospital run"
erl -noshell -s central_server run
