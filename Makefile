all: proxy

%.o: %.c
	gcc -c $< -o $@

proxy: proxy.o
	gcc $^ -o $@
