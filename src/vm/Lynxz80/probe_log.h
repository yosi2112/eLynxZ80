#pragma once

#include <chrono>
#include <cstdarg>
#include <cstdint>
#include <cstdio>

inline const std::chrono::steady_clock::time_point& probe_log_start_time()
{
    static const auto start_time = std::chrono::steady_clock::now();
    return start_time;
}

inline void probe_log_write(const char* filename, int& count, const char* format, va_list args)
{
    FILE* fp = fopen(filename, count == 0 ? "w" : "a");
    if(fp == NULL) {
        return;
    }

    auto now = std::chrono::steady_clock::now();
    uint64_t elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(now - probe_log_start_time()).count();
    fprintf(fp, "%llu|", (unsigned long long)elapsed);
    vfprintf(fp, format, args);
    fprintf(fp, "\n");
    fclose(fp);
    count++;
}

inline void probe_log_file(const char* filename, int& count, const char* format, ...)
{
    va_list args;
    va_start(args, format);
    probe_log_write(filename, count, format, args);
    va_end(args);
}
