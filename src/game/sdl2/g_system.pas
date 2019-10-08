(* Copyright (C)  Doom 2D: Forever Developers
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License ONLY.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *)
{$INCLUDE ../shared/a_modes.inc}
unit g_system;

interface

  uses Utils;

  (* --- Utils --- *)
  function sys_GetTicks (): Int64;
  procedure sys_Delay (ms: Integer);

  (* --- Graphics --- *)
  function sys_GetDispalyModes (bpp: Integer): SSArray;
  function sys_SetDisplayMode (w, h, bpp: Integer; fullscreen: Boolean): Boolean;
  procedure sys_EnableVSync (yes: Boolean);
  procedure sys_Repaint;

  (* --- Input --- *)
  function sys_HandleInput (): Boolean;
  procedure sys_RequestQuit;

  (* --- Init --- *)
  procedure sys_Init;
  procedure sys_Final;

implementation

  uses
    SysUtils, SDL2, GL, Math,
    e_log, e_graphics, e_input,
    g_touch,
    g_options, g_window, g_console, g_game, g_menu, g_gui, g_main;

  const
    GameTitle = 'Doom 2D: Forever (SDL 2)';

  var
    window: PSDL_Window;
    context: TSDL_GLContext;
    display: Integer;
    JoystickHandle: array [0..e_MaxJoys - 1] of PSDL_Joystick;
    JoystickHatState: array [0..e_MaxJoys - 1, 0..e_MaxJoyHats - 1, HAT_LEFT..HAT_DOWN] of Boolean;
    JoystickZeroAxes: array [0..e_MaxJoys - 1, 0..e_MaxJoyAxes - 1] of Integer;

  (* --------- Utils --------- *)

  function sys_GetTicks (): Int64;
  begin
    result := SDL_GetTicks()
  end;

  procedure sys_Delay (ms: Integer);
  begin
    SDL_Delay(ms)
  end;

  (* --------- Graphics --------- *)

  procedure UpdateSize (w, h: Integer);
  begin
    gWinSizeX := w;
    gWinSizeY := h;
    gWinRealPosX := 0;
    gWinRealPosY := 0;
    gScreenWidth := w;
    gScreenHeight := h;
    {$IFDEF ENABLE_HOLMES}
      fuiScrWdt := w;
      fuiScrHgt := h;
    {$ENDIF}
    e_ResizeWindow(w, h);
    e_InitGL;
    g_Game_SetupScreenSize;
    g_Menu_Reset;
    g_Game_ClearLoading;
  end;

  function InitWindow (w, h, bpp: Integer; fullScreen: Boolean): Boolean;
    var flags: UInt32;
  begin
    e_LogWritefln('InitWindow %s %s %s %s', [w, h, bpp, fullScreen]);
    result := false;
    if window = nil then
    begin
      {$IFDEF USE_GLES1}
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 1);
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 1);
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_ES);
      {$ELSE}
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2);
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 1);
        SDL_GL_SetAttribute(SDL_GL_RED_SIZE, 8);
        SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE, 8);
        SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE, 8);
        SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 16);
        SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
        SDL_GL_SetAttribute(SDL_GL_STENCIL_SIZE, 8); // lights; it is enough to have 1-bit stencil buffer for lighting, but...
      {$ENDIF}
      flags := SDL_WINDOW_OPENGL or SDL_WINDOW_RESIZABLE;
      if fullScreen then flags := flags or SDL_WINDOW_FULLSCREEN;
      window := SDL_CreateWindow(GameTitle, SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, w, h, flags);
      if window <> nil then
      begin
        context := SDL_GL_CreateContext(window);
        if context <> nil then
        begin
          UpdateSize(w, h);
          result := true
        end
        else
        begin
          e_LogWritefln('SDL: unable to create OpenGL context: %s', [SDL_GetError])
        end
      end
      else
      begin
        e_LogWritefln('SDL: unable to create window: %s', [SDL_GetError])
      end
    end
    else
    begin
      if fullScreen then flags := SDL_WINDOW_FULLSCREEN else flags := 0;
      SDL_SetWindowSize(window, w, h);
      SDL_SetWindowFullscreen(window, flags);
      UpdateSize(w, h);
      result := true
    end
  end;

  procedure sys_Repaint;
  begin
    SDL_GL_SwapWindow(window)
  end;

  procedure sys_EnableVSync (yes: Boolean);
  begin
    if yes then
      SDL_GL_SetSwapInterval(1)
    else
      SDL_GL_SetSwapInterval(0)
  end;

  function sys_GetDispalyModes (bpp: Integer): SSArray;
    var i, count, num, pw, ph: Integer; m: TSDL_DisplayMode;
  begin
    result := nil;
    num := SDL_GetNumDisplayModes(display);
    if num < 0 then
      e_LogWritefln('SDL: unable to get numer of available display modes: %s', [SDL_GetError]);
    if num > 0 then
    begin
      e_LogWritefln('Video modes for display %s:', [display]);
      SetLength(result, num);
      i := 0; count := 0; pw := 0; ph := 0;
      while i < num do
      begin
        SDL_GetDisplayMode(display, i, @m);
        if ((pw <> m.w) or (ph <> m.h)) then
        begin
          e_LogWritefln('* %sx%sx%s@%s', [m.w, m.h, SDL_BITSPERPIXEL(m.format), m.refresh_rate]);
          pw := m.w; ph := m.h;
          result[count] := IntToStr(m.w) + 'x' + IntToStr(m.h);
          Inc(count);
        end
        else
        begin
          e_LogWritefln('- %sx%sx%s@%s', [m.w, m.h, SDL_BITSPERPIXEL(m.format), m.refresh_rate]);
        end;
        Inc(i)
      end;
      SetLength(result, count)
    end
  end;

  function sys_SetDisplayMode (w, h, bpp: Integer; fullScreen: Boolean): Boolean;
  begin
    result := InitWindow(w, h, bpp, fullScreen)
  end;

  (* --------- Joystick --------- *)

  procedure HandleJoyButton (var ev: TSDL_JoyButtonEvent);
    var down: Boolean; key: Integer;
  begin
    if (ev.which < e_MaxJoys) and (ev.button < e_MaxJoyBtns) then
    begin
      key := e_JoyButtonToKey(ev.which, ev.button);
      down := ev.type_ = SDL_JOYBUTTONDOWN;
      if g_dbg_input then
        e_LogWritefln('Input Debug: jbutton, joy=%s, button=%s, keycode=%s, press=%s', [ev.which, ev.button, key, down]);
      e_KeyUpDown(key, down);
      g_Console_ProcessBind(key, down)
    end
    else
    begin
      if g_dbg_input then
      begin
        down := ev.type_ = SDL_JOYBUTTONDOWN;
        e_LogWritefln('Input Debug: NOT IN RANGE! jbutton, joy=%s, button=%s, press=%s', [ev.which, ev.button, down])
      end
    end
  end;

  procedure HandleJoyAxis (var ev: TSDL_JoyAxisEvent);
    var key, minuskey: Integer;
  begin
    if (ev.which < e_MaxJoys) and (ev.axis < e_MaxJoyAxes) then
    begin
      key := e_JoyAxisToKey(ev.which, ev.axis, AX_PLUS);
      minuskey := e_JoyAxisToKey(ev.which, ev.axis, AX_MINUS);

      if g_dbg_input then
          e_LogWritefln('Input Debug: jaxis, joy=%s, axis=%s, value=%s, zeroaxes=%s, deadzone=%s', [ev.which, ev.axis, ev.value, JoystickZeroAxes[ev.which, ev.axis], e_JoystickDeadzones[ev.which]]);

      if ev.value < JoystickZeroAxes[ev.which, ev.axis] - e_JoystickDeadzones[ev.which] then
      begin
        if (e_KeyPressed(key)) then
        begin
          e_KeyUpDown(key, False);
          g_Console_ProcessBind(key, False)
        end;
        e_KeyUpDown(minuskey, True);
        g_Console_ProcessBind(minuskey, True)
      end
      else if ev.value > JoystickZeroAxes[ev.which, ev.axis] + e_JoystickDeadzones[ev.which] then
      begin
        if (e_KeyPressed(minuskey)) then
        begin
          e_KeyUpDown(minuskey, False);
          g_Console_ProcessBind(minuskey, False)
        end;
        e_KeyUpDown(key, True);
        g_Console_ProcessBind(key, True)
      end
      else
      begin
        if (e_KeyPressed(minuskey)) then
        begin
          e_KeyUpDown(minuskey, False);
          g_Console_ProcessBind(minuskey, False)
        end;
        if (e_KeyPressed(key)) then
        begin
          e_KeyUpDown(key, False);
          g_Console_ProcessBind(key, False)
        end
      end
    end
    else
    begin
      if g_dbg_input then
        e_LogWritefln('Input Debug: NOT IN RANGE! jaxis, joy=%s, axis=%s, value=%s, zeroaxes=%s, deadzone=%s', [ev.which, ev.axis, ev.value, JoystickZeroAxes[ev.which, ev.axis], e_JoystickDeadzones[ev.which]])
    end
  end;

  procedure HandleJoyHat (var ev: TSDL_JoyHatEvent);
    var
      down: Boolean;
      i, key: Integer;
      hat: array [HAT_LEFT..HAT_DOWN] of Boolean;
  begin
    if (ev.which < e_MaxJoys) and (ev.hat < e_MaxJoyHats) then
    begin
      if g_dbg_input then
        e_LogWritefln('Input Debug: jhat, joy=%s, hat=%s, value=%s', [ev.which, ev.hat, ev.value]);
      hat[HAT_UP] := LongBool(ev.value and SDL_HAT_UP);
      hat[HAT_DOWN] := LongBool(ev.value and SDL_HAT_DOWN);
      hat[HAT_LEFT] := LongBool(ev.value and SDL_HAT_LEFT);
      hat[HAT_RIGHT] := LongBool(ev.value and SDL_HAT_RIGHT);
      for i := HAT_LEFT to HAT_DOWN do
      begin
        if JoystickHatState[ev.which, ev.hat, i] <> hat[i] then
        begin
          down := hat[i];
          key := e_JoyHatToKey(ev.which, ev.hat, i);
          e_KeyUpDown(key, down);
          g_Console_ProcessBind(key, down)
        end
      end;
      JoystickHatState[ev.which, ev.hat] := hat
    end
    else
    begin
      if g_dbg_input then
        e_LogWritefln('Input Debug: NOT IN RANGE! jhat, joy=%s, hat=%s, value=%s', [ev.which, ev.hat, ev.value])
    end
  end;

  procedure HandleJoyAdd (var ev: TSDL_JoyDeviceEvent);
    var i: Integer;
  begin
    if (ev.which < e_MaxJoys) then
    begin
      JoystickHandle[ev.which] := SDL_JoystickOpen(ev.which);
      if JoystickHandle[ev.which] <> nil then
      begin
        e_LogWritefln('Added Joystick %s', [ev.which]);
        e_JoystickAvailable[ev.which] := True;
        for i := 0 to Min(SDL_JoystickNumAxes(JoystickHandle[ev.which]), e_MaxJoyAxes) - 1 do
          JoystickZeroAxes[ev.which, i] := SDL_JoystickGetAxis(JoystickHandle[ev.which], i)
      end
      else
      begin
        e_LogWritefln('Warning! Failed to open Joystick %s', [ev.which])
      end
    end
    else
    begin
      e_LogWritefln('Warning! Added Joystick %s, but we support only <= %s', [ev.which, e_MaxJoys])
    end
  end;

  procedure HandleJoyRemove (var ev: TSDL_JoyDeviceEvent);
  begin
    e_LogWritefln('Removed Joystick %s', [ev.which]);
    if (ev.which < e_MaxJoys) then
    begin
      e_JoystickAvailable[ev.which] := False;
      if JoystickHandle[ev.which] <> nil then
        SDL_JoystickClose(JoystickHandle[ev.which]);
      JoystickHandle[ev.which] := nil
    end
  end;

  (* --------- Input --------- *)

  function HandleWindow (var ev: TSDL_WindowEvent): Boolean;
  begin
    result := false;
    case ev.event of
      SDL_WINDOWEVENT_RESIZED: UpdateSize(ev.data1, ev.data2);
      SDL_WINDOWEVENT_EXPOSED: sys_Repaint;
      SDL_WINDOWEVENT_CLOSE: result := true;
    end
  end;

  procedure HandleKeyboard (var ev: TSDL_KeyboardEvent);
    var down: Boolean; key: Integer;
  begin
    key := ev.keysym.scancode;
    down := (ev.type_ = SDL_KEYDOWN);
    if key = SDL_SCANCODE_AC_BACK then
      key := SDL_SCANCODE_ESCAPE;
    if ev._repeat = 0 then
    begin
      if g_dbg_input then
        e_LogWritefln('Input Debug: keysym, press=%s, scancode=%s', [down, key]);
      e_KeyUpDown(key, down);
      g_Console_ProcessBind(key, down);
    end
    else if gConsoleShow or gChatShow or (g_ActiveWindow <> nil) then
    begin
      KeyPress(key) // key repeat in menus and shit
    end
  end;

  procedure HandleTextInput (var ev: TSDL_TextInputEvent);
    var ch: UnicodeChar; sch: AnsiChar;
  begin
    if g_dbg_input then
      e_LogWritefln('Input Debug: text, text=%s', [ev.text]);
    Utf8ToUnicode(@ch, PChar(ev.text), 1);
    if IsValid1251(Word(ch)) then
    begin
      sch := AnsiChar(wchar2win(ch));
      CharPress(sch);
    end;
  end;

  function sys_HandleInput (): Boolean;
    var ev: TSDL_Event;
  begin
    result := false;
    while SDL_PollEvent(@ev) <> 0 do
    begin
      case ev.type_ of
        SDL_QUITEV: result := true;
        SDL_WINDOWEVENT: result := HandleWindow(ev.window);
        SDL_KEYUP, SDL_KEYDOWN: HandleKeyboard(ev.key);
        SDL_JOYBUTTONDOWN, SDL_JOYBUTTONUP: HandleJoyButton(ev.jbutton);
        SDL_JOYAXISMOTION: HandleJoyAxis(ev.jaxis);
        SDL_JOYHATMOTION: HandleJoyHat(ev.jhat);
        SDL_JOYDEVICEADDED: HandleJoyAdd(ev.jdevice);
        SDL_JOYDEVICEREMOVED: HandleJoyRemove(ev.jdevice);
        SDL_TEXTINPUT: HandleTextInput(ev.text);
        SDL_FINGERMOTION, SDL_FINGERDOWN, SDL_FINGERUP: g_Touch_HandleEvent(ev.tfinger);
      end
    end
  end;

  procedure sys_RequestQuit;
    var ev: TSDL_Event;
  begin
    ev.type_ := SDL_QUITEV;
    SDL_PushEvent(@ev)
  end;

  (* --------- Init --------- *)

  procedure sys_Init;
    var flags: UInt32; ok: Boolean;
  begin
    e_WriteLog('Init SDL2', TMsgType.Notify);
    {$IFDEF HEADLESS}
      {$IFDEF USE_SDLMIXER}
        flags := SDL_INIT_TIMER or SDL_INIT_AUDIO or $00004000;
      {$ELSE}
        flags := SDL_INIT_TIMER or $00004000;
      {$ENDIF}
    {$ELSE}
      flags := SDL_INIT_JOYSTICK or SDL_INIT_TIMER or SDL_INIT_VIDEO;
    {$ENDIF}
    SDL_SetHint(SDL_HINT_ACCELEROMETER_AS_JOYSTICK, '0');
    if SDL_Init(flags) <> 0 then
      raise Exception.Create('SDL: Init failed: ' + SDL_GetError);
    ok := InitWindow(gScreenWidth, gScreenHeight, gBPP, gFullscreen);
    if not ok then
      raise Exception.Create('SDL: Failed to set videomode: ' + SDL_GetError);
  end;

  procedure sys_Final;
  begin
    e_WriteLog('Releasing SDL2', TMsgType.Notify);
    if context <> nil then
      SDL_GL_DeleteContext(context);
    if window <> nil then
      SDL_DestroyWindow(window);
    window := nil;
    context := nil;
    SDL_Quit
  end;

initialization
  conRegVar('sdl2_display_index', @display, 'use display index as base', '');
end.
