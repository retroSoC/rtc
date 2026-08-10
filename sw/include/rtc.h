// Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn>
// SPDX-License-Identifier: MulanPSL-2.0

#ifndef RTC_H
#define RTC_H

#include <stdbool.h>
#include <stdint.h>

typedef enum {
    RTC_STATUS_OK = 0,
    RTC_STATUS_INVALID_ARGUMENT = -1,
    RTC_STATUS_TIMEOUT = -2,
    RTC_STATUS_IO_ERROR = -3,
    RTC_STATUS_NOT_INITIALIZED = -4
} rtc_status_t;

typedef struct {
    uint32_t second_cycles;
    int16_t calibration_ppm;
    uint32_t interrupt_enable;
    uint32_t wake_enable;
    bool enable;
} rtc_config_t;

typedef struct {
    uint64_t seconds;
    uint8_t subsecond;
} rtc_time_t;

typedef struct {
    uint64_t seconds;
    uint8_t subsecond;
    bool enable;
} rtc_alarm_t;

typedef struct {
    uint32_t ticks;
    bool enable;
    bool auto_reload;
} rtc_periodic_t;

typedef struct {
    uint16_t year;
    uint8_t month;
    uint8_t day;
    uint8_t hour;
    uint8_t minute;
    uint8_t second;
} rtc_calendar_t;

rtc_status_t rtc_probe(uintptr_t base);
rtc_status_t rtc_configure(uintptr_t base, const rtc_config_t *config, uint32_t timeout);
rtc_status_t rtc_set_time(uintptr_t base, const rtc_time_t *time, uint32_t timeout);
rtc_status_t rtc_get_time(uintptr_t base, rtc_time_t *time, uint32_t timeout);
rtc_status_t rtc_configure_alarm(uintptr_t base, uint32_t channel, const rtc_alarm_t *alarm,
                                 uint32_t timeout);
rtc_status_t rtc_configure_periodic(uintptr_t base, const rtc_periodic_t *periodic,
                                    uint32_t timeout);
uint32_t rtc_get_events(uintptr_t base);
rtc_status_t rtc_clear_events(uintptr_t base, uint32_t mask, uint32_t timeout);
rtc_status_t rtc_inject_events(uintptr_t base, uint32_t mask, uint32_t timeout);
rtc_status_t rtc_calendar_to_epoch(const rtc_calendar_t *calendar, uint64_t *seconds);
rtc_status_t rtc_epoch_to_calendar(uint64_t seconds, rtc_calendar_t *calendar);

#endif
