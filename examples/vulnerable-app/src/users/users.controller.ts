import { Controller, Get, Patch, Param, Body, UseGuards } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { JwtGuard } from '../auth/jwt.guard';

@Controller('users')
@UseGuards(JwtGuard)
export class UsersController {
  constructor(private readonly db: DataSource) {}

  @Get(':id')
  async profile(@Param('id') id: string) {
    return this.db.getRepository('User').findOne({ where: { id } });
  }

  @Patch(':id')
  async update(@Param('id') id: string, @Body() body: any) {
    const repo = this.db.getRepository('User');
    const user = await repo.findOne({ where: { id } });
    Object.assign(user, body);
    return repo.save(user);
  }
}
