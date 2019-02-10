(* Copyright (C)  Doom 2D: Forever Developers
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *)
{$INCLUDE a_modes.inc}
{.$MODE OBJFPC}
unit envvars;

interface

  uses SysUtils, CTypes;

  function SetEnvVar(const VarName: AnsiString; const VarVal: AnsiString): Boolean;
  function GetUserName: String;

implementation

  uses
{$IFDEF WINDOWS}
    Windows,
{$ENDIF}
    utils;


{$IFDEF WINDOWS}
function setenv(const VarStr: PChar; const VarVal: PChar; Repl: cint): cint;
begin
  if (SetEnvironmentVariable(VarStr, VarVal)) then
    Result := 0
  else
    Result := -1;
end;
{$ELSE}
  {$IFDEF GO32V2}
    function setenv(const VarStr: PChar; const VarVal: PChar; Repl: cint): cint;
    begin
      {$WARNING setenv stub!}
      result := 0
    end;
  {$ELSE}
    {$LINKLIB c}
    const clib = 'c';
    function setenv(const VarStr: PChar; const VarVal: PChar; Repl: cint): cint; cdecl; external clib name 'setenv';
  {$ENDIF}
{$ENDIF}

function SetEnvVar(const VarName: AnsiString; const VarVal: AnsiString): Boolean;
begin
  Result := (setenv(PChar(VarName), PChar(VarVal), 1) = 0);
end;

  (* Get system username already in cp1251 *)
  function GetUserName: AnsiString;
    var i: Integer;
  begin
    {$IF DEFINED(WINDOWS)}
      Result := utf2win(UTF8String(SysUtils.GetEnvironmentVariable(WideString('USERNAME'))));
    {$ELSEIF DEFINED(UNIX)}
      Result := utf2win(SysUtils.GetEnvironmentVariable('USER'));
    {$ELSE}
      Result := '';
    {$ENDIF}
    (* invalidate username with non-cp1251 symbols *)
    i := Low(Result);
    while i <= High(Result) do
    begin
      if Result[i] = '?' then
        Result := '';
      Inc(i)
    end
  end;

end.
