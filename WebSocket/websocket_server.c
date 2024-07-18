// websocket_server.c
#include <libwebsockets.h>
#include <string.h>
#include <signal.h>

static int interrupted = 0;

static void sigint_handler(int sig) {
    interrupted = 1;
}

static int callback_echo(struct lws *wsi, enum lws_callback_reasons reason,
                    void *user, void *in, size_t len)
{
    switch (reason) {
        case LWS_CALLBACK_ESTABLISHED:
            lwsl_user("Connection established\n");
            break;

        case LWS_CALLBACK_RECEIVE:
            lwsl_user("Received data: %s\n", (char *)in);
            lws_write(wsi, (unsigned char *)in, len, LWS_WRITE_TEXT);
            break;

        case LWS_CALLBACK_CLOSED:
            lwsl_user("Connection closed\n");
            break;

        default:
            break;
    }
    return 0;
}

static struct lws_protocols protocols[] = {
    {
        "echo-protocol",
        callback_echo,
        0,
        128,
    },
    { NULL, NULL, 0, 0 } /* terminator */
};

int main(void) {
    struct lws_context_creation_info info;
    struct lws_context *context;

    signal(SIGINT, sigint_handler);

    memset(&info, 0, sizeof info);
    info.port = 8080;
    info.protocols = protocols;
    info.options = LWS_SERVER_OPTION_DO_SSL_GLOBAL_INIT;

    context = lws_create_context(&info);
    if (!context) {
        lwsl_err("lws init failed\n");
        return -1;
    }

    lwsl_user("WebSocket server listening on port 8080\n");

    while (!interrupted) {
        lws_service(context, 1000);
    }

    lws_context_destroy(context);

    return 0;
}
//gcc websocket_server.c -o websocket_server -lwebsockets