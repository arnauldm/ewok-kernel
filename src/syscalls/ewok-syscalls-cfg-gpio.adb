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

with system;

with ewok.tasks_shared; use ewok.tasks_shared;
with ewok.exti;
with ewok.exported.gpios; use ewok.exported.gpios;
with ewok.sanitize;

package body ewok.syscalls.cfg.gpio
   with spark_mode => on
is

   procedure svc_gpio_set
     (caller_id   : in  ewok.tasks_shared.t_task_id;
      params      : in  t_parameters;
      mode        : in  ewok.tasks_shared.t_task_mode)
   is

      ref   : ewok.exported.gpios.t_gpio_ref
         with import, address => params(1)'address;

      val   : unsigned_8
         with import, address => params(2)'address;

   begin

      -- Task initialization is complete ?
      if not is_init_done (caller_id) then
         set_return_value (caller_id, mode, SYS_E_DENIED);
         ewok.tasks.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- Valid t_gpio_ref ?
      if not ref.pin'valid or not ref.port'valid then
         set_return_value (caller_id, mode, SYS_E_INVAL);
         ewok.tasks.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- Does that GPIO really belongs to the caller ?
      if not ewok.gpio.belong_to (caller_id, ref) then
         set_return_value (caller_id, mode, SYS_E_DENIED);
         ewok.tasks.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- Write the pin
      if val >= 1 then
         ewok.gpio.write_pin (ref, 1);
      else
         ewok.gpio.write_pin (ref, 0);
      end if;

      set_return_value (caller_id, mode, SYS_E_DONE);
      ewok.tasks.set_state (caller_id, mode, TASK_STATE_RUNNABLE);

   end svc_gpio_set;


   procedure svc_gpio_get
     (caller_id   : in     ewok.tasks_shared.t_task_id;
      params      : in out t_parameters;
      mode        : in     ewok.tasks_shared.t_task_mode)
   is

      ref   : ewok.exported.gpios.t_gpio_ref
         with import, address => params(1)'address;

      val_address : constant system.address := to_address (params(2));
      val         : unsigned_8
         with import, address => val_address;

   begin

      -- Task initialization is complete ?
      if not is_init_done (caller_id) then
         set_return_value (caller_id, mode, SYS_E_DENIED);
         ewok.tasks.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- Valid t_gpio_ref ?
      if not ref.pin'valid or not ref.port'valid then
         set_return_value (caller_id, mode, SYS_E_INVAL);
         ewok.tasks.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- Does that GPIO really belongs to the caller ?
      if not ewok.gpio.belong_to (caller_id, ref) then
         set_return_value (caller_id, mode, SYS_E_DENIED);
         ewok.tasks.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- Does &val is in the caller address space ?
      if not ewok.sanitize.is_word_in_data_slot
               (to_system_address (val_address), caller_id, mode)
      then
         set_return_value (caller_id, mode, SYS_E_DENIED);
         ewok.tasks.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- Read the pin
      val := unsigned_8 (ewok.gpio.read_pin (ref));

      set_return_value (caller_id, mode, SYS_E_DONE);
      ewok.tasks.set_state (caller_id, mode, TASK_STATE_RUNNABLE);

   end svc_gpio_get;



   -- Unlock EXTI line associated to given GPIO, if the EXTI
   -- line has been locked by the kernel (exti lock parameter is
   -- set to 'true'.
   procedure svc_gpio_unlock_exti
     (caller_id   : in  ewok.tasks_shared.t_task_id;
      params      : in  t_parameters;
      mode        : in  ewok.tasks_shared.t_task_mode)
   is

      ref         : ewok.exported.gpios.t_gpio_ref
                        with import, address => params(1)'address;

      gpio_config : ewok.exported.gpios.t_gpio_config;

   begin

      -- Task initialization is complete ?
      if not is_init_done (caller_id) then
         set_return_value (caller_id, mode, SYS_E_DENIED);
         ewok.tasks.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- Valid t_gpio_ref ?
      if not ref.pin'valid or not ref.port'valid then
         set_return_value (caller_id, mode, SYS_E_INVAL);
         ewok.tasks.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- Does that GPIO really belongs to the caller ?
      if not ewok.gpio.belong_to (caller_id, ref) then
         set_return_value (caller_id, mode, SYS_E_DENIED);
         ewok.tasks.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      gpio_config := ewok.gpio.get_config(ref);

      -- Does that GPIO has an EXTI line which is lockable ?
      if gpio_config.exti_trigger = GPIO_EXTI_TRIGGER_NONE or
         gpio_config.exti_lock    = GPIO_EXTI_UNLOCKED
      then
         set_return_value (caller_id, mode, SYS_E_INVAL);
         ewok.tasks.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      ewok.exti.enable(ref);

      set_return_value (caller_id, mode, SYS_E_DONE);
      ewok.tasks.set_state (caller_id, mode, TASK_STATE_RUNNABLE);

   end svc_gpio_unlock_exti;


end ewok.syscalls.cfg.gpio;
