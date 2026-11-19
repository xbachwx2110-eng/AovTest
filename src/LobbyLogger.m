/*
 * LobbyLogger.m - Tự động bắt IP, Port và dump gói tin đăng nhập Lobby Liên Quân Mobile
 * Tương thích 100% mọi iOS (Jailbroken & Non-Jailbroken / Sideload qua ESign, Feather, Sideloadly, TrollStore)
 * Không phụ thuộc thư viện ngoài (sử dụng dyld interposing + runtime C).
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <dlfcn.h>
#include <pthread.h>
#include <stdio.h>
#include <string.h>

#ifndef DYLD_INTERPOSE
#define DYLD_INTERPOSE(_replacement, _replacee) \
   __attribute__((used)) static const struct { const void* replacement; const void* replacee; } _interpose_##_replacee \
            __attribute__((section ("__DATA,__interpose"))) = { (const void*)(unsigned long)&_replacement, (const void*)(unsigned long)&_replacee };
#endif

static NSString * const kLobbyLoggerNotification = @"kLobbyLoggerNotification";

static FILE *g_log_file = NULL;
static pthread_mutex_t g_log_mutex = PTHREAD_MUTEX_INITIALIZER;
static char g_doc_path[1024] = {0};

static void init_logger(void) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if ([paths count] > 0) {
        NSString *docDir = [paths objectAtIndex:0];
        strncpy(g_doc_path, [docDir UTF8String], sizeof(g_doc_path) - 1);
        
        char log_filepath[1200];
        snprintf(log_filepath, sizeof(log_filepath), "%s/lobby_traffic.log", g_doc_path);
        
        g_log_file = fopen(log_filepath, "a+");
        if (g_log_file) {
            fprintf(g_log_file, "\n========================================\n");
            fprintf(g_log_file, "[LOBBY_LOGGER] Khoi dong thanh cong luc %s\n", [[NSDate date] description].UTF8String);
            fprintf(g_log_file, "========================================\n");
            fflush(g_log_file);
        }
    }
}

static void notify_ui_log(NSString *logMsg, BOOL isLobby, NSString *endpoint) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        if (logMsg) dict[@"log"] = logMsg;
        dict[@"is_lobby"] = @(isLobby);
        if (endpoint) dict[@"endpoint"] = endpoint;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kLobbyLoggerNotification
                                                            object:nil
                                                          userInfo:dict];
    });
}

static void write_log(const char *fmt, ...) {
    char buffer[2048] = {0};
    va_list args;
    va_start(args, fmt);
    vsnprintf(buffer, sizeof(buffer), fmt, args);
    va_end(args);

    pthread_mutex_lock(&g_log_mutex);
    if (!g_log_file) {
        init_logger();
    }
    if (g_log_file) {
        fprintf(g_log_file, "%s\n", buffer);
        fflush(g_log_file);
    }
    pthread_mutex_unlock(&g_log_mutex);

    NSString *msg = [NSString stringWithUTF8String:buffer];
    notify_ui_log(msg, NO, nil);
}

// -----------------------------------------------------------------------------
// 1. Hook BSD connect() để tóm mọi IP & Port máy chủ kết nối tới
// -----------------------------------------------------------------------------
static int my_connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen) {
    if (addr && addr->sa_family == AF_INET) {
        const struct sockaddr_in *sin = (const struct sockaddr_in *)addr;
        char ip_str[INET_ADDRSTRLEN] = {0};
        inet_ntop(AF_INET, &(sin->sin_addr), ip_str, INET_ADDRSTRLEN);
        int port = ntohs(sin->sin_port);

        // Bỏ qua loopback và DNS nội bộ
        if (strcmp(ip_str, "127.0.0.1") != 0) {
            BOOL isCandidate = (port != 80 && port != 443 && port != 53);
            if (isCandidate) {
                char candidateMsg[512];
                snprintf(candidateMsg, sizeof(candidateMsg), "[>>> LOBBY CANDIDATE <<<] Phat hien ket noi toi: %s:%d", ip_str, port);
                
                pthread_mutex_lock(&g_log_mutex);
                if (g_log_file) {
                    fprintf(g_log_file, "%s\n", candidateMsg);
                    fflush(g_log_file);
                }
                pthread_mutex_unlock(&g_log_mutex);
                
                NSString *endpoint = [NSString stringWithFormat:@"%s:%d", ip_str, port];
                notify_ui_log([NSString stringWithUTF8String:candidateMsg], YES, endpoint);
            } else {
                write_log("[CONNECT] Socket fd=%d -> IP: %s | Port: %d", sockfd, ip_str, port);
            }
        }
    }
    return connect(sockfd, addr, addrlen);
}
DYLD_INTERPOSE(my_connect, connect);

// -----------------------------------------------------------------------------
// 2. Hook send() để tóm gói tin CSPKG_CMD_GAMELOGINREQ (Opcode 1802 / 0x070A)
// -----------------------------------------------------------------------------
static ssize_t my_send(int sockfd, const void *buf, size_t len, int flags) {
    if (buf && len >= 16) {
        const unsigned char *p = (const unsigned char *)buf;
        uint32_t msg_id = (p[0] << 24) | (p[1] << 16) | (p[2] << 8) | p[3];
        uint32_t seq    = (p[4] << 24) | (p[5] << 16) | (p[6] << 8) | p[7];
        uint32_t bodylen= (p[12] << 24) | (p[13] << 16) | (p[14] << 8) | p[15];

        // 1802 = 0x070A = CSPKG_CMD_GAMELOGINREQ
        if (msg_id == 1802) {
            write_log("=======================================================");
            write_log("[SEND] Bat duoc CSPKG_CMD_GAMELOGINREQ (1802 / 0x070A)!");
            write_log("  - Tong bytes: %zu, BodyLen: %u, Seq: %u", len, bodylen, seq);
            
            char hex_buf[512] = {0};
            size_t dump_len = len < 64 ? len : 64;
            for (size_t i = 0; i < dump_len; i++) {
                snprintf(hex_buf + strlen(hex_buf), sizeof(hex_buf) - strlen(hex_buf), "%02X ", p[i]);
            }
            write_log("  - Raw Hex (dau %zu bytes): %s", dump_len, hex_buf);

            if (g_doc_path[0]) {
                char dump_path[1200];
                snprintf(dump_path, sizeof(dump_path), "%s/gameloginreq.bin", g_doc_path);
                FILE *df = fopen(dump_path, "wb");
                if (df) {
                    fwrite(buf, 1, len, df);
                    fclose(df);
                    write_log("  - Da luu tron goi tin ra: Documents/gameloginreq.bin");
                }
            }
            write_log("=======================================================");
        } else if (msg_id > 1000 && msg_id < 3000) {
            write_log("[SEND GAME PKT] MsgID: %u (0x%04X), Len: %zu", msg_id, msg_id, len);
        }
    }
    return send(sockfd, buf, len, flags);
}
DYLD_INTERPOSE(my_send, send);

// -----------------------------------------------------------------------------
// 3. Hook recv() để tóm phản hồi từ Lobby (SCPKG_CMD_GAMELOGINRSP 1810 / 0x0712)
// -----------------------------------------------------------------------------
static ssize_t my_recv(int sockfd, void *buf, size_t len, int flags) {
    ssize_t ret = recv(sockfd, buf, len, flags);
    if (ret >= 16 && buf) {
        const unsigned char *p = (const unsigned char *)buf;
        uint32_t msg_id = (p[0] << 24) | (p[1] << 16) | (p[2] << 8) | p[3];
        if (msg_id == 1810) {
            write_log("[RECV] >>> SCPKG_CMD_GAMELOGINRSP (1810 / 0x0712 - LOGIN THANH CONG!) <<<");
        } else if (msg_id == 1812) {
            write_log("[RECV] >>> SCPKG_CMD_GAMELOGINLIMIT (1812 / 0x0714 - GIOI HAN/BAO TRI) <<<");
        } else if (msg_id == 1799) {
            write_log("[RECV] >>> SCPKG_LOGIN_REDIRECT_NTY (1799 / 0x0707 - CHUYEN HUONG SERVER) <<<");
        }
    }
    return ret;
}
DYLD_INTERPOSE(my_recv, recv);

__attribute__((constructor))
static void entry(void) {
    init_logger();
    write_log("[LOBBY_LOGGER] Sniffer initialized successfully.");
}
