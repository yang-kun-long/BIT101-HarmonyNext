// entry/src/main/ets/services/manage/ReportService.ts
import { bit101Session } from '../../core/network/bit101Session';
import type { RcpResponseData } from '../../core/network/rcpSession';

export interface ReportType {
  id: number;
  text: string;
}

export interface PostReportBody {
  obj: string;     // "poster{id}" 或 "comment{id}"
  text: string;    // 举报理由补充说明
  type_id: number; // 举报类型 ID（注意下划线）
}

class ReportService {
  // 解析 JSON 的小工具：失败时返回 null，避免直接 throw JSON.parse 的异常
  private parseJsonArray(bodyText: string): ReportType[] | null {
    try {
      const parsed = JSON.parse(bodyText) as ReportType[]; // 按 OpenAPI 约定是数组
      // 这里做一个最基本的检查：至少是数组
      if (parsed && parsed instanceof Array) {
        return parsed;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  private parseJsonObject(bodyText: string): Record<string, unknown> | null {
    try {
      const parsed = JSON.parse(bodyText) as Record<string, unknown>;
      return parsed;
    } catch (_) {
      return null;
    }
  }

  // 获取举报类型列表：GET /manage/report_types
  async getReportTypes(): Promise<ReportType[]> {
    const res: RcpResponseData = await bit101Session.fetch('GET', '/manage/report_types');

    if (res.statusCode !== 200) {
      // 非 200 直接认为失败
      throw new Error('getReportTypes failed: statusCode=' + res.statusCode);
    }

    const data = this.parseJsonArray(res.bodyText);
    if (!data) {
      throw new Error('getReportTypes failed: invalid response body');
    }

    return data;
  }

  // 通用举报：obj 形如 "poster10" / "comment456"
  async report(obj: string, typeId: number, text: string): Promise<boolean> {
    const body: PostReportBody = {
      obj: obj,
      text: text,
      type_id: typeId
    };

    const res: RcpResponseData = await bit101Session.fetch('POST', '/manage/reports', {
      body: JSON.stringify(body),
      headers: {
        'Content-Type': 'application/json'
      }
    });

    if (res.statusCode === 200) {
      // 200 按成功处理
      return true;
    }

    // 非 200 看一下 msg（如果后端按 OpenAPI 返回 { msg: string }）
    const objBody = this.parseJsonObject(res.bodyText);
    if (objBody && objBody['msg']) {
      // 你可以在这里用 Logger 打一下 msg
      // logger.warn('[ReportService] report failed: ' + String(objBody['msg']));
    }

    return false;
  }

  async reportPoster(id: number, typeId: number, text: string): Promise<boolean> {
    const obj = `poster${id}`;
    return this.report(obj, typeId, text);
  }

  async reportComment(id: number, typeId: number, text: string): Promise<boolean> {
    const obj = `comment${id}`;
    return this.report(obj, typeId, text);
  }
}

export const reportService = new ReportService();
