#!/usr/bin/env python3

import sys
# with collection, we keep the same device order as the json file
import json, collections
import re

if len(sys.argv) != 3:
    print("usage: ", sys.argv[0], "<mode> <filename.json>\n");
    sys.exit(1);

# mode is ADA
mode = sys.argv[1];
filename = sys.argv[2];

########################################################
# Ada file header and footer
########################################################
# print type:
ada_header = """
-- @file devmap.ads
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
-- This file has been generated by tools/devmap.py
--
--

with soc.interrupts; use soc.interrupts;
with soc.dma;

package soc.devmap
   with spark_mode => on
is

   type t_interrupt_range is range 1 .. 4;
   type t_interrupt_list is array (t_interrupt_range)
      of soc.interrupts.t_interrupt;

   -- Structure defining the STM32 device map
   -- This table is based on doc STMicro RM0090 Reference manual memory map
   -- Only devices that may be registered in userspace are defined here

   type t_periph_info is record
      name             : string (1 .. 16);
      addr             : system_address;
      size             : unsigned_32;
      subregions       : unsigned_8;
      interrupt_list   : t_interrupt_list;
      ro               : boolean;
   end record;

   -- STM32F4 devices map
   -- This structure define all available devices and associated informations.
   -- This informations are separated in two parts:
   --   - physical information (IRQ lines, RCC references, physical address...)
   --   - security information (required permissions, usage restriction...)
""";


ada_footer= """);

   function find_periph
     (addr     : system_address;
      size     : unsigned_32)
      return t_periph_id;

   function find_dma_periph
     (id       : soc.dma.t_dma_periph_index;
      stream   : soc.dma.t_stream_index)
      return t_periph_id
         with
            post => find_dma_periph'result /= NO_PERIPH;


end soc.devmap;
""";



if re.match(r'^ADA$', mode):
    header = ada_header;
    footer = ada_footer;
else:
    print("Error ! Unsupported mode: %s" % mode);
    exit(1);


with open(filename, "r") as jsonfile:
    data = json.load(jsonfile, object_pairs_hook=collections.OrderedDict);


def hex_to_adahex(val):
    if not re.match(r'^0$', val):
        hexa = re.sub(r'0x', '16#', val);
        hexa = re.sub(r'$', '#', hexa);
    else:
        hexa = val;
    return hexa;

def bin_to_adabin(val):
    if not re.match(r'^0$', val):
        hexa = re.sub(r'0b', '2#', val);
        hexa = re.sub(r'$', '#', hexa);
    else:
        hexa = val;
    return hexa;

def lookahead(iterable):
    """Pass through all values from the given iterable, augmented by the
       information if there are more values to come after the current one
       (True), or if it is the last value (False).
    """
    # Get an iterator and pull the first value.
    it = iter(iterable)
    last = next(it)
    # Run the iterator to exhaustion (starting from the second value).
    for val in it:
        # Report the *previous* value (more to come).
        yield last, True
        last = val
        # Report the last value.
    yield last, False


def generate_ada():
    # not yet operational:
    # we do not print out peripheral, and as is, last devices may be
    # unprinted ones
    print("   type t_periph_id is (");
    print("      NO_PERIPH");
    for device, has_more in lookahead(data):
        if device["type"] != "block":
            continue;
        dev_id = device["name"].upper();
        dev_id = re.sub(r'-', '_', dev_id);
        print("     ,%s" % dev_id);
    print("   );\n\n");

    print("   periphs : constant array (t_periph_id range t_periph_id'succ (t_periph_id'first) .. t_periph_id'last) of t_periph_info := (");
    counter = 1
    for device, has_more in lookahead(data):
        if device["type"] != "block":
            continue;
        dev_id = device["name"].upper();
        dev_id = re.sub(r'-', '_', dev_id);
        dev_id = dev_id.ljust(16)[:16];

        if counter > 1:
            print("   ,%s => " % dev_id, end='');
        else:
            print("    %s => " % dev_id, end='');
        counter = counter + 1;

        # device name
        print("( \"%s\", " % dev_id, end='');

        # device address
        print("%s, " % hex_to_adahex(device["address"]), end='');

        # device size
        print("%s, " % hex_to_adahex(device["size"]), end='');

        # device memory mapping mask
        print("%s, " % bin_to_adabin(device["memory_subregion_mask"]), end='');

        # device irq
        if 'irqs' in device:
           irqs = device["irqs"];
           print("( ", end='');
           print("t_interrupt'val(%s)" % irqs[0]["value"], end='');
           for irq in irqs[1:]:
               print(", t_interrupt'val(%s)" % irq["value"], end='');
           if len(irqs) < 4:
               for i in range(len(irqs), 4):
                   print(", INT_NONE", end='');
           print(" ), ", end='');
        else:
           print("( INT_NONE, INT_NONE, INT_NONE, INT_NONE ), ", end='');

        # device mapping ro ?
        print("%s)" % device["read_only"]);
#print data;

print(header);

if re.match(r'^ADA$', mode):
   generate_ada();

print(footer);
