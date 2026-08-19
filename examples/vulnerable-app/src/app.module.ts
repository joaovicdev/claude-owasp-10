import { Module } from '@nestjs/common';
import { OrdersController } from './orders/orders.controller';
import { UsersController } from './users/users.controller';
import { AuthController } from './auth/auth.controller';
import { RequestLogger } from './common/request-logger.middleware';

@Module({
  controllers: [OrdersController, UsersController, AuthController],
  providers: [RequestLogger],
})
export class AppModule {}
