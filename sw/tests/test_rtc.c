// Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn>
// SPDX-License-Identifier: MulanPSL-2.0

#include <assert.h>
#include <stdint.h>

#include "rtc.h"

static void test_calendar_boundaries(void) {
    rtc_calendar_t calendar = {1970U, 1U, 1U, 0U, 0U, 0U};
    rtc_calendar_t decoded;
    uint64_t seconds;

    assert(rtc_calendar_to_epoch(&calendar, &seconds) == RTC_STATUS_OK);
    assert(seconds == 0U);
    calendar.year = 2000U;
    calendar.month = 2U;
    calendar.day = 29U;
    calendar.hour = 23U;
    calendar.minute = 59U;
    calendar.second = 59U;
    assert(rtc_calendar_to_epoch(&calendar, &seconds) == RTC_STATUS_OK);
    assert(rtc_epoch_to_calendar(seconds, &decoded) == RTC_STATUS_OK);
    assert((decoded.year == 2000U) && (decoded.month == 2U) && (decoded.day == 29U));
    calendar.year = 2100U;
    assert(rtc_calendar_to_epoch(&calendar, &seconds) == RTC_STATUS_INVALID_ARGUMENT);
    assert(rtc_epoch_to_calendar(UINT64_C(253402300799), &decoded) == RTC_STATUS_OK);
    assert((decoded.year == 9999U) && (decoded.month == 12U) && (decoded.day == 31U));
    assert(rtc_epoch_to_calendar(UINT64_C(253402300800), &decoded) == RTC_STATUS_INVALID_ARGUMENT);
}

int main(void) {
    rtc_config_t config = {256U, 0, 0U, 0U, false};
    rtc_time_t time = {0U, 0U};
    rtc_alarm_t alarm = {0U, 0U, false};
    rtc_periodic_t periodic = {0U, false, false};

    test_calendar_boundaries();
    assert(rtc_probe((uintptr_t)0U) == RTC_STATUS_INVALID_ARGUMENT);
    assert(rtc_configure((uintptr_t)0U, &config, 1U) == RTC_STATUS_INVALID_ARGUMENT);
    assert(rtc_set_time((uintptr_t)0U, &time, 1U) == RTC_STATUS_INVALID_ARGUMENT);
    assert(rtc_get_time((uintptr_t)0U, &time, 1U) == RTC_STATUS_INVALID_ARGUMENT);
    assert(rtc_configure_alarm((uintptr_t)0U, 0U, &alarm, 1U) == RTC_STATUS_INVALID_ARGUMENT);
    assert(rtc_configure_periodic((uintptr_t)0U, &periodic, 1U) == RTC_STATUS_INVALID_ARGUMENT);
    assert(rtc_clear_events((uintptr_t)0U, 1U, 1U) == RTC_STATUS_INVALID_ARGUMENT);
    return 0;
}
