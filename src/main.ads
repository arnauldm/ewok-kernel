with soc.dwt;

procedure main
   with
      spark_mode      => on,
      convention      => c,
      export          => true,
      external_name   => "ewok_main",
      pre             => not soc.dwt.init_done;
