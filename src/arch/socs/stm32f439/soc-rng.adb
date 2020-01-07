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

with soc.devmap;
with soc.rcc;

package body soc.rng
   with spark_mode => on
is

   procedure init
     (success : out boolean)
   is
      data_ready  : boolean;
      seed_error  : boolean;
      clock_error : boolean;
   begin

      soc.rcc.enable_clock (soc.devmap.RNG);
      RNG.CR.RNGEN := true;

      loop
         data_ready := RNG.SR.DRDY;
         exit when data_ready;
      end loop;

      seed_error  := RNG.SR.SECS;
      clock_error := RNG.SR.CECS;
      if seed_error or clock_error then
         success := false;
      else
         success := true;
      end if;

      last_random := RNG.DR.RNDATA;
   end init;


   procedure random
     (rand     : out unsigned_32;
      success  : out boolean)
   is
      data_ready  : boolean;
      seed_error  : boolean;
   begin

      loop
         data_ready := RNG.SR.DRDY;
         exit when data_ready;
      end loop;

      rand        := RNG.DR.RNDATA;
      seed_error  := RNG.SR.SECS;

      if rand = last_random or seed_error then
         success := false;
      else
         success := true;
      end if;
   end random;


end soc.rng;
