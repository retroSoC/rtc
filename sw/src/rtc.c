// Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn>
// SPDX-License-Identifier: MulanPSL-2.0

#include "rtc.h"

#include <stddef.h>

#include "rtc_regs.h"

#define RTC_SECONDS_PER_MINUTE UINT64_C(60)
#define RTC_SECONDS_PER_HOUR   UINT64_C(3600)
#define RTC_SECONDS_PER_DAY    UINT64_C(86400)
#define RTC_MAX_EPOCH_SECONDS  UINT64_C(253402300799)

static volatile uint32_t *rtc_register(uintptr_t base, uint32_t offset) {
    return (volatile uint32_t *)(base + (uintptr_t)offset);
}

static uint32_t rtc_read_register(uintptr_t base, uint32_t offset) {
    return *rtc_register(base, offset);
}

static void rtc_write_register(uintptr_t base, uint32_t offset, uint32_t value) {
    *rtc_register(base, offset) = value;
}

static bool rtc_is_leap_year(uint32_t year) {
    return ((year % 4U) == 0U) && (((year % 100U) != 0U) || ((year % 400U) == 0U));
}

static uint32_t rtc_days_in_month(uint32_t year, uint32_t month) {
    static const uint8_t days[] = {31U, 28U, 31U, 30U, 31U, 30U, 31U, 31U, 30U, 31U, 30U, 31U};
    uint32_t result = 0U;

    if ((month >= 1U) && (month <= 12U)) {
        result = days[month - 1U];
        if ((month == 2U) && rtc_is_leap_year(year)) {
            result++;
        }
    }
    return result;
}

static rtc_status_t rtc_execute(uintptr_t base, uint32_t command, uint32_t timeout) {
    uint32_t status;

    rtc_write_register(base, RTC_COMMAND_STATUS_OFFSET,
                       RTC_COMMAND_STATUS_DONE_MASK | RTC_COMMAND_STATUS_ERROR_MASK);
    rtc_write_register(base, RTC_COMMAND_OFFSET, command);
    do {
        status = rtc_read_register(base, RTC_COMMAND_STATUS_OFFSET);
        if ((status & RTC_COMMAND_STATUS_DONE_MASK) != 0U) {
            return ((status & RTC_COMMAND_STATUS_ERROR_MASK) == 0U) ? RTC_STATUS_OK
                                                                    : RTC_STATUS_IO_ERROR;
        }
        timeout--;
    } while (timeout != 0U);
    return RTC_STATUS_TIMEOUT;
}

rtc_status_t rtc_probe(uintptr_t base) {
    uint32_t capability;

    if (base == (uintptr_t)0U) {
        return RTC_STATUS_INVALID_ARGUMENT;
    }
    capability = rtc_read_register(base, RTC_CAPABILITY_OFFSET);
    if ((rtc_read_register(base, RTC_IP_ID_OFFSET) != RTC_IP_ID_VALUE) ||
        ((capability >> 24U) != RTC_ABI_VERSION)) {
        return RTC_STATUS_IO_ERROR;
    }
    return RTC_STATUS_OK;
}

rtc_status_t rtc_configure(uintptr_t base, const rtc_config_t *config, uint32_t timeout) {
    if ((base == (uintptr_t)0U) || (config == NULL) ||
        (config->second_cycles < RTC_SECOND_CYCLES_MIN) ||
        (config->calibration_ppm < RTC_CALIB_PPM_MIN) ||
        (config->calibration_ppm > RTC_CALIB_PPM_MAX) ||
        ((config->interrupt_enable & ~RTC_EVENT_VALID_MASK) != 0U) ||
        ((config->wake_enable & ~RTC_EVENT_VALID_MASK) != 0U) || (timeout == 0U)) {
        return RTC_STATUS_INVALID_ARGUMENT;
    }
    rtc_write_register(base, RTC_CTRL_OFFSET, config->enable ? RTC_CTRL_ENABLE_MASK : 0U);
    rtc_write_register(base, RTC_SECOND_CYCLES_OFFSET, config->second_cycles);
    rtc_write_register(base, RTC_CALIB_PPM_OFFSET, (uint32_t)(int32_t)config->calibration_ppm);
    rtc_write_register(base, RTC_INTR_ENABLE_OFFSET, config->interrupt_enable);
    rtc_write_register(base, RTC_WAKE_ENABLE_OFFSET, config->wake_enable);
    return rtc_execute(base, RTC_COMMAND_APPLY_CONFIG, timeout);
}

rtc_status_t rtc_set_time(uintptr_t base, const rtc_time_t *time, uint32_t timeout) {
    if ((base == (uintptr_t)0U) || (time == NULL) || (timeout == 0U)) {
        return RTC_STATUS_INVALID_ARGUMENT;
    }
    rtc_write_register(base, RTC_TIME_LOAD_LO_OFFSET, (uint32_t)time->seconds);
    rtc_write_register(base, RTC_TIME_LOAD_HI_OFFSET, (uint32_t)(time->seconds >> 32U));
    rtc_write_register(base, RTC_TIME_LOAD_SUBSEC_OFFSET, time->subsecond);
    return rtc_execute(base, RTC_COMMAND_SET_TIME, timeout);
}

rtc_status_t rtc_get_time(uintptr_t base, rtc_time_t *time, uint32_t timeout) {
    rtc_status_t result;
    uint32_t status;

    if ((base == (uintptr_t)0U) || (time == NULL) || (timeout == 0U)) {
        return RTC_STATUS_INVALID_ARGUMENT;
    }
    status = rtc_read_register(base, RTC_STATUS_OFFSET);
    if ((status & RTC_STATUS_TIME_VALID_MASK) == 0U) {
        return RTC_STATUS_NOT_INITIALIZED;
    }
    result = rtc_execute(base, RTC_COMMAND_SNAPSHOT, timeout);
    if (result == RTC_STATUS_OK) {
        time->seconds = rtc_read_register(base, RTC_SNAPSHOT_TIME_LO_OFFSET);
        time->seconds |= ((uint64_t)rtc_read_register(base, RTC_SNAPSHOT_TIME_HI_OFFSET) << 32U);
        time->subsecond = (uint8_t)rtc_read_register(base, RTC_SNAPSHOT_SUBSEC_OFFSET);
    }
    return result;
}

rtc_status_t rtc_configure_alarm(uintptr_t base, uint32_t channel, const rtc_alarm_t *alarm,
                                 uint32_t timeout) {
    uint32_t enable;
    uint32_t low_offset;
    uint32_t high_offset;
    uint32_t subsecond_offset;

    if ((base == (uintptr_t)0U) || (alarm == NULL) || (channel > 1U) || (timeout == 0U)) {
        return RTC_STATUS_INVALID_ARGUMENT;
    }
    low_offset = (channel == 0U) ? RTC_ALARM0_TIME_LO_OFFSET : RTC_ALARM1_TIME_LO_OFFSET;
    high_offset = (channel == 0U) ? RTC_ALARM0_TIME_HI_OFFSET : RTC_ALARM1_TIME_HI_OFFSET;
    subsecond_offset = (channel == 0U) ? RTC_ALARM0_SUBSEC_OFFSET : RTC_ALARM1_SUBSEC_OFFSET;
    rtc_write_register(base, low_offset, (uint32_t)alarm->seconds);
    rtc_write_register(base, high_offset, (uint32_t)(alarm->seconds >> 32U));
    rtc_write_register(base, subsecond_offset, alarm->subsecond);
    enable = rtc_read_register(base, RTC_ALARM_ENABLE_OFFSET);
    if (alarm->enable) {
        enable |= UINT32_C(1) << channel;
    } else {
        enable &= ~(UINT32_C(1) << channel);
    }
    rtc_write_register(base, RTC_ALARM_ENABLE_OFFSET, enable);
    return rtc_execute(base, RTC_COMMAND_APPLY_CONFIG, timeout);
}

rtc_status_t rtc_configure_periodic(uintptr_t base, const rtc_periodic_t *periodic,
                                    uint32_t timeout) {
    uint32_t control = 0U;

    if ((base == (uintptr_t)0U) || (periodic == NULL) ||
        (periodic->enable && (periodic->ticks == 0U)) || (timeout == 0U)) {
        return RTC_STATUS_INVALID_ARGUMENT;
    }
    if (periodic->enable) {
        control |= RTC_PERIOD_ENABLE_MASK;
    }
    if (periodic->auto_reload) {
        control |= RTC_PERIOD_AUTO_RELOAD_MASK;
    }
    rtc_write_register(base, RTC_PERIOD_RELOAD_OFFSET, periodic->ticks);
    rtc_write_register(base, RTC_PERIOD_CTRL_OFFSET, control);
    return rtc_execute(base, RTC_COMMAND_APPLY_CONFIG, timeout);
}

uint32_t rtc_get_events(uintptr_t base) {
    return (base == (uintptr_t)0U) ? 0U : rtc_read_register(base, RTC_EVENT_RAW_OFFSET);
}

rtc_status_t rtc_clear_events(uintptr_t base, uint32_t mask, uint32_t timeout) {
    if ((base == (uintptr_t)0U) || (mask == 0U) || ((mask & ~RTC_EVENT_VALID_MASK) != 0U) ||
        (timeout == 0U)) {
        return RTC_STATUS_INVALID_ARGUMENT;
    }
    rtc_write_register(base, RTC_EVENT_CLEAR_OFFSET, mask);
    return rtc_execute(base, RTC_COMMAND_CLEAR_EVENTS, timeout);
}

rtc_status_t rtc_inject_events(uintptr_t base, uint32_t mask, uint32_t timeout) {
    if ((base == (uintptr_t)0U) || (mask == 0U) || ((mask & ~RTC_EVENT_VALID_MASK) != 0U) ||
        (timeout == 0U)) {
        return RTC_STATUS_INVALID_ARGUMENT;
    }
    rtc_write_register(base, RTC_EVENT_TEST_OFFSET, mask);
    return rtc_execute(base, RTC_COMMAND_INJECT_EVENTS, timeout);
}

rtc_status_t rtc_calendar_to_epoch(const rtc_calendar_t *calendar, uint64_t *seconds) {
    uint64_t days = 0U;
    uint32_t year;
    uint32_t month;

    if ((calendar == NULL) || (seconds == NULL) || (calendar->year < 1970U) ||
        (calendar->year > 9999U) || (calendar->month < 1U) || (calendar->month > 12U) ||
        (calendar->day < 1U) ||
        (calendar->day > rtc_days_in_month(calendar->year, calendar->month)) ||
        (calendar->hour > 23U) || (calendar->minute > 59U) || (calendar->second > 59U)) {
        return RTC_STATUS_INVALID_ARGUMENT;
    }
    for (year = 1970U; year < calendar->year; year++) {
        days += rtc_is_leap_year(year) ? 366U : 365U;
    }
    for (month = 1U; month < calendar->month; month++) {
        days += rtc_days_in_month(calendar->year, month);
    }
    days += (uint64_t)calendar->day - 1U;
    *seconds = (days * RTC_SECONDS_PER_DAY) + ((uint64_t)calendar->hour * RTC_SECONDS_PER_HOUR) +
               ((uint64_t)calendar->minute * RTC_SECONDS_PER_MINUTE) + calendar->second;
    return RTC_STATUS_OK;
}

rtc_status_t rtc_epoch_to_calendar(uint64_t seconds, rtc_calendar_t *calendar) {
    uint64_t days;
    uint64_t day_seconds;
    uint32_t year = 1970U;
    uint32_t month = 1U;
    uint32_t year_days;
    uint32_t month_days;

    if ((calendar == NULL) || (seconds > RTC_MAX_EPOCH_SECONDS)) {
        return RTC_STATUS_INVALID_ARGUMENT;
    }
    days = seconds / RTC_SECONDS_PER_DAY;
    day_seconds = seconds % RTC_SECONDS_PER_DAY;
    year_days = rtc_is_leap_year(year) ? 366U : 365U;
    while (days >= year_days) {
        days -= year_days;
        year++;
        year_days = rtc_is_leap_year(year) ? 366U : 365U;
    }
    month_days = rtc_days_in_month(year, month);
    while (days >= month_days) {
        days -= month_days;
        month++;
        month_days = rtc_days_in_month(year, month);
    }
    calendar->year = (uint16_t)year;
    calendar->month = (uint8_t)month;
    calendar->day = (uint8_t)(days + 1U);
    calendar->hour = (uint8_t)(day_seconds / RTC_SECONDS_PER_HOUR);
    day_seconds %= RTC_SECONDS_PER_HOUR;
    calendar->minute = (uint8_t)(day_seconds / RTC_SECONDS_PER_MINUTE);
    calendar->second = (uint8_t)(day_seconds % RTC_SECONDS_PER_MINUTE);
    return RTC_STATUS_OK;
}
