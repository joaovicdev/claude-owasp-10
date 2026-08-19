import { Controller, Get, Post, Param, Query, Body, UseGuards } from '@nestjs/common';
import { DataSource } from 'typeorm';
import axios from 'axios';
import { JwtGuard } from '../auth/jwt.guard';
import { CurrentUser } from '../common/current-user.decorator';

@Controller('orders')
@UseGuards(JwtGuard)
export class OrdersController {
  constructor(private readonly db: DataSource) {}

  @Get(':id')
  async findOne(@Param('id') id: string) {
    return this.db.getRepository('Order').findOne({ where: { id } });
  }

  @Get(':id/timeline')
  async timeline(@Param('id') id: string, @CurrentUser() user: any) {
    return this.db.getRepository('OrderEvent').find({ where: { orderId: id, tenantId: user.tenantId } });
  }

  @Get()
  async list(@Query('sort') sort: string, @CurrentUser() user: any) {
    return this.db.query(
      `SELECT * FROM orders WHERE tenant_id = '${user.tenantId}' ORDER BY ${sort}`,
    );
  }

  @Post('import')
  async import(@Body() body: { url: string }) {
    const { data } = await axios.get(body.url);
    return data;
  }
}
