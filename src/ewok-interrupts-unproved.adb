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

with ewok.interrupts.handler;
with ewok.tasks_shared;    use ewok.tasks_shared;
with ewok.devices_shared;  use ewok.devices_shared;
with m4.scb;
with soc.nvic;

package body ewok.interrupts.unproved
   with spark_mode => off
is

   procedure init
   is
   begin

      m4.scb.SCB.SHCSR.USGFAULTENA := true;
      m4.scb.SCB.SHCSR.BUSFAULTENA := true;

      for i in interrupt_table'range loop
         interrupt_table(i) :=
           (handler_type   => DEFAULT_HANDLER,
            handler        => 0,
            task_id        => ewok.tasks_shared.ID_UNUSED,
            device_id      => ewok.devices_shared.ID_DEV_UNUSED);
      end loop;

      interrupt_table(soc.interrupts.INT_HARDFAULT) :=
           (handler_type   => TASK_SWITCH_HANDLER,
            handler     =>
               to_system_address
                 (ewok.interrupts.handler.hardfault_handler'address),
            task_id     => ewok.tasks_shared.ID_KERNEL,
            device_id   => ewok.devices_shared.ID_DEV_UNUSED);

      interrupt_table(soc.interrupts.INT_BUSFAULT) :=
           (handler_type   => TASK_SWITCH_HANDLER,
            handler     =>
               to_system_address
                 (ewok.interrupts.handler.busfault_handler'address),
            task_id     => ewok.tasks_shared.ID_KERNEL,
            device_id   => ewok.devices_shared.ID_DEV_UNUSED);

      interrupt_table(soc.interrupts.INT_USAGEFAULT) :=
           (handler_type     => TASK_SWITCH_HANDLER,
            handler     =>
               to_system_address
                 (ewok.interrupts.handler.usagefault_handler'address),
            task_id     => ewok.tasks_shared.ID_KERNEL,
            device_id   => ewok.devices_shared.ID_DEV_UNUSED);

      interrupt_table(soc.interrupts.INT_SYSTICK) :=
           (handler_type     => TASK_SWITCH_HANDLER,
            handler     =>
               to_system_address
                 (ewok.interrupts.handler.systick_default_handler'address),
            task_id     => ewok.tasks_shared.ID_KERNEL,
            device_id   => ewok.devices_shared.ID_DEV_UNUSED);

      m4.scb.SCB.SHPR1.mem_fault.priority := 0;
      m4.scb.SCB.SHPR1.bus_fault.priority := 1;
      m4.scb.SCB.SHPR1.usage_fault.priority := 2;
      m4.scb.SCB.SHPR2.svc_call.priority  := 3;
      m4.scb.SCB.SHPR3.pendsv.priority    := 4;
      m4.scb.SCB.SHPR3.systick.priority   := 5;

      for irq in soc.nvic.t_irq_index'range loop
         soc.nvic.NVIC.IPR(irq).priority := 7;
      end loop;

   end init;

end ewok.interrupts.unproved;
