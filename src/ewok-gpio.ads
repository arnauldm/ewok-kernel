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

with soc.gpio;
with ewok.exported.gpios;
with ewok.tasks_shared;    use ewok.tasks_shared;
with ewok.devices_shared;  use ewok.devices_shared;

package ewok.gpio
   with spark_mode => on
is

   function is_used
     (ref : ewok.exported.gpios.t_gpio_ref)
      return boolean
   with post =>
      is_used'result = gpio_points(ref.port, ref.pin).used;

   procedure register
     (task_id     : in  ewok.tasks_shared.t_task_id;
      device_id   : in  ewok.devices_shared.t_device_id;
      gpio_config : in  ewok.exported.gpios.t_gpio_config;
      success     : out boolean)
   with
      pre => task_id /= ID_UNUSED;

   procedure release
     (task_id     : in  ewok.tasks_shared.t_task_id;
      device_id   : in  ewok.devices_shared.t_device_id;
      gpio_config : in  ewok.exported.gpios.t_gpio_config);

   procedure config
     (gpio_config : in  ewok.exported.gpios.t_gpio_config);

   procedure write_pin
     (ref      : in  ewok.exported.gpios.t_gpio_ref;
      value    : in  bit)
      with inline_always;

   function read_pin
     (ref      : in  ewok.exported.gpios.t_gpio_ref)
      return bit
      with inline_always;

   function belong_to
     (task_id  : in  ewok.tasks_shared.t_task_id;
      ref      : in  ewok.exported.gpios.t_gpio_ref)
      return boolean;

   function get_task_id
     (ref      : in  ewok.exported.gpios.t_gpio_ref)
      return ewok.tasks_shared.t_task_id;

   function get_device_id
     (ref      : in  ewok.exported.gpios.t_gpio_ref)
      return ewok.devices_shared.t_device_id;

   function get_config
     (ref      : in  ewok.exported.gpios.t_gpio_ref)
      return ewok.exported.gpios.t_gpio_config;

--private

   type t_gpio_state is record
      used        : boolean                           := false;
      task_id     : ewok.tasks_shared.t_task_id       := ID_UNUSED;
      device_id   : ewok.devices_shared.t_device_id   := ID_DEV_UNUSED;
      config      : ewok.exported.gpios.t_gpio_config;
   end record
      with dynamic_predicate => (if used then task_id /= ID_UNUSED);

   -- Keep track of used GPIO points
   gpio_points : array (soc.gpio.t_gpio_port_index, soc.gpio.t_gpio_pin_index)
      of t_gpio_state :=
        (others => (others => <>));

end ewok.gpio;
