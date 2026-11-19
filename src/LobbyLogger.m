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

#define MAX_TRACK_FDS 4096
static int  g_candidate_ports[MAX_TRACK_FDS] = {0};
static char g_candidate_ips[MAX_TRACK_FDS][48] = {{0}};

static void ensure_doc_path(void) {
    if (!g_doc_path[0]) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        if ([paths count] > 0) {
            strncpy(g_doc_path, [[paths objectAtIndex:0] UTF8String], sizeof(g_doc_path) - 1);
        }
    }
}

static void init_logger(void) {
    ensure_doc_path();
    if (g_doc_path[0]) {
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

static void dump_traffic_bytes(const char *direction, int sockfd, int port, const char *ip, const void *buf, size_t len) {
    if (!buf || len == 0) return;
    
    char hex_preview[256] = {0};
    const unsigned char *p = (const unsigned char *)buf;
    size_t preview_len = len < 32 ? len : 32;
    for (size_t i = 0; i < preview_len; i++) {
        snprintf(hex_preview + strlen(hex_preview), sizeof(hex_preview) - strlen(hex_preview), "%02X ", p[i]);
    }
    
    // Kiểm tra có Opcode đăng nhập 1802 (0x070A) hoặc 1810 (0x0712) không
    BOOL isLoginReq = NO;
    BOOL isLoginRsp = NO;
    for (size_t i = 0; i + 3 < len; i++) {
        uint32_t val = (p[i] << 24) | (p[i+1] << 16) | (p[i+2] << 8) | p[i+3];
        if (val == 1802) isLoginReq = YES;
        if (val == 1810) isLoginRsp = YES;
    }
    
    if (isLoginReq) {
        write_log("[>>> LOBBY_LOGIN_REQ (1802) <<<] %s fd=%d (%s:%d) Len=%zu | Hex: %s", direction, sockfd, ip, port, len, hex_preview);
    } else if (isLoginRsp) {
        write_log("[>>> LOBBY_LOGIN_RSP (1810) <<<] %s fd=%d (%s:%d) Len=%zu | Hex: %s", direction, sockfd, ip, port, len, hex_preview);
    } else {
        write_log("[%s -> %s:%d] fd=%d Len=%zu | Hex: %s", direction, ip, port, sockfd, len, hex_preview);
    }
    
    // Lưu raw nhị phân ra file để phân tích giao thức
    ensure_doc_path();
    if (g_doc_path[0]) {
        char dump_path[1200];
        snprintf(dump_path, sizeof(dump_path), "%s/traffic_%s_%d.bin", g_doc_path, direction, port);
        FILE *df = fopen(dump_path, "ab");
        if (df) {
            fwrite(buf, 1, len, df);
            fflush(df);
            fclose(df);
        }
    }
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
                if (sockfd >= 0 && sockfd < MAX_TRACK_FDS) {
                    g_candidate_ports[sockfd] = port;
                    strncpy(g_candidate_ips[sockfd], ip_str, sizeof(g_candidate_ips[sockfd]) - 1);
                }
                
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
// 2. Hook send() & sendto() & write()
// -----------------------------------------------------------------------------
static ssize_t my_send(int sockfd, const void *buf, size_t len, int flags) {
    if (sockfd >= 0 && sockfd < MAX_TRACK_FDS && g_candidate_ports[sockfd] > 0) {
        dump_traffic_bytes("SEND", sockfd, g_candidate_ports[sockfd], g_candidate_ips[sockfd], buf, len);
    }
    return send(sockfd, buf, len, flags);
}
DYLD_INTERPOSE(my_send, send);

static ssize_t my_sendto(int sockfd, const void *buf, size_t len, int flags, const struct sockaddr *dest_addr, socklen_t addrlen) {
    if (sockfd >= 0 && sockfd < MAX_TRACK_FDS && g_candidate_ports[sockfd] > 0) {
        dump_traffic_bytes("SENDTO", sockfd, g_candidate_ports[sockfd], g_candidate_ips[sockfd], buf, len);
    }
    return sendto(sockfd, buf, len, flags, dest_addr, addrlen);
}
DYLD_INTERPOSE(my_sendto, sendto);

static ssize_t my_write(int fd, const void *buf, size_t count) {
    if (fd >= 0 && fd < MAX_TRACK_FDS && g_candidate_ports[fd] > 0) {
        dump_traffic_bytes("WRITE", fd, g_candidate_ports[fd], g_candidate_ips[fd], buf, count);
    }
    return write(fd, buf, count);
}
DYLD_INTERPOSE(my_write, write);

// -----------------------------------------------------------------------------
// 3. Hook recv() & recvfrom() & read()
// -----------------------------------------------------------------------------
static ssize_t my_recv(int sockfd, void *buf, size_t len, int flags) {
    ssize_t ret = recv(sockfd, buf, len, flags);
    if (ret > 0 && sockfd >= 0 && sockfd < MAX_TRACK_FDS && g_candidate_ports[sockfd] > 0) {
        dump_traffic_bytes("RECV", sockfd, g_candidate_ports[sockfd], g_candidate_ips[sockfd], buf, ret);
    }
    return ret;
}
DYLD_INTERPOSE(my_recv, recv);

static ssize_t my_recvfrom(int sockfd, void *buf, size_t len, int flags, struct sockaddr *src_addr, socklen_t *addrlen) {
    ssize_t ret = recvfrom(sockfd, buf, len, flags, src_addr, addrlen);
    if (ret > 0 && sockfd >= 0 && sockfd < MAX_TRACK_FDS && g_candidate_ports[sockfd] > 0) {
        dump_traffic_bytes("RECVFROM", sockfd, g_candidate_ports[sockfd], g_candidate_ips[sockfd], buf, ret);
    }
    return ret;
}
DYLD_INTERPOSE(my_recvfrom, recvfrom);

static ssize_t my_read(int fd, void *buf, size_t count) {
    ssize_t ret = read(fd, buf, count);
    if (ret > 0 && fd >= 0 && fd < MAX_TRACK_FDS && g_candidate_ports[fd] > 0) {
        dump_traffic_bytes("READ", fd, g_candidate_ports[fd], g_candidate_ips[fd], buf, ret);
    }
    return ret;
}
DYLD_INTERPOSE(my_read, read);

// -----------------------------------------------------------------------------
// 4. Hook close() để dọn dẹp fd tracking
// -----------------------------------------------------------------------------
static int my_close(int fd) {
    if (fd >= 0 && fd < MAX_TRACK_FDS) {
        g_candidate_ports[fd] = 0;
        g_candidate_ips[fd][0] = '\0';
    }
    return close(fd);
}
DYLD_INTERPOSE(my_close, close);

__attribute__((constructor))
static void entry(void) {
    init_logger();
    write_log("[LOBBY_LOGGER] Sniffer v2.0 initialized (All Socket IO hooked).");
}
