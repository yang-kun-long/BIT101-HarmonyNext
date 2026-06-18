import type { SchoolBootstrapResult } from './SchoolAuthTypes';

export interface SchoolBootstrap {
  run(): Promise<SchoolBootstrapResult>;
}
