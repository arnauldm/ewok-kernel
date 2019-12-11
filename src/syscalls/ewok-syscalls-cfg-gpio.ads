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

with ewok.tasks_shared;
with ewok.tasks;        use ewok.tasks;
with ewok.gpio;
with soc.exti;
with soc.gpio;
with soc.nvic;
with applications;

package ewok.syscalls.cfg.gpio
   with spark_mode => on
is
   procedure svc_gpio_set
     (caller_id   : in  ewok.tasks_shared.t_task_id;
      params      : in  t_parameters;
      mode        : in  ewok.tasks_shared.t_task_mode)
      with
         pre => caller_id in applications.t_real_task_id,
         global =>
           (input => ewok.gpio.gpio_points,
            in_out =>
              (tasks_list,
               soc.gpio.GPIOA,
               soc.gpio.GPIOB,
               soc.gpio.GPIOC,
               soc.gpio.GPIOD,
               soc.gpio.GPIOE,
               soc.gpio.GPIOF,
               soc.gpio.GPIOG,
               soc.gpio.GPIOH,
               soc.gpio.GPIOI));

   procedure svc_gpio_get
     (caller_id   : in     ewok.tasks_shared.t_task_id;
      params      : in out t_parameters;
      mode        : in     ewok.tasks_shared.t_task_mode)
      with
         pre => caller_id in applications.t_real_task_id,
         global =>
           (input => ewok.gpio.gpio_points,
            in_out => tasks_list);

   procedure svc_gpio_unlock_exti
     (caller_id   : in  ewok.tasks_shared.t_task_id;
      params      : in  t_parameters;
      mode        : in  ewok.tasks_shared.t_task_mode)
      with
         pre => caller_id in applications.t_real_task_id,
         global =>
           (input => ewok.gpio.gpio_points,
            in_out =>
              (tasks_list,
               soc.exti.EXTI,
               soc.nvic.nvic));

end ewok.syscalls.cfg.gpio;
