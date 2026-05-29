import { DebugCase } from './DebugCase';
import { LoginHealthService, LoginHealthSummary } from '../services/auth/LoginHealthService';

export class LoginHealthCase extends DebugCase {
  readonly name: string = 'Login health check';

  async run(): Promise<void> {
    const service = new LoginHealthService();
    const summary: LoginHealthSummary = await service.checkLogin({ clearWhenInvalid: false });

    this.logInfo(
      'summary ok =',
      summary.ok,
      'bit101 =',
      summary.bit101.ok,
      summary.bit101.message,
      'school =',
      summary.school.ok,
      summary.school.message,
      'jxzx =',
      summary.jxzx.ok,
      summary.jxzx.message,
      'detail =',
      summary.detail,
    );

    if (summary.ok) {
      this.assertEquals(summary.statusText, '已登录', 'valid login should display logged-in text');
      this.assertEquals(summary.toastText, '登录状态检查成功', 'valid login should display success toast');
    } else if (summary.bit101.ok && summary.school.ok) {
      this.assertEquals(summary.statusText, '部分异常', 'partial login should display partial status text');
      this.assertEquals(
        summary.toastText,
        '部分登录态异常，请重新登录后再试考试/空教室',
        'partial login should display partial failure toast',
      );
    } else {
      this.assertEquals(summary.statusText, '未登录', 'invalid login should display logged-out text');
      this.assertEquals(summary.toastText, '登录状态检查失败', 'invalid login should display failure toast');
    }
  }
}
