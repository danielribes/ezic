-module(ezic_generator).
-export([generate/0]).
-include("include/ezic.hrl").

generate() ->
  {ok, Zones, Rules, _, _} = ezic_record:separate(ezic_loader:load()),
  FlatZones = ezic_flatten:flatten(Zones, Rules),

  filelib:ensure_dir("zones/"),
  {ok, MapFile} = file:open("zones/ezic_zone_map.erl", [write]),
  file:write(MapFile, "-module(ezic_zone_map).\n"),
  file:write(MapFile, "-export([find/1]).\n"),
  generate_files(FlatZones, MapFile, []),
  ok.

generate_files([], MapFile, Files) ->
  lists:foreach(fun({_, File}) ->
    file:write(File, "]."),
    file:close(File)
  end, Files),

  file:write(MapFile, "find(Z) -> throw({zone_not_found, Z}).\n"),
  file:close(MapFile);

generate_files([FlatZone = #flatzone{tzname = Name} | Rest], MapFile, Files) ->
  {File, NewFiles} = case orddict:find(Name, Files) of
    error ->
      IO = create_file(Name, MapFile),
      {IO, orddict:store(Name, IO, Files)};
    {ok, IO} ->
      file:write(IO, ",\n"),
      {IO, Files}
  end,
  file:write(File, io_lib:format("~1000p", [FlatZone])),
  generate_files(Rest, MapFile, NewFiles).

create_file(ZoneName, MapFile) ->
  io:format("Creating file for zone ~p~n", [ZoneName]),
  ModuleName = "ezic_zone_" ++ re:replace(string:to_lower(ZoneName), "/", "_", [global, {return, list}]),
  FileName = "zones" ++ "/" ++ ModuleName ++ ".erl",
  {ok, File} = file:open(FileName, [write]),
  file:write(File, io_lib:format("-module(~p).\n", [list_to_atom(ModuleName)])),
  file:write(File, "-export([flatzones/0]).\n"),
  file:write(File, "flatzones() ->\n["),
  file:write(MapFile, io_lib:format("find(~p) -> ~p;\n", [ZoneName, list_to_atom(ModuleName)])),
  File.
