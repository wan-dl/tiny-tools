#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <ctype.h>
#include "cJSON.h"

// ANSI color codes for pretty printing
static const char* COLOR_RESET   = "\033[0m";
static const char* COLOR_KEY     = "\033[1;34m";
static const char* COLOR_VALUE   = "\033[1;32m";
static const char* COLOR_NUMBER  = "\033[1;33m";
static const char* COLOR_BOOL    = "\033[1;35m";
static const char* COLOR_NULL    = "\033[1;36m";
static const char* COLOR_BRACE   = "\033[1;34m";

// 读取标准输入所有内容
char* read_stdin_all() {
    size_t size = 0, cap = 4096;
    char* buf = malloc(cap);
    int c;
    if (!buf) {
        fprintf(stderr, "Out of memory.\n");
        exit(1);
    }
    while ((c = getchar()) != EOF) {
        if (size + 1 >= cap) {
            cap *= 2;
            char* tmp = realloc(buf, cap);
            if (!tmp) {
                free(buf);
                fprintf(stderr, "Out of memory.\n");
                exit(1);
            }
            buf = tmp;
        }
        buf[size++] = c;
    }
    buf[size] = '\0';
    return buf;
}

// 读取文件所有内容
char* read_file_all(const char* filename) {
    FILE *fp = fopen(filename, "rb");
    if (!fp) {
        fprintf(stderr, "Failed to open file: %s\n", filename);
        return NULL;
    }
    fseek(fp, 0, SEEK_END);
    size_t fsize = (size_t)ftell(fp);
    fseek(fp, 0, SEEK_SET);
    char* buf = malloc(fsize + 1);
    if (!buf) {
        fclose(fp);
        fprintf(stderr, "Out of memory.\n");
        return NULL;
    }
    if (fread(buf, 1, fsize, fp) != fsize) {
        fclose(fp);
        free(buf);
        fprintf(stderr, "Failed to read file: %s\n", filename);
        return NULL;
    }
    buf[fsize] = '\0';
    fclose(fp);
    return buf;
}

// 去除json中的注释
char* strip_json_comments(const char* src) {
    size_t len = strlen(src);
    char* out = malloc(len + 1);
    if (!out) {
        fprintf(stderr, "Out of memory.\n");
        return NULL;
    }
    size_t i = 0, j = 0;
    bool in_str = false;
    while (i < len) {
        if (!in_str && src[i] == '/' && src[i + 1] == '/') {
            i += 2;
            while (src[i] && src[i] != '\n') i++;
        } else if (!in_str && src[i] == '/' && src[i + 1] == '*') {
            i += 2;
            while (src[i] && !(src[i] == '*' && src[i+1] == '/')) i++;
            if (src[i]) i += 2;
        } else {
            if (src[i] == '"' && (i == 0 || src[i - 1] != '\\')) in_str = !in_str;
            out[j++] = src[i++];
        }
    }
    out[j] = '\0';
    return out;
}

// 将json字符串中的tab缩进替换为4空格，冒号后tab替换为一个空格
char* beautify_json(const char* src) {
    size_t len = strlen(src);
    char* out = malloc(len * 4 + 1);
    if (!out) {
        fprintf(stderr, "Out of memory.\n");
        return NULL;
    }
    size_t i = 0, j = 0;
    while (src[i]) {
        if (src[i] == ':') {
            out[j++] = src[i++];
            if (src[i] == '\t') { out[j++] = ' '; i++; }
        } else if (src[i] == '\t') {
            memcpy(out + j, "    ", 4); j += 4; i++;
        } else {
            out[j++] = src[i++];
        }
    }
    out[j] = '\0';
    return out;
}

// 路径查找：支持多级 .a.b.c
cJSON* find_by_path(cJSON* root, const char* path) {
    char keybuf[256];
    cJSON *val = root, *tmp;
    const char *kstart = path, *kend;
    while (*kstart && val) {
        kend = strchr(kstart, '.');
        size_t klen = kend ? (size_t)(kend - kstart) : strlen(kstart);
        if (klen >= sizeof(keybuf)) klen = sizeof(keybuf) - 1;
        strncpy(keybuf, kstart, klen);
        keybuf[klen] = 0;
        tmp = cJSON_GetObjectItemCaseSensitive(val, keybuf);
        val = tmp;
        if (!kend) break;
        kstart = kend + 1;
    }
    return val;
}

// 输出带颜色的json字符串，key和value区分颜色
void print_colored_json(const char *json) {
    const char *p = json;
    int in_key = 0; // 0: 普通, 1: 期待key, 2: 期待value
    while (*p) {
        if (*p == '{' || *p == '[') {
            printf("%s%c%s", COLOR_BRACE, *p++, COLOR_RESET);
            in_key = (*p == '"') ? 1 : 0;
        } else if (*p == '}' || *p == ']') {
            printf("%s%c%s", COLOR_BRACE, *p++, COLOR_RESET);
            in_key = 0;
        } else if (*p == '"') { // 字符串
            int is_key = (in_key == 1);
            printf("%s", is_key ? COLOR_KEY : COLOR_VALUE);
            printf("%c", *p++);
            while (*p) {
                putchar(*p);
                if (*p == '"' && *(p-1) != '\\') {
                    p++;
                    break;
                }
                p++;
            }
            printf("%s", COLOR_RESET);
            if (is_key && *p == ':') { in_key = 2; }
            else if (!is_key) { in_key = 1; }
        } else if (*p == ':') {
            putchar(*p++);
        } else if (in_key == 2 && (isdigit(*p) || (*p == '-' && isdigit(*(p+1))))) { // 数字 value
            printf("%s", COLOR_NUMBER);
            while (isdigit(*p) || *p == '.' || *p == '-' || *p == 'e' || *p == 'E' || *p == '+')
                putchar(*p++);
            printf("%s", COLOR_RESET);
            in_key = 1;
        } else if (in_key == 2 && (!strncmp(p, "true", 4) || !strncmp(p, "false", 5))) { // 布尔 value
            printf("%s", COLOR_BOOL);
            if (!strncmp(p, "true", 4)) { printf("true"); p += 4; }
            else { printf("false"); p += 5; }
            printf("%s", COLOR_RESET);
            in_key = 1;
        } else if (in_key == 2 && !strncmp(p, "null", 4)) { // null value
            printf("%snull%s", COLOR_NULL, COLOR_RESET);
            p += 4;
            in_key = 1;
        } else if (*p == ',') {
            putchar(*p++);
            in_key = (*p == '"') ? 1 : 0;
        } else if (isspace(*p)) {
            putchar(*p++);
        } else {
            putchar(*p++);
        }
    }
}

// 支持 . 或 .key 的简单过滤
void apply_filter(cJSON* root, const char* filter) {
    if (strcmp(filter, ".") == 0) {
        char* out = cJSON_Print(root);
        char* beautified = beautify_json(out);
        print_colored_json(beautified);
        printf("\n");
        free(out);
        free(beautified);
    } else if (filter[0] == '.' && filter[1]) {
        cJSON* val = find_by_path(root, filter + 1);
        if (val) {
            char* out = cJSON_Print(val);
            char* beautified = beautify_json(out);
            print_colored_json(beautified);
            printf("\n");
            free(out);
            free(beautified);
        } else {
            fprintf(stderr, "Key path '%s' not found.\n", filter + 1);
            exit(1);
        }
    } else {
        fprintf(stderr, "Unsupported filter: %s\n", filter);
        exit(1);
    }
}

int main(int argc, char* argv[]) {
    // 参数解析与帮助
    if (argc >= 2 && (strcmp(argv[1], "--help") == 0 || strcmp(argv[1], "-h") == 0)) {
        printf("NAME\n");
        printf("    jqc - JSON processor with comments support\n\n");
        printf("SYNOPSIS\n");
        printf("    jqc <filter> [json_file]\n");
        printf("    cat file.json | jqc <filter>\n\n");
        printf("DESCRIPTION\n");
        printf("    jqc 是一个类似 jq 的命令行 JSON 处理器，支持带注释的 JSON 文件。\n\n");
        printf("OPTIONS\n");
        printf("    <filter>      jq 风格过滤器，如 . 或 .key\n");
        printf("    [json_file]   可选，指定 JSON 文件，否则从标准输入读取\n");
        printf("    -h, --help    显示本帮助信息\n\n");
        printf("EXAMPLES\n");
        printf("    jqc '.' data.json\n");
        printf("    cat data.json | jqc '.'\n");
        printf("    jqc '.foo.bar' config.json\n");
        printf("    cat config.json | jqc '.foo.bar'\n\n");
        printf("NOTES\n");
        printf("    支持 // 和 /* ... */ 注释的 JSON 文件。\n");
        return 0;
    }

    // 输入读取
    char* input = NULL;
    if (argc == 2) {
        input = read_stdin_all();
    } else if (argc == 3) {
        input = read_file_all(argv[2]);
        if (!input) return 1;
    } else {
        fprintf(stderr, "Usage: %s <filter> [json_file]\n", argv[0]);
        return 1;
    }

    // 注释去除
    char* stripped = strip_json_comments(input);
    free(input);
    if (!stripped) return 1;

    // JSON解析
    cJSON* root = cJSON_Parse(stripped);
    free(stripped);
    if (!root) {
        fprintf(stderr, "Invalid JSON input.\n");
        return 1;
    }

    // 过滤与输出
    apply_filter(root, argv[1]);
    cJSON_Delete(root);
    return 0;
}
