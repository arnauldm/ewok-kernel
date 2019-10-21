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


with ada.unchecked_conversion;
with ewok.tasks;           use ewok.tasks;
with ewok.tasks.debug;
with ewok.tasks_shared;    use ewok.tasks_shared;
with ewok.devices_shared;  use ewok.devices_shared;
with ewok.sched;
with ewok.debug;
with soc.interrupts;

package body ewok.mpu.handler
   with spark_mode => off
is

   procedure memory_fault_handler
     (frame_a      : in  ewok.t_stack_frame_access;
      new_frame_a  : out ewok.t_stack_frame_access)
   is
   begin
      pragma DEBUG (ewok.tasks.debug.crashdump (frame_a));

      -- On memory fault, the task is not scheduled anymore
      ewok.tasks.set_state
        (ewok.sched.current_task_id, TASK_MODE_MAINTHREAD,
         ewok.tasks.TASK_STATE_FAULT);

#if CONFIG_KERNEL_PANIC_FAULT
      if (ewok.tasks.is_real_user(ewok.sched.current_task_id)) then
         ewok.sched.do_schedule (frame_a, new_frame_a);
         return;
      else
         -- panic happen in a kernel task (softirq...)
         debug.panic ("Memory fault!");
         new_frame_a := frame_a;
         return;
      end if;
#else
      -- leave the panic function handling the other panic actions
      debug.panic ("Memory fault!");
      new_frame_a := frame_a;
      return;
#end if;

   end memory_fault_handler;


   procedure init
   is
   begin
      ewok.interrupts.set_interrupt_handler
        (soc.interrupts.INT_MEMMANAGE,
         ewok.interrupts.TASK_SWITCH_HANDLER,
         to_system_address (memory_fault_handler'address),
         ID_KERNEL,
         ID_DEV_UNUSED);
   end init;


end ewok.mpu.handler;
