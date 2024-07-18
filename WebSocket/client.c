// client.c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>

int main() {
    int sockfd;
    struct sockaddr_in serv_addr;
    char buffer[1024] = {0};

    // 创建 socket
    if ((sockfd = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
        printf("\n Socket creation error \n");
        return -1;
    }

    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(8080);

    // 将地址转换为二进制表单
    if (inet_pton(AF_INET, "127.0.0.1", &serv_addr.sin_addr) <= 0) {
        printf("\nInvalid address/Address not supported \n");
        return -1;
    }

    // 连接到服务器
    if (connect(sockfd, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0) {
        printf("\nConnection Failed \n");
        return -1;
    }

    // 发送消息
    send(sockfd, "Hello from client", strlen("Hello from client"), 0);
    printf("Hello message sent\n");

    // 接收消息
    read(sockfd, buffer, 1024);
    printf("Message from server: %s\n", buffer);

    // 关闭 socket
    close(sockfd);
    return 0;
}
//emcc client.c -o client.html -s USE_PTHREADS=1 -s PROXY_TO_PTHREAD -s OFFSCREENCANVAS_SUPPORT=1