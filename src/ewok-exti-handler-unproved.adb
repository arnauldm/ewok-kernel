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

with soc.gpio;             use soc.gpio;
with soc.exti;             use soc.exti;
with soc.interrupts;
with ewok.interrupts;
with ewok.exported.gpios;  use type ewok.exported.gpios.t_interface_gpio_exti_lock;
with ewok.tasks_shared;
with ewok.devices_shared;

package body ewok.exti.handler.unproved
   with spark_mode => off
is

   procedure init
   is
   begin

      ewok.interrupts.set_interrupt_handler
        (soc.interrupts.INT_EXTI0,
         ewok.interrupts.DEFAULT_HANDLER,
         to_system_address (exti_handler'address),
         ewok.tasks_shared.ID_KERNEL,
         ewok.devices_shared.ID_DEV_UNUSED);

      ewok.interrupts.set_interrupt_handler
        (soc.interrupts.INT_EXTI1,
         ewok.interrupts.DEFAULT_HANDLER,
         to_system_address (exti_handler'address),
         ewok.tasks_shared.ID_KERNEL,
         ewok.devices_shared.ID_DEV_UNUSED);

      ewok.interrupts.set_interrupt_handler
        (soc.interrupts.INT_EXTI2,
         ewok.interrupts.DEFAULT_HANDLER,
         to_system_address (exti_handler'address),
         ewok.tasks_shared.ID_KERNEL,
         ewok.devices_shared.ID_DEV_UNUSED);

      ewok.interrupts.set_interrupt_handler
        (soc.interrupts.INT_EXTI3,
         ewok.interrupts.DEFAULT_HANDLER,
         to_system_address (exti_handler'address),
         ewok.tasks_shared.ID_KERNEL,
         ewok.devices_shared.ID_DEV_UNUSED);

      ewok.interrupts.set_interrupt_handler
        (soc.interrupts.INT_EXTI4,
         ewok.interrupts.DEFAULT_HANDLER,
         to_system_address (exti_handler'address),
         ewok.tasks_shared.ID_KERNEL,
         ewok.devices_shared.ID_DEV_UNUSED);

      ewok.interrupts.set_interrupt_handler
        (soc.interrupts.INT_EXTI9_5,
         ewok.interrupts.DEFAULT_HANDLER,
         to_system_address (exti_handler'address),
         ewok.tasks_shared.ID_KERNEL,
         ewok.devices_shared.ID_DEV_UNUSED);

      ewok.interrupts.set_interrupt_handler
        (soc.interrupts.INT_EXTI15_10,
         ewok.interrupts.DEFAULT_HANDLER,
         to_system_address (exti_handler'address),
         ewok.tasks_shared.ID_KERNEL,
         ewok.devices_shared.ID_DEV_UNUSED);

   end init;


end ewok.exti.handler.unproved;
