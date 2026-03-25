export class SchoolAuthError extends Error {
  readonly kind: string;

  constructor(kind: string, message: string) {
    super(message);
    this.name = 'SchoolAuthError';
    this.kind = kind;
  }
}

export class SchoolTgtError extends SchoolAuthError {
  constructor(message: string) {
    super('tgt_failure', message);
    this.name = 'SchoolTgtError';
  }
}

export class SchoolStError extends SchoolAuthError {
  constructor(message: string) {
    super('st_failure', message);
    this.name = 'SchoolStError';
  }
}

export class SchoolServiceResolutionError extends SchoolAuthError {
  constructor(message: string) {
    super('service_resolution_failure', message);
    this.name = 'SchoolServiceResolutionError';
  }
}

export class SchoolWebvpnLandingError extends SchoolAuthError {
  constructor(message: string) {
    super('webvpn_landing_failure', message);
    this.name = 'SchoolWebvpnLandingError';
  }
}

export class SchoolBootstrapError extends SchoolAuthError {
  constructor(message: string) {
    super('bootstrap_failure', message);
    this.name = 'SchoolBootstrapError';
  }
}
