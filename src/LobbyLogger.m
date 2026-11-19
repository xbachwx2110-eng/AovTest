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
            fprintf(g_log_file, "\n\n========================================\n");
            fprintf(g_log_file, "[LOBBY_LOGGER] Khoi dong thanh cong luc %s\n", [[NSDate date] description].UTF8String);
            fprintf(g_log_file, "========================================\n");
            fflush(g_log_file);
        }
    }
}

static void write_log(const char *fmt, ...) {
    pthread_mutex_lock(&g_log_mutex);
    if (!g_log_file) {
        init_logger();
    }
    if (g_log_file) {
        va_list args;
        va_start(args, fmt);
        vfprintf(g_log_file, fmt, args);
        va_end(args);
        fprintf(g_log_file, "\n");
        fflush(g_log_file);
    }
    pthread_mutex_unlock(&g_log_mutex);
}

static void show_on_screen_toast(NSString *msg) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) {
            NSArray *windows = [UIApplication sharedApplication].windows;
            if (windows.count > 0) window = windows[0];
        }
        if (window) {
            UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 50, window.bounds.size.width - 40, 60)];
            label.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.85];
            label.textColor = [UIColor colorWithRed:0.2 green:1.0 blue:0.4 alpha:1.0];
            label.textAlignment = NSTextAlignmentCenter;
            label.font = [UIFont boldSystemFontOfSize:13];
            label.numberOfLines = 2;
            label.layer.cornerRadius = 8;
            label.layer.masksToBounds = YES;
            label.layer.borderWidth = 1.5;
            label.layer.borderColor = [UIColor greenColor].CGColor;
            label.text = msg;
            [window addSubview:label];
            
            [UIView animateWithDuration:0.5 delay:7.0 options:0 animations:^{
                label.alpha = 0;
            } completion:^(BOOL finished) {
                [label removeFromSuperview];
            }];
        }
    });
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
            write_log("[CONNECT] Socket fd=%d -> IP: %s | Port: %d", sockfd, ip_str, port);
            
            // Nếu phát hiện kết nối game (port không phải 80/443/53 thường là Lobby hoặc TDir)
            if (port != 80 && port != 443 && port != 53) {
                write_log("[>>> LOBBY CANDIDATE <<<] Phat hien ket noi toi: %s:%d", ip_str, port);
                NSString *toastMsg = [NSString stringWithFormat:@"[Lobby Detected]\nIP: %s | Port: %d", ip_str, port];
                show_on_screen_toast(toastMsg);
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
        uint32_t svrseq = (p[8] << 24) | (p[9] << 16) | (p[10] << 8) | p[11];
        uint32_t bodylen= (p[12] << 24) | (p[13] << 16) | (p[14] << 8) | p[15];

        // 1802 = 0x070A = CSPKG_CMD_GAMELOGINREQ
        if (msg_id == 1802) {
            write_log("\n=======================================================");
            write_log("[SEND PACKET] Bat duoc CSPKG_CMD_GAMELOGINREQ (1802 / 0x070A)!");
            write_log("  - Tong byte: %zu, BodyLen: %u, Seq: %u", len, bodylen, seq);
            
            char hex_buf[4096] = {0};
            size_t dump_len = len < 512 ? len : 512;
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
                    write_log("  - Da luu tron goi tin ra: %s", dump_path);
                }
            }
            write_log("=======================================================\n");
            show_on_screen_toast(@"[CAPTURED]\nDa dump thanh cong CSPKG_CMD_GAMELOGINREQ!");
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
            write_log("[RECV] Bat duoc SCPKG_CMD_GAMELOGINRSP (1810 / 0x0712 - LOGIN THANH CONG)!");
            show_on_screen_toast(@"[LOGIN SUCCESS]\nNhan duoc phan hoi dang nhap thanh cong!");
        } else if (msg_id == 1812) {
            write_log("[RECV] Bat duoc SCPKG_CMD_GAMELOGINLIMIT (1812 / 0x0714 - GIOI HAN/BAO TRI)!");
        } else if (msg_id == 1799) {
            write_log("[RECV] Bat duoc SCPKG_LOGIN_REDIRECT_NTY (1799 / 0x0707 - CHUYEN HUONG SERVER)!");
        }
    }
    return ret;
}
DYLD_INTERPOSE(my_recv, recv);

__attribute__((constructor))
static void entry(void) {
    init_logger();
    write_log("[LOBBY_LOGGER] Constructor duoc goi. Hook dyld interpose da san sang.");
}
