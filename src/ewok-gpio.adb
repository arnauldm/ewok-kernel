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

with ewok.debug;
with ewok.exported.gpios; use ewok.exported.gpios;
with soc.gpio;            use type soc.gpio.t_gpio_pin_index;
                          use type soc.gpio.t_gpio_port_index;

package body ewok.gpio
   with spark_mode => on
is

   function is_used
     (ref : ewok.exported.gpios.t_gpio_ref)
      return boolean
   is
   begin
      return gpio_points(ref.port, ref.pin).used;
   end is_used;


   procedure register
     (task_id     : in  ewok.tasks_shared.t_task_id;
      device_id   : in  ewok.devices_shared.t_device_id;
      gpio_config : in  ewok.exported.gpios.t_gpio_config;
      success     : out boolean)
   is
      ref : constant ewok.exported.gpios.t_gpio_ref := gpio_config.kref;
   begin
      if gpio_points(ref.port, ref.pin).used then
         pragma DEBUG (debug.log (debug.ERROR, "Registering GPIO: port" &
            soc.gpio.t_gpio_port_index'image (ref.port) & ", pin" &
            soc.gpio.t_gpio_pin_index'image (ref.pin) & " is already used."));
         success := false;
      else
         gpio_points(ref.port, ref.pin).used       := true;
         gpio_points(ref.port, ref.pin).task_id    := task_id;
         gpio_points(ref.port, ref.pin).device_id  := device_id;
         gpio_points(ref.port, ref.pin).config     := gpio_config;
         success := true;
      end if;
   end register;


   procedure release
     (task_id     : in  ewok.tasks_shared.t_task_id;
      device_id   : in  ewok.devices_shared.t_device_id;
      gpio_config : in  ewok.exported.gpios.t_gpio_config)
   is
      ref : constant ewok.exported.gpios.t_gpio_ref := gpio_config.kref;
   begin
      if gpio_points(ref.port, ref.pin).task_id   /= task_id   or
         gpio_points(ref.port, ref.pin).device_id /= device_id
      then
         raise program_error; -- Should never happen
      else
         gpio_points(ref.port, ref.pin).used       := false;
         gpio_points(ref.port, ref.pin).task_id    := ID_UNUSED;
         gpio_points(ref.port, ref.pin).device_id  := ID_DEV_UNUSED;
         gpio_points(ref.port, ref.pin).config     := (others => <>);
      end if;
   end release;


   procedure config
     (gpio_config : in ewok.exported.gpios.t_gpio_config)
   is
      pragma warnings (off);
      function to_pin_alt_func is new ada.unchecked_conversion
        (unsigned_32, soc.gpio.t_pin_alt_func);
      pragma warnings (on);
   begin

      -- Enable RCC
      soc.gpio.enable_clock (gpio_config.kref.port);

      if gpio_config.settings.set_mode then
         soc.gpio.set_mode
           (gpio_config.kref.port,
            gpio_config.kref.pin,
            soc.gpio.t_pin_mode'val
              (t_interface_gpio_mode'pos (gpio_config.mode)));
      end if;

      if gpio_config.settings.set_type then
         soc.gpio.set_type
           (gpio_config.kref.port,
            gpio_config.kref.pin,
            soc.gpio.t_pin_output_type'val
               (t_interface_gpio_type'pos (gpio_config.otype)));
      end if;

      if gpio_config.settings.set_speed then
         soc.gpio.set_speed
           (gpio_config.kref.port,
            gpio_config.kref.pin,
            soc.gpio.t_pin_output_speed'val
              (t_interface_gpio_speed'pos (gpio_config.ospeed)));
      end if;

      if gpio_config.settings.set_pupd then
         soc.gpio.set_pupd
           (gpio_config.kref.port,
            gpio_config.kref.pin,
            soc.gpio.t_pin_pupd'val
              (t_interface_gpio_pupd'pos (gpio_config.pupd)));
      end if;

      if gpio_config.settings.set_bsr_r then
         soc.gpio.set_bsr_r
           (gpio_config.kref.port,
            gpio_config.kref.pin,
            types.to_bit (gpio_config.bsr_r));
      end if;

      if gpio_config.settings.set_bsr_s then
         soc.gpio.set_bsr_s
           (gpio_config.kref.port,
            gpio_config.kref.pin,
            types.to_bit (gpio_config.bsr_s));
      end if;

      -- FIXME - Writing to LCKR register requires a specific sequence
      --         describe in section 8.4.8 (RM 00090)
      if gpio_config.settings.set_lck then
         soc.gpio.set_lck
           (gpio_config.kref.port,
            gpio_config.kref.pin,
            soc.gpio.t_pin_lock'val (gpio_config.lck));
      end if;

      if gpio_config.settings.set_af then
         soc.gpio.set_af
           (gpio_config.kref.port,
            gpio_config.kref.pin,
            to_pin_alt_func (gpio_config.af));
      end if;

   end config;


   procedure write_pin
     (ref      : in  ewok.exported.gpios.t_gpio_ref;
      value    : in  bit)
   is
   begin
      soc.gpio.write_pin (ref.port, ref.pin, value);
   end write_pin;


   function read_pin
     (ref      : ewok.exported.gpios.t_gpio_ref)
      return bit
   is
      value : bit;
   begin
      soc.gpio.read_pin (ref.port, ref.pin, value);
      return value;
   end read_pin;


   function belong_to
     (task_id     : ewok.tasks_shared.t_task_id;
      ref         : ewok.exported.gpios.t_gpio_ref)
      return boolean
   is
   begin
      if gpio_points(ref.port, ref.pin).used and
         gpio_points(ref.port, ref.pin).task_id = task_id
      then
         return true;
      else
         return false;
      end if;
   end belong_to;


   function get_task_id
     (ref      : in  ewok.exported.gpios.t_gpio_ref)
      return ewok.tasks_shared.t_task_id
   is
   begin
      return gpio_points(ref.port, ref.pin).task_id;
   end get_task_id;


   function get_device_id
     (ref      : in  ewok.exported.gpios.t_gpio_ref)
      return ewok.devices_shared.t_device_id
   is
   begin
      return gpio_points(ref.port, ref.pin).device_id;
   end get_device_id;


   function get_config
     (ref      : in  ewok.exported.gpios.t_gpio_ref)
      return ewok.exported.gpios.t_gpio_config
   is
   begin
      return gpio_points(ref.port, ref.pin).config;
   end get_config;

end ewok.gpio;
