import { Injectable, NestMiddleware, Logger } from '@nestjs/common';

@Injectable()
export class RequestLogger implements NestMiddleware {
  private readonly log = new Logger('http');

  use(req: any, _res: any, next: () => void) {
    this.log.log(`${req.method} ${req.url} headers=${JSON.stringify(req.headers)} body=${JSON.stringify(req.body)}`);
    next();
  }
}
