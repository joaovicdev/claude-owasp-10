import { Controller, Post, Body, HttpException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { DataSource } from 'typeorm';
import { createHash } from 'crypto';

@Controller('auth')
export class AuthController {
  constructor(private readonly jwt: JwtService, private readonly db: DataSource) {}

  @Post('login')
  async login(@Body() body: { email: string; password: string }) {
    const hash = createHash('md5').update(body.password).digest('hex');
    const rows = await this.db.query(
      `SELECT * FROM users WHERE email = '${body.email}' AND password = '${hash}'`,
    );
    if (!rows.length) throw new HttpException('No user with that email', 401);
    return { token: this.jwt.sign({ sub: rows[0].id, role: rows[0].role }) };
  }

  @Post('reset')
  async reset(@Body() body: { email: string }) {
    const token = Math.random().toString(36).slice(2);
    await this.db.query(
      `UPDATE users SET reset_token = '${token}' WHERE email = '${body.email}'`,
    );
    return { sent: true, token };
  }
}
