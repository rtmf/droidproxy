#include <sys/select.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#define BUFSIZE 16384
#define ARG_COUNT 4
#ifndef MAX
#define MAX(a,b) (a>b?a:b)
#endif
#define RD(ep) if (FD_ISSET(ep.socket,&rd)) ep_rd(&ep);
#define WR(ep) if (FD_ISSET(ep.socket,&wr)) ep_wr(&ep);
#define FD(ep) if (ep.to->bytes<BUFSIZE) FD_SET(ep.socket,&rd); if (ep.bytes>0) FD_SET(ep.socket,&wr);
int die(char * why, int how)
{
	write(2,why,strlen(why));
	write(2,"\n",strlen("\n"));
	exit(how);
}
void usage()
{
	die("Usage: proxy server_port remote_ip4 remote_port",1);
}
struct _endpoint;
typedef struct _endpoint {
	int socket;
	struct sockaddr_in addr;
	char buffer[BUFSIZE];
	int bytes;
	char * name;
	char * host;
	int port;
	struct _endpoint * to;
} endpoint;
void ep_rd(endpoint * ep)
{
	int ret;
	ret=read(ep->socket,&(ep->to->buffer),BUFSIZE-ep->to->bytes);
	if (ret<0)
	{
		fprintf(stderr,"Error reading from %s for %s.\n",ep->name,ep->to->name);
		die("ep_rd",7);
	}
	else
		printf("Buffered %d bytes from %s for %s.\n",ret,ep->name,ep->to->name);
	ep->to->bytes+=ret;
}
void ep_wr(endpoint * ep)
{
	int ret;
	ret=write(ep->socket,ep->buffer,ep->bytes);
	if (ret<0)
	{
		fprintf(stderr,"Error writing to %s.\n",ep->name);
		die("ep_rd",8);
	}
	else
		printf("Wrote %d bytes to %s of %d buffered.\n",ret,ep->name,ep->bytes);
	ep->bytes-=ret;
	memmove(ep->buffer,&(ep->buffer[ret]),ep->bytes);
}
int main (int argc, char * argv[])
{
	endpoint server,
					 client,
					 remote;
	fd_set rd,wr,ex;
	socklen_t size;
	struct timeval tv;
	int ret;
	if (argc != ARG_COUNT)
		usage();
	server.socket=socket(AF_INET,SOCK_STREAM,IPPROTO_TCP);
	server.addr.sin_family=AF_INET;
	server.addr.sin_addr.s_addr=INADDR_ANY;
	server.addr.sin_port=htons(atoi(argv[1]));
	server.name="server";
	server.bytes=0;
	server.port=server.addr.sin_port;
	server.host="0.0.0.0";
	if (bind(server.socket,(struct sockaddr *)&server.addr, sizeof(server.addr))<0)
		die("Could not bind socket",2);
	listen(server.socket,3);
	while (1)
	{
		size=sizeof(client.addr);
		FD_ZERO(&rd);
		FD_ZERO(&wr);
		FD_ZERO(&ex);
		FD_SET(server.socket,&rd);
		tv.tv_sec=60;
		tv.tv_usec=5;
		ret=select(server.socket+1,&rd,&wr,&ex,&tv);
		if (ret<0)
			die("Server select failed.",3);
		if (ret>0)
		{
			printf("Connecting client...\n");
			client.socket=accept(server.socket,(struct sockaddr *)&client.addr, &size);
			client.name="client";
			client.host="unknown";
			client.port=0;
			client.bytes=0;
			client.to=&remote;
			if (client.socket<=0)
				die("Accept failed.",4);
			if (fork()==0)
			{
				printf("Connected client...\n");
				remote.socket=socket(AF_INET,SOCK_STREAM,IPPROTO_TCP);
				remote.addr.sin_family=AF_INET;
				remote.addr.sin_addr.s_addr=inet_addr(argv[2]);
				remote.addr.sin_port=htons(atoi(argv[3]));
				remote.name="remote";
				remote.host=argv[2];
				remote.port=remote.addr.sin_port;
				remote.bytes=0;
				remote.to=&client;
				if (connect(remote.socket,(struct sockaddr *)&remote.addr, sizeof(remote.addr))<0)
					die("Could not connect to remote",5);
				while(1)
				{
					FD_ZERO(&rd);
					FD_ZERO(&wr);
					FD_ZERO(&ex);
					FD(client);
					FD(remote);
					tv.tv_sec=60;
					tv.tv_usec=5;
					ret=select(MAX(client.socket,remote.socket)+1,&rd,&wr,&ex,&tv);
					if (ret<0)
						die("Client select failed.",6);
					if (ret>0)
					{	
						RD(client);
						RD(remote);
						WR(client);
						WR(remote);
					}
				}
			}
		}
	}
}
