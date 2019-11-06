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
with soc.interrupts;    use soc.interrupts;

package ewok.isr
   with spark_mode => on
is

   procedure postpone_isr
     (intr     : in soc.interrupts.t_interrupt;
      handler  : in system_address;
      task_id  : in ewok.tasks_shared.t_task_id)
   with
      pre =>
         intr >= soc.interrupts.INT_WWDG and
         task_id /= ID_UNUSED;

end ewok.isr;
