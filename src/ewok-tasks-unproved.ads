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

with soc.layout;


package ewok.tasks.unproved
   with spark_mode => on
is

   -- create various task's stack
   -- preconditions :
   -- Here we check that generated headers, defining stack address and
   -- program counter of various stack are valid for the currently
   -- supported SoC. This is a sanitizing function for generated files.
   procedure create_stack
     (sp       : in  system_address;
      pc       : in  system_address;
      params   : in  ewok.t_parameters;
      frame_a  : out ewok.t_stack_frame_access)
      with
         -- precondition 1 : stack pointer must be in RAM
         pre =>
           (
            (sp >= soc.layout.USER_RAM_BASE and
             sp <= (soc.layout.USER_RAM_BASE + soc.layout.USER_RAM_SIZE)) or
            (sp >= soc.layout.KERNEL_RAM_BASE and
             sp <= (soc.layout.KERNEL_RAM_BASE + soc.layout.KERNEL_RAM_SIZE))
           ) and (
         -- precondition 2 : program counter must be in flash
            pc >= soc.layout.FLASH_BASE and
            pc <= soc.layout.FLASH_BASE + soc.layout.FLASH_SIZE
           ),
         post => frame_a /= NULL,
         global => ( in_out => tasks_list );

   procedure set_default_values (tsk : out t_task);

   procedure init_softirq_task;
   procedure init_idle_task;
   procedure init_apps;

   procedure task_init
      with global => null;



end ewok.tasks.unproved;
