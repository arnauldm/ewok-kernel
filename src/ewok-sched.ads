--
-- Copyright 2018 The wookey project team <wookey@ssi.gouv.fr>
--   - Ryad     Benadjila
--   - Arnauld  Michelizza
--   - Mathieu  Renard
--   - Philippe Thierry
--   - Philippe Trebuchet
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
--     Unless required by applicable law or agreed to in writing, software
--     distributed under the License is distributed on an "AS IS" BASIS,
--     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--     See the License for the specific language governing permissions and
--     limitations under the License.
--
--

with ewok.tasks_shared; use ewok.tasks_shared;
with ewok.tasks;
with ewok.sleep;
with ewok.devices;
with ewok.mpu.allocator;
with ewok.debug;
with applications;
with m4.systick;
with m4.mpu;
with m4.scb;
with soc.dwt;
with soc.usart;

package ewok.sched
   with spark_mode => on
is

   sched_period            : unsigned_32  := 0;
   current_task_id         : t_task_id    := ID_KERNEL;
   current_task_mode       : t_task_mode  := TASK_MODE_MAINTHREAD;
   last_main_user_task_id  : t_task_id    := applications.list'first;

   pragma assertion_policy (pre => IGNORE, post => IGNORE, assert => IGNORE);

   -- SPARK/ghost specific function
   function current_task_is_valid
      return boolean
         with ghost;

   procedure request_schedule
      with
         inline,
         global => (in_out => m4.scb.SCB);

   procedure task_elect
     (elected : out t_task_id)
      with
         global =>
           (input  => (ewok.sleep.awakening_time,
                       m4.systick.ticks),
            in_out => (ewok.tasks.tasks_list,
                       last_main_user_task_id));

   procedure pendsv_handler
     (frame_a     : in ewok.t_stack_frame_access;
      new_frame_a : out ewok.t_stack_frame_access)
      with
         global =>
           (input  => (ewok.sleep.awakening_time,
                       ewok.devices.registered_device,
                       ewok.debug.kernel_usart_id,
                       m4.systick.ticks),
            in_out => (ewok.tasks.tasks_list,
                       last_main_user_task_id,
                       current_task_id,
                       current_task_mode,
                       m4.mpu.MPU,
                       soc.usart.USART1,
                       soc.usart.UART4,
                       soc.usart.USART6),
            output => ewok.mpu.allocator.regions_pool);

   procedure systick_handler
     (frame_a     : in ewok.t_stack_frame_access;
      new_frame_a : out ewok.t_stack_frame_access)
      with
         global =>
           (input  => (ewok.sleep.awakening_time,
                       ewok.devices.registered_device,
                       ewok.debug.kernel_usart_id),
            in_out => (ewok.tasks.tasks_list,
                       last_main_user_task_id,
                       current_task_id,
                       current_task_mode,
                       m4.systick.ticks,
                       m4.mpu.MPU,
                       soc.dwt.DWT_CYCCNT,
                       sched_period,
#if CONFIG_KERNEL_SERIAL
                       soc.usart.USART1,
                       soc.usart.UART4,
                       soc.usart.USART6,
#end if;
                       soc.dwt.dwt_loops,
                       soc.dwt.last_dwt),
            output => ewok.mpu.allocator.regions_pool);

   procedure do_schedule
     (frame_a     : in ewok.t_stack_frame_access;
      new_frame_a : out ewok.t_stack_frame_access)
      renames pendsv_handler;

end ewok.sched;

