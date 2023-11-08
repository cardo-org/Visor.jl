using Visor
using Sockets

# Require a tcp server accepting connection on port 8800, for example:
# 
#   socat TCP-LISTEN:8800,reuseaddr,pf=ip4,fork -
#

function main(self)
    sock = connect(8800)

    while true
        write(sock, "hello world\n")
        sleep(2)
    end
end

tasks = [process("tcpclient", main; debounce_time=0.5)]

supervise(tasks; intensity=2, period=1)