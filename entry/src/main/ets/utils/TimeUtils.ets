// entry/src/main/ets/utils/TimeUtils.ets
export class TimeUtils {
  /**
   * 对应 Android:
   * val time = formatTime(editTime)
   * val diff = if (time == null) "未知" else calculateTimeDiff(time)
   */
  static getRelativeTime(dateTimeStr?: string | null): string {
    if (!dateTimeStr) {
      return '未知';
    }

    const date = TimeUtils.parseTimeString(dateTimeStr);
    if (!date) {
      return '未知';
    }

    const now = new Date();

    // 差值：单位秒
    const second = Math.floor((now.getTime() - date.getTime()) / 1000);

    const minute = Math.floor(second / 60);
    const hour = Math.floor(minute / 60);
    const day = Math.floor(hour / 24);
    const week = Math.floor(day / 7);
    const month = Math.floor(day / 30);
    const year = Math.floor(month / 12);

    if (year > 0) return `${year}年前`;
    if (month > 0) return `${month}月前`;
    if (week > 0) return `${week}周前`;
    if (day > 0) return `${day}天前`;
    if (hour > 0) return `${hour}小时前`;
    if (minute > 0) return `${minute}分钟前`;
    if (second > 0) return `${second}秒前`;
    return '刚刚';
  }

  /**
   * 模拟 Kotlin: LocalDateTime.parse(time, TIME_FORMATTER)
   * TIME_FORMATTER 基本可以认为是 "yyyy-MM-dd HH:mm:ss"
   */
  private static parseTimeString(timeStr: string): Date | null {
    // 1. 先试试 ISO 格式：2025-11-24T12:00:00
    const iso = new Date(timeStr.replace(' ', 'T'));
    if (!isNaN(iso.getTime())) {
      return iso;
    }

    // 2. 再试 "yyyy/MM/dd HH:mm:ss" 兼容老浏览器/鸿蒙
    const slash = new Date(timeStr.replace(/-/g, '/'));
    if (!isNaN(slash.getTime())) {
      return slash;
    }

    // 3. 手动解析 "yyyy-MM-dd HH:mm:ss"
    const m = timeStr.match(
      /^(\d{4})-(\d{1,2})-(\d{1,2})[ T](\d{1,2}):(\d{1,2}):(\d{1,2})$/
    );
    if (m) {
      const year = Number(m[1]);
      const month = Number(m[2]);
      const day = Number(m[3]);
      const hour = Number(m[4]);
      const minute = Number(m[5]);
      const second = Number(m[6]);
      return new Date(year, month - 1, day, hour, minute, second);
    }

    // 解析失败
    return null;
  }
}
