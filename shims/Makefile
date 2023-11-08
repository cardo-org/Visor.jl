JL_BIN = $(shell julia --startup-file=no -e 'print(Sys.BINDIR)')

JL_SHARE = $(shell julia  --startup-file=no -e 'print(joinpath(Sys.BINDIR, Base.DATAROOTDIR, "julia"))')
#JL_SHARE = "/opt/julia-1.7.2/share/julia"

CFLAGS   += $(shell $(JL_SHARE)/julia-config.jl --cflags)
#CFLAGS += -std=gnu99 -I'$(JULIA_HOME)/include/julia' -fPIC

LDFLAGS  += $(shell $(JL_SHARE)/julia-config.jl --ldflags)
#LDFLAGS  += -L'$(JULIA_HOME)/lib' -Wl,--export-dynamic

LDLIBS   += $(shell $(JL_SHARE)/julia-config.jl --ldlibs)
#LDLIBS   += -Wl,-rpath,'$(JULIA_HOME)/lib' -Wl,-rpath,'$(JULIA_HOME)/lib/julia' -ljulia

LDLIBS   += -lpthread -ldl

#CFLAGS += -std=gnu99 -I'/opt/julia-1.6.1/include/julia' -fPIC
#LDFLAGS  += -L'/opt/julia-1.6.1/lib' -Wl,--export-dynamic
#LDLIBS   += -Wl,-rpath,'/opt/julia-1.6.1/lib' -Wl,-rpath,'/opt/julia-1.6.1/lib/julia' -ljulia -lpthread -ldl 

# For: /usr/bin/ld: warning: type and size of dynamic symbol `jl_init__threading' are not defined
# see
# https://github.com/JuliaLang/julia/pull/40575
all: visor sigvisor

visor: visor.c
	cc $(CFLAGS) $(LDFLAGS) $^ $(LDLIBS) -o $@

sigvisor:
	gcc sigvisor.c -o sigvisor

visor.so:
	./create_sysimage.sh $(SKIP_DB_INIT)

clean:
	rm -f visor sigvisor

install: visor sigvisor
	cp visor sigvisor $(JL_BIN)