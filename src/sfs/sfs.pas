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
// streaming file system (virtual)
{$INCLUDE ../shared/a_modes.inc}
{$SCOPEDENUMS OFF}
{.$R+}
{.$DEFINE SFS_VOLDEBUG}
unit sfs;

interface

uses
  SysUtils, Classes, Contnrs;


type
  ESFSError = class(Exception);

  TSFSVolume = class;

  TSFSFileInfo = class
  public
    fOwner: TSFSVolume; // ���, �� ������ ������
    fPath: AnsiString;  // ����������� ��������� -- "/"; ������ ����� �� ���������, ���� �� ������, ������� ����������� "/"
    fName: AnsiString;  // ������ ���
    fSize: Int64;       // unpacked
    fOfs: Int64;        // in VFS (many of 'em need this %-)

    constructor Create (pOwner: TSFSVolume);
    destructor Destroy (); override;

    property path: AnsiString read fPath;
    property name: AnsiString read fName;
    property size: Int64 read fSize; // can be -1 if size is unknown
  end;

  // ����������� �������� �������. ������ ��� ������!
  // ��� �� ������ ��������� ����� �����, ��� ��� ������ �������!
  TSFSVolume = class
  protected
    fFileName: AnsiString;// ������ ��� ������������� �����
    fFileStream: TStream; // ������ ����� ��� ������ ������������� �����
    fFiles: TObjectList;  // TSFSFileInfo ��� ����������

    // ��������� ��� ���������.
    // �� ������ ������, ���� � �������� ��������� ���.
    procedure Clear (); virtual;

    // ���������� �� DoDirectoryRead() ��� ���������� ������ ������.
    // ���������, ��� ��� ������ ��� ��������� � ���� ����� ���.
    // fFileName, fFileStream ��� �����������, fFiles ������,
    // � ��, ������ �����, ������ ���.
    // ������� ������ -- ��, ��� �������� �������.
    // ��� ������� ������ ����������, ����� ��� ����� ������ ��������.
    // ����������� ����� ������ ���� ������ "/", �������� "/" ������
    // ���� ������, ���� (���� �� ������) ������ ����������� "/"!
    // fName ������ ��������� ������ ���, fPath -- ������ ����.
    // � ��������, �� ���� ����������� DoDirectoryRead(), �� �����
    // ������ ��� ������ ������?
    procedure ReadDirectory (); virtual; abstract;

    // ����� ����, ������� ��� ������ � fFiles.
    // ��� ��������� ����� ������ fFiles!
    // fPath -- � ���������� �����, � "/", �������� "/" ����, ��������� ��������.
    // ���� ���� �� ������, ������� -1.
    function FindFile (const fPath, fName: AnsiString): Integer; virtual;

    // ���������� ���������� ������ � fFiles
    function GetFileCount (): Integer; virtual;

    // ���������� ���� � �������� index.
    // ����� ���������� NIL.
    // ������� ������� �� ������������ �������!
    function GetFiles (index: Integer): TSFSFileInfo; virtual;

  public
    // pSt �� ����������� ����������, ���� �� �� �����.
    constructor Create (const pFileName: AnsiString; pSt: TStream); virtual;
    // fFileStream ���������� ������, ���� �� ����� ��������� pSt ������������.
    destructor Destroy (); override;

    // �������� ReadDirectory().
    // ��� ��������� ���� ��������� � ����������� ���: ����������� �
    // ����� ���-���������� ������������� � ���������� �����.
    // ����� ��� ����������� ��� ���.
    procedure DoDirectoryRead ();

    // ��� ������� �������� ������������.
    function OpenFileByIndex (const index: Integer): TStream; virtual; abstract;

    // ���� �� ������ ���������� ����� (��� ��� ��� ��������), �������� ����������.
    function OpenFileEx (const fName: AnsiString): TStream; virtual;

    property FileCount: Integer read GetFileCount; // ����� ������� ����
    // ����� ���������� NIL.
    // ������� ������� �� ������������ �������!
    property Files [index: Integer]: TSFSFileInfo read GetFiles;
  end;

  // ������� �����. ��� SFS ��� ������ ��������� ���� �������.
  // ��������� ����� ����� ��������� ������ ������ SFS �����������
  // ������� ����������� ���������.
  // ������� �� ������ ��������� ����� �����, ��� ��� ������ ������
  // SFSUnregisterVolumeFactory()! ��� �����������, ��� ������
  // ����� ���������� ������ �� ��� � ����.
  TSFSVolumeFactory = class
  public
    // ���� ��������� ���� ������ ���� � ������ ���� "zip:....", ��
    // SFS �������� ��� "zip" � �������� � ��� �������.
    // ����� ������� ����� ������, �� SFS ������� Produce ��� �������
    // �����. ���� �� ���� ������� ������� �� ��������, �� ���� �� �������.
    // ������������ ��� �������� �����������.
    // SFS �� ������� ��������� ������ ������ �Ш� ��������!
    function IsMyVolumePrefix (const prefix: AnsiString): Boolean; virtual; abstract;
    // ���������, ����� �� ������� ������� ��� ��� ������� �����.
    // st -- �������� ��� ������ ������� �����. ��������� ������ ����� � ������.
    // ���� ����� ������ ���������!
    // prefix: ��, ��� ���� �������� � IsMyVolumePrefix() ��� ''.
    // ���������� ��������� �������, ������� NIL ��������� �������.
    function Produce (const prefix, fileName: AnsiString; st: TStream): TSFSVolume; virtual; abstract;
    // ����� ��� ������ �� �����, �� ����� ����� ������� �� �����������.
    // ����� ������ �� ����� ����� ��� ���.
    procedure Recycle (vol: TSFSVolume); virtual; abstract;
  end;

  // "��������", ������������ SFSFileList()
  TSFSFileList = class
  protected
    fVolume: TSFSVolume;

    function GetCount (): Integer;
    function GetFiles (index: Integer): TSFSFileInfo;

  public
    constructor Create (const pVolume: TSFSVolume);
    destructor Destroy (); override;

    property Volume: TSFSVolume read fVolume;
    property Count: Integer read GetCount;
    // ��� ������������ ������� ����� ����� NIL.
    // ��� ���������� ���� ����� ������� NIL!
    // ����� �� ������� ������ ���������� ����������� ������.
    // �������, � ��� �� ���������� ����� ��������� ��� ����� �������,
    // �� ����, ���� �� ����� � �� ������ ���� �������� ������, ��
    // ������ �� ������ � ����������� �����?
    property Files [index: Integer]: TSFSFileInfo read GetFiles; default;
  end;


procedure SFSRegisterVolumeFactory (factory: TSFSVolumeFactory);
// ��� ������� ������������� ������� factory.
procedure SFSUnregisterVolumeFactory (factory: TSFSVolumeFactory);

// �������� ������� � ���������� ������.
// ���� ������� � ����� ������ ��� ������, �� �� ��������� ��� ��������.
// ������� �� ������ ����������.
// top: �������� � ������ ������ ������.
// ����� ���� ��� ������.
// �������� ��������� �������� � ��������� ��� ������ ������ ��� a-la:
// "zip:pack0::pack:pack1::wad2:pack2".
// � ���������� ������� ���������� � �������� ��� "pack2::xxx".
// ��� ����� ��������:
// "zip:pack0::pack:pack1::wad2:pack2|datafile".
// � ���������� ��� "datafile::xxx".
// "||" ������������� � ������� "|" � ������������ �� ���������.
// ����������� �� �������� ������ ��������� �����.
function SFSAddDataFile (const dataFileName: AnsiString; top: Boolean=false): Boolean;

// �������� ������� ��������
function SFSAddDataFileTemp (const dataFileName: AnsiString; top: Boolean=false): Boolean;

// �������� � ���������� ������ ������� �� ������ ds.
// ���� ���������� ������, �� SFS ���������� ���������� ������ ds � ����
// ������� ��� ����� �� �������������.
// virtualName ���������� ������ �������� ��� �������� �������� ����� ����
// "packfile:file.ext".
// ���� �����-������ ������� � ������ virtualName ��� ������, ����� false.
// ������� �� ������ ����������.
// top: �������� � ������ ������ ������.
// ����� ���� ��� ������.
// ��������� ������� �� ������. dataFileName -- ����������� ���.
// �.�. �� ����� ���� ������ ����� ����� � �� ���� �� �����.
function SFSAddSubDataFile (const virtualName: AnsiString; ds: TStream; top: Boolean=false): Boolean;

// ��������� ������������.
// ���� fName �� ����� �������� �� ���� ������ (��� ��, ��� �������� ��
// ���������� ����� ����������), �� ���� ������� �� ���� ������������������
// ������ ������, ����� � ������� ��������, ����� � ��������, ������ ����������.
// ���� ������ �� �����, ������ ����������.
function SFSFileOpenEx (const fName: AnsiString): TStream;

// ��� ������ -- NIL, � ������� ����������.
function SFSFileOpen (const fName: AnsiString): TStream;

// ���������� NIL ��� ������.
// ����� �������������, ����������, �������� ���� �������� %-)
function SFSFileList (const dataFileName: AnsiString): TSFSFileList;

// ��������� ������������ ��������� ����� (����� �������� ����������)
procedure sfsGCDisable ();

// ��������� ������������ ��������� ����� (����� �������� ����������)
procedure sfsGCEnable ();

// for completeness sake
procedure sfsGCCollect ();

function SFSReplacePathDelims (const s: AnsiString; newDelim: Char): AnsiString;

// ��������� ������� ��� �����, ������� ����������� ��� ���������� ������
// ��� ������ �������, ���� ������� �� ����.
function SFSGetLastVirtualName (const fn: AnsiString): AnsiString;

// Wildcard matching
// this code is meant to allow wildcard pattern matches. tt is VERY useful
// for matching filename wildcard patterns. tt allows unix grep-like pattern
// comparisons, for instance:
//
//       ?       Matches any single characer
//       +       Matches any single characer or nothing
//       *       Matches any number of contiguous characters
//       [abc]   Matches a or b or c at that position
//       [!abc]  Matches anything but a or b or c at that position
//       [a-e]   Matches a through e at that position
//
//       'ma?ch.*'       -Would match match.exe, mavch.dat, march.on, etc
//       'this [e-n]s a [!zy]est' -Would match 'this is a test', but would
//                                 not match 'this as a yest'
//
function WildMatch (pattern, text: AnsiString): Boolean;
function WildListMatch (wildList, text: AnsiString; delimChar: AnsiChar=':'): Integer;
function HasWildcards (const pattern: AnsiString): Boolean;


var
  // ������: ��������� ������ ����� �� ������ � ������ ������, �� � �� �����.
  sfsDiskEnabled: Boolean = true;
  // ������: ���� ���� �� �����������, �� ������� ���� ����� �� �����,
  // ����� � ������ ������.
  sfsDiskFirst: Boolean = true;
  // ������: ���� ��� ������������� ������ ������� ���������� ����
  // (���� ���������� ������ sfsDiskFirst � sfsDiskEnabled).
  sfsForceDiskForPrefixed: Boolean = false;
  // ������ �������� ��������� ��� ������ �����. ���� ���� -- ���� ������ �
  // �������. �������� ����������� ������ ("|").
  // <currentdir> ���������� �� ������� ������� (� ����������� "/"),
  // <exedir> ���������� �� �������, ��� ����� .EXE (� ����������� "/").
  sfsDiskDirs: AnsiString = '<currentdir>|<exedir>';


implementation

uses
  xstreams, utils;


const
  // character defines
  WILD_CHAR_ESCAPE         = '\';
  WILD_CHAR_SINGLE         = '?';
  WILD_CHAR_SINGLE_OR_NONE = '+';
  WILD_CHAR_MULTI          = '*';
  WILD_CHAR_RANGE_OPEN     = '[';
  WILD_CHAR_RANGE          = '-';
  WILD_CHAR_RANGE_CLOSE    = ']';
  WILD_CHAR_RANGE_NOT      = '!';


function HasWildcards (const pattern: AnsiString): Boolean;
begin
  result :=
    (Pos(WILD_CHAR_ESCAPE, pattern) <> 0) or
    (Pos(WILD_CHAR_SINGLE, pattern) <> 0) or
    (Pos(WILD_CHAR_SINGLE_OR_NONE, pattern) <> 0) or
    (Pos(WILD_CHAR_MULTI, pattern) <> 0) or
    (Pos(WILD_CHAR_RANGE_OPEN, pattern) <> 0);
end;

function MatchMask (const pattern: AnsiString; p, pend: Integer; const text: AnsiString; t, tend: Integer): Boolean;
var
  rangeStart, rangeEnd: AnsiChar;
  rangeNot, rangeMatched: Boolean;
  ch: AnsiChar;
begin
  // sanity checks
  if (pend < 0) or (pend > Length(pattern)) then pend := Length(pattern);
  if (tend < 0) or (tend > Length(text)) then tend := Length(text);
  if t < 1 then t := 1;
  if p < 1 then p := 1;
  while p <= pend do
  begin
    if t > tend then
    begin
      // no more text. check if there's no more chars in pattern (except "*" & "+")
      while (p <= pend) and
            ((pattern[p] = WILD_CHAR_MULTI) or
             (pattern[p] = WILD_CHAR_SINGLE_OR_NONE)) do Inc(p);
      result := (p > pend);
      exit;
    end;
    case pattern[p] of
      WILD_CHAR_SINGLE: ;
      WILD_CHAR_ESCAPE:
        begin
          Inc(p);
          if p > pend then result := false else result := (pattern[p] = text[t]);
          if not result then exit;
        end;
      WILD_CHAR_RANGE_OPEN:
        begin
          result := false;
          Inc(p); if p > pend then exit; // sanity check
          rangeNot := (pattern[p] = WILD_CHAR_RANGE_NOT);
          if rangeNot then begin Inc(p); if p > pend then exit; {sanity check} end;
          if pattern[p] = WILD_CHAR_RANGE_CLOSE then exit; // sanity check
          ch := text[t]; // speed reasons
          rangeMatched := false;
          repeat
            if p > pend then exit; // sanity check
            rangeStart := pattern[p];
            if rangeStart = WILD_CHAR_RANGE_CLOSE then break;
            Inc(p); if p > pend then exit; // sanity check
            if pattern[p] = WILD_CHAR_RANGE then
            begin
              Inc(p); if p > pend then exit; // sanity check
              rangeEnd := pattern[p]; Inc(p);
              if rangeStart < rangeEnd then
              begin
                rangeMatched := (ch >= rangeStart) and (ch <= rangeEnd);
              end
              else rangeMatched := (ch >= rangeEnd) and (ch <= rangeStart);
            end
            else rangeMatched := (ch = rangeStart);
          until rangeMatched;
          if rangeNot = rangeMatched then exit;

          // skip the rest or the range
          while (p <= pend) and (pattern[p] <> WILD_CHAR_RANGE_CLOSE) do Inc(p);
          if p > pend then exit; // sanity check
        end;
      WILD_CHAR_SINGLE_OR_NONE:
        begin
          Inc(p);
          result := MatchMask(pattern, p, pend, text, t, tend);
          if not result then result := MatchMask(pattern, p, pend, text, t+1, tend);
          exit;
        end;
      WILD_CHAR_MULTI:
        begin
          while (p <= pend) and (pattern[p] = WILD_CHAR_MULTI) do Inc(p);
          result := (p > pend); if result then exit;
          while not result and (t <= tend) do
          begin
            result := MatchMask(pattern, p, pend, text, t, tend);
            Inc(t);
          end;
          exit;
        end;
      else result := (pattern[p] = text[t]); if not result then exit;
    end;
    Inc(p); Inc(t);
  end;
  result := (t > tend);
end;


function WildMatch (pattern, text: AnsiString): Boolean;
begin
  if pattern <> '' then pattern := AnsiLowerCase(pattern);
  if text <> '' then text := AnsiLowerCase(text);
  result := MatchMask(pattern, 1, -1, text, 1, -1);
end;

function WildListMatch (wildList, text: AnsiString; delimChar: AnsiChar=':'): Integer;
var
  s, e: Integer;
begin
  if wildList <> '' then wildList := AnsiLowerCase(wildList);
  if text <> '' then text := AnsiLowerCase(text);
  result := 0;
  s := 1;
  while s <= Length(wildList) do
  begin
    e := s; while e <= Length(wildList) do
    begin
      if wildList[e] = WILD_CHAR_RANGE_OPEN then
      begin
        while (e <= Length(wildList)) and (wildList[e] <> WILD_CHAR_RANGE_CLOSE) do Inc(e);
      end;
      if wildList[e] = delimChar then break;
      Inc(e);
    end;
    if s < e then
    begin
      if MatchMask(wildList, s, e-1, text, 1, -1) then exit;
    end;
    Inc(result);
    s := e+1;
  end;
  result := -1;
end;


type
  TVolumeInfo = class
  public
    fFactory: TSFSVolumeFactory;
    fVolume: TSFSVolume;
    fPackName: AnsiString; // ��� ������ � ���� �� ����� ����� ������ ���� ���!
    fStream: TStream; // �������� ����� ��� ��������
    fPermanent: Boolean; // ������ -- �� ����� ���������, ���� �� ��������� �� ������ ��������� ����
    // ������ -- ���� ��� ��� ������ �� ������ � �� ����� ��������� �����, ������ ������� ����� �������� �� ��� ��������, � ������ ������
    fNoDiskFile: Boolean;
    fOpenedFilesCount: Integer;

    destructor Destroy (); override;
  end;

  TOwnedPartialStream = class (TSFSPartialStream)
  protected
    fOwner: TVolumeInfo;

  public
    constructor Create (pOwner: TVolumeInfo; pSrc: TStream; pPos, pSize: Int64; pKillSrc: Boolean);
    destructor Destroy (); override;
  end;


var
  factories: TObjectList; // TSFSVolumeFactory
  volumes: TObjectList;   // TVolumeInfo
  gcdisabled: Integer = 0; // >0: disabled


procedure sfsGCCollect ();
var
  f, c: Integer;
  vi: TVolumeInfo;
  used: Boolean;
begin
  // collect garbage
  f := 0;
  while f < volumes.Count do
  begin
    vi := TVolumeInfo(volumes[f]);
    if (vi <> nil) and (not vi.fPermanent) and (vi.fOpenedFilesCount = 0) then
    begin
      // this volume probably can be removed
      used := false;
      c := volumes.Count-1;
      while not used and (c >= 0) do
      begin
        if (c <> f) and (volumes[c] <> nil) then
        begin
          used := (TVolumeInfo(volumes[c]).fStream = vi.fStream);
          if not used then used := (TVolumeInfo(volumes[c]).fVolume.fFileStream = vi.fStream);
          if used then break;
        end;
        Dec(c);
      end;
      if not used then
      begin
        {$IFDEF SFS_VOLDEBUG}writeln('000: destroying volume "', TVolumeInfo(volumes[f]).fPackName, '"');{$ENDIF}
        volumes.extract(vi); // remove from list
        vi.Free; // and kill
        f := 0;
        continue;
      end;
    end;
    Inc(f); // next volume
  end;
end;

procedure sfsGCDisable ();
begin
  Inc(gcdisabled);
end;

procedure sfsGCEnable ();
begin
  Dec(gcdisabled);
  if gcdisabled <= 0 then
  begin
    gcdisabled := 0;
    sfsGCCollect();
  end;
end;


// ������� ��� ����� �� �����: ������� �������� �������, ��� ����� ������,
// ���������� ��� �����
// ��� �������� ���:
// (("sfspfx:")?"datafile::")*"filename"
procedure SplitFName (const fn: AnsiString; out dataFile, fileName: AnsiString);
var
  f: Integer;
begin
  f := Length(fn)-1;
  while f >= 1 do
  begin
    if (fn[f] = ':') and (fn[f+1] = ':') then break;
    Dec(f);
  end;
  if f < 1 then begin dataFile := ''; fileName := fn; end
  else
  begin
    dataFile := Copy(fn, 1, f-1);
    fileName := Copy(fn, f+2, maxInt-10000);
  end;
end;

// ����������: �������� ����������� ��� �� dataFile.
function ExtractVirtName (var dataFile: AnsiString): AnsiString;
var
  f: Integer;
begin
  f := Length(dataFile); result := dataFile;
  while f > 1 do
  begin
    if dataFile[f] = ':' then break;
    if dataFile[f] = '|' then
    begin
      if dataFile[f-1] = '|' then begin Dec(f); Delete(dataFile, f, 1); end
      else
      begin
        result := Copy(dataFile, f+1, Length(dataFile));
        Delete(dataFile, f, Length(dataFile));
        break;
      end;
    end;
    Dec(f);
  end;
end;

// ������� ��� �������� �� �����: ������� �������� �������, ��� ����� ������,
// ����������� ���. ���� ������������ ����� �� ����, ��� ����� ����� dataFile.
// ��� �������� ���:
// [sfspfx:]datafile[|virtname]
// ���� ����� ���������� ������ ��� ����, �� ��� ��������� �� ���������,
// � ������ �����.
procedure SplitDataName (const fn: AnsiString; out pfx, dataFile, virtName: AnsiString);
var
  f: Integer;
begin
  f := Pos(':', fn);
  if f <= 3 then begin pfx := ''; dataFile := fn; end
  else
  begin
    pfx := Copy(fn, 1, f-1);
    dataFile := Copy(fn, f+1, maxInt-10000);
  end;
  virtName := ExtractVirtName(dataFile);
end;

// ����� ������������� ��� ����� ����� (���� ���� ��� ������).
// onlyPerm: ������ "����������" �������������.
function FindVolumeInfo (const dataFileName: AnsiString; onlyPerm: Boolean=false): Integer;
var
  f: Integer;
  vi: TVolumeInfo;
begin
  f := 0;
  while f < volumes.Count do
  begin
    if volumes[f] <> nil then
    begin
      vi := TVolumeInfo(volumes[f]);
      if not onlyPerm or vi.fPermanent then
      begin
        if StrEquCI1251(vi.fPackName, dataFileName) then
        begin
          result := f;
          exit;
        end;
      end;
    end;
    Inc(f);
  end;
  result := -1;
end;

// ����� ���� ��� ����� ����.
// ������� ���, ������? %-)
function FindVolumeInfoByVolumeInstance (vol: TSFSVolume): Integer;
begin
  result := volumes.Count-1;
  while result >= 0 do
  begin
    if volumes[result] <> nil then
    begin
      if TVolumeInfo(volumes[result]).fVolume = vol then exit;
    end;
    Dec(result);
  end;
end;


// adds '/' too
function normalizePath (fn: AnsiString): AnsiString;
var
  i: Integer;
begin
  result := '';
  i := 1;
  while i <= length(fn) do
  begin
    if (fn[i] = '.') and ((length(fn)-i = 0) or (fn[i+1] = '/') or (fn[i+1] = '\')) then
    begin
      i := i+2;
      continue;
    end;
    if (fn[i] = '/') or (fn[i] = '\') then
    begin
      if (length(result) > 0) and (result[length(result)] <> '/') then result := result+'/';
    end
    else
    begin
      result := result+fn[i];
    end;
    Inc(i);
  end;
  if (length(result) > 0) and (result[length(result)] <> '/') then result := result+'/';
end;

function SFSReplacePathDelims (const s: AnsiString; newDelim: Char): AnsiString;
var
  f: Integer;
begin
  result := s;
  for f := 1 to Length(result) do
  begin
    if (result[f] = '/') or (result[f] = '\') then
    begin
      // avoid unnecessary string changes
      if result[f] <> newDelim then result[f] := newDelim;
    end;
  end;
end;

function SFSGetLastVirtualName (const fn: AnsiString): AnsiString;
var
  rest, tmp: AnsiString;
  f: Integer;
begin
  rest := fn;
  repeat
    f := Pos('::', rest); if f = 0 then f := Length(rest)+1;
    tmp := Copy(rest, 1, f-1); Delete(rest, 1, f+1);
    result := ExtractVirtName(tmp);
  until rest = '';
end;


{ TVolumeInfo }
destructor TVolumeInfo.Destroy ();
var
  f, me: Integer;
  used: Boolean; // ������ ���������� ������ ���-�� ���
begin
  if fFactory <> nil then fFactory.Recycle(fVolume);
  used := false;
  fVolume := nil;
  fFactory := nil;
  fPackName := '';

  // ���� �������������: ���� ��� ����� ����� ����� �� �������, �� �������� ��� �����
  if not used then
  begin
    me := volumes.IndexOf(self);
    f := volumes.Count-1;
    while not used and (f >= 0) do
    begin
      if (f <> me) and (volumes[f] <> nil) then
      begin
        used := (TVolumeInfo(volumes[f]).fStream = fStream);
        if not used then
        begin
          used := (TVolumeInfo(volumes[f]).fVolume.fFileStream = fStream);
        end;
        if used then break;
      end;
      Dec(f);
    end;
  end;
  if not used then FreeAndNil(fStream); // ���� ������ ����� �� �����, �������
  inherited Destroy();
end;


{ TOwnedPartialStream }
constructor TOwnedPartialStream.Create (pOwner: TVolumeInfo; pSrc: TStream;
  pPos, pSize: Int64; pKillSrc: Boolean);
begin
  inherited Create(pSrc, pPos, pSize, pKillSrc);
  fOwner := pOwner;
  if pOwner <> nil then Inc(pOwner.fOpenedFilesCount);
end;

destructor TOwnedPartialStream.Destroy ();
var
  f: Integer;
begin
  inherited Destroy();
  if fOwner <> nil then
  begin
    Dec(fOwner.fOpenedFilesCount);
    if (gcdisabled = 0) and not fOwner.fPermanent and (fOwner.fOpenedFilesCount < 1) then
    begin
      f := volumes.IndexOf(fOwner);
      if f <> -1 then
      begin
        {$IFDEF SFS_VOLDEBUG}writeln('001: destroying volume "', TVolumeInfo(volumes[f]).fPackName, '"');{$ENDIF}
        volumes[f] := nil; // this will destroy the volume
      end;
    end;
  end;
end;


{ TSFSFileInfo }
constructor TSFSFileInfo.Create (pOwner: TSFSVolume);
begin
  inherited Create();
  fOwner := pOwner;
  fPath := '';
  fName := '';
  fSize := 0;
  fOfs := 0;
  if pOwner <> nil then pOwner.fFiles.Add(self);
end;

destructor TSFSFileInfo.Destroy ();
begin
  if fOwner <> nil then fOwner.fFiles.Extract(self);
  inherited Destroy();
end;


{ TSFSVolume }
constructor TSFSVolume.Create (const pFileName: AnsiString; pSt: TStream);
begin
  inherited Create();
  fFileStream := pSt;
  fFileName := pFileName;
  fFiles := TObjectList.Create(true);
end;

procedure TSFSVolume.DoDirectoryRead ();
var
  f, c: Integer;
  sfi: TSFSFileInfo;
  tmp: AnsiString;
begin
  fFileName := ExpandFileName(SFSReplacePathDelims(fFileName, '/'));
  ReadDirectory();
  fFiles.Pack();

  f := 0;
  while f < fFiles.Count do
  begin
    sfi := TSFSFileInfo(fFiles[f]);
    // normalize name & path
    sfi.fPath := SFSReplacePathDelims(sfi.fPath, '/');
    if (sfi.fPath <> '') and (sfi.fPath[1] = '/') then Delete(sfi.fPath, 1, 1);
    if (sfi.fPath <> '') and (sfi.fPath[Length(sfi.fPath)] <> '/') then sfi.fPath := sfi.fPath+'/';
    tmp := SFSReplacePathDelims(sfi.fName, '/');
    c := Length(tmp); while (c > 0) and (tmp[c] <> '/') do Dec(c);
    if c > 0 then
    begin
      // split path and name
      Delete(sfi.fName, 1, c); // cut name
      tmp := Copy(tmp, 1, c);  // get path
      if tmp = '/' then tmp := ''; // just delimiter; ignore it
      sfi.fPath := sfi.fPath+tmp;
    end;
    sfi.fPath := normalizePath(sfi.fPath);
    if (length(sfi.fPath) = 0) and (length(sfi.fName) = 0) then sfi.Free else Inc(f);
  end;
end;

destructor TSFSVolume.Destroy ();
begin
  Clear();
  FreeAndNil(fFiles);
  inherited Destroy();
end;

procedure TSFSVolume.Clear ();
begin
  fFiles.Clear();
end;

function TSFSVolume.FindFile (const fPath, fName: AnsiString): Integer;
begin
  if fFiles = nil then result := -1
  else
  begin
    result := fFiles.Count;
    while result > 0 do
    begin
      Dec(result);
      if fFiles[result] <> nil then
      begin
        if StrEquCI1251(fPath, TSFSFileInfo(fFiles[result]).fPath) and
           StrEquCI1251(fName, TSFSFileInfo(fFiles[result]).fName) then exit;
      end;
    end;
    result := -1;
  end;
end;

function TSFSVolume.GetFileCount (): Integer;
begin
  if fFiles = nil then result := 0 else result := fFiles.Count;
end;

function TSFSVolume.GetFiles (index: Integer): TSFSFileInfo;
begin
  if fFiles = nil then result := nil
  else
  begin
    if (index < 0) or (index >= fFiles.Count) then result := nil
    else result := TSFSFileInfo(fFiles[index]);
  end;
end;

function TSFSVolume.OpenFileEx (const fName: AnsiString): TStream;
var
  fp, fn: AnsiString;
  f, ls: Integer;
begin
  fp := fName;
  // normalize name, find split position
  if (fp <> '') and ((fp[1] = '/') or (fp[1] = '\')) then Delete(fp, 1, 1);
  ls := 0;
  for f := 1 to Length(fp) do
  begin
    if fp[f] = '\' then fp[f] := '/';
    if fp[f] = '/' then ls := f;
  end;
  fn := Copy(fp, ls+1, Length(fp));
  fp := Copy(fp, 1, ls);
  f := FindFile(fp, fn);
  if f = -1 then raise ESFSError.Create('file not found: "'+fName+'"');
  result := OpenFileByIndex(f);
  if result = nil then raise ESFSError.Create('file not found: "'+fName+'"');
end;


{ TSFSFileList }
constructor TSFSFileList.Create (const pVolume: TSFSVolume);
var
  f: Integer;
begin
  inherited Create();
  ASSERT(pVolume <> nil);
  f := FindVolumeInfoByVolumeInstance(pVolume);
  ASSERT(f <> -1);
  fVolume := pVolume;
  Inc(TVolumeInfo(volumes[f]).fOpenedFilesCount); // �� �������� ����� ������!
end;

destructor TSFSFileList.Destroy ();
var
  f: Integer;
begin
  f := FindVolumeInfoByVolumeInstance(fVolume);
  ASSERT(f <> -1);
  Dec(TVolumeInfo(volumes[f]).fOpenedFilesCount);
  // ����� ������, ���� ��� ���������, � � ��� ��� ������ ������ ���������
  if (gcdisabled = 0) and not TVolumeInfo(volumes[f]).fPermanent and (TVolumeInfo(volumes[f]).fOpenedFilesCount < 1) then
  begin
    {$IFDEF SFS_VOLDEBUG}writeln('002: destroying volume "', TVolumeInfo(volumes[f]).fPackName, '"');{$ENDIF}
    volumes[f] := nil;
  end;
  inherited Destroy();
end;

function TSFSFileList.GetCount (): Integer;
begin
  result := fVolume.fFiles.Count;
end;

function TSFSFileList.GetFiles (index: Integer): TSFSFileInfo;
begin
  if (index < 0) or (index >= fVolume.fFiles.Count) then result := nil
  else result := TSFSFileInfo(fVolume.fFiles[index]);
end;


procedure SFSRegisterVolumeFactory (factory: TSFSVolumeFactory);
var
  f: Integer;
begin
  if factory = nil then exit;
  if factories.IndexOf(factory) <> -1 then
    raise ESFSError.Create('duplicate factories are not allowed');
  f := factories.IndexOf(nil);
  if f = -1 then factories.Add(factory) else factories[f] := factory;
end;

procedure SFSUnregisterVolumeFactory (factory: TSFSVolumeFactory);
var
  f: Integer;
  c: Integer;
begin
  if factory = nil then exit;
  f := factories.IndexOf(factory);
  if f = -1 then raise ESFSError.Create('can''t unregister nonexisting factory');
  c := 0; while c < volumes.Count do
  begin
    if (volumes[c] <> nil) and (TVolumeInfo(volumes[c]).fFactory = factory) then volumes[c] := nil;
    Inc(c);
  end;
  factories[f] := nil;
end;


function SFSAddDataFileEx (dataFileName: AnsiString; ds: TStream; top, permanent: Integer): Integer;
// dataFileName ����� ����� ������� ���� "zip:" (��. ����: IsMyPrefix).
// ����� �������� ����������!
// top:
//   <0: �������� � ������ ������ ������.
//   =0: �� ������.
//   >0: �������� � ����� ������ ������.
// permanent:
//   <0: ������� "���������" ���.
//   =0: �� ������ ������ �����������.
//   >0: ������� "����������" ���.
// ���� ds <> nil, �� ������ ������� �� ������. ���� ������� � ������
// dataFileName ��� ���������������, �� ������ �����.
// ���������� ������ � volumes.
// ����� ������ ��������.
var
  fac: TSFSVolumeFactory;
  vol: TSFSVolume;
  vi: TVolumeInfo;
  f: Integer;
  st, st1: TStream;
  pfx: AnsiString;
  fn, vfn, tmp: AnsiString;
begin
  f := Pos('::', dataFileName);
  if f <> 0 then
  begin
    // ����������� ��������.
    // �������� dataFileName �� ��� �������� � �������.
    // pfx ����� ������ ��������, dataFileName -- ��������.
    pfx := Copy(dataFileName, 1, f-1); Delete(dataFileName, 1, f+1);
    // ������� ������� ������ ������...
    result := SFSAddDataFileEx(pfx, ds, 0, 0);
    // ...������ ��������� � ��������.
    // ������, ����� ����� ���������.
    // ���������� ������ "::" ������� (��� ����� ��� �����).
    f := Pos('::', dataFileName); if f = 0 then f := Length(dataFileName)+1;
    fn := Copy(dataFileName, 1, f-1); Delete(dataFileName, 1, f-1);
    // dataFileName ������ �������.
    // �������� ��� �����:
    SplitDataName(fn, pfx, tmp, vfn);
    // ������� ���� ����
    vi := TVolumeInfo(volumes[result]); st := nil;
    try
      st := vi.fVolume.OpenFileEx(tmp);
      st1 := TOwnedPartialStream.Create(vi, st, 0, st.Size, true);
    except
      FreeAndNil(st);
      // ������ �������������� ��������� ���.
      if (gcdisabled = 0) and not vi.fPermanent and (vi.fOpenedFilesCount < 1) then volumes[result] := nil;
      raise;
    end;
    // ���. ������� ����. ������ � ������ �������, ���������� �����������.
    fn := fn+dataFileName;
    try
      st1.Position := 0;
      result := SFSAddDataFileEx(fn, st1, top, permanent);
    except
      st1.Free(); // � ��� �� ����������. ������� �������� �����, ��������.
      raise;
    end;
    exit;
  end;

  // ������������ ������������� ��������.
  SplitDataName(dataFileName, pfx, fn, vfn);

  f := FindVolumeInfo(vfn);
  if f <> -1 then
  begin
    if ds <> nil then raise ESFSError.Create('subdata name conflict');
    if permanent <> 0 then TVolumeInfo(volumes[f]).fPermanent := (permanent > 0);
    if top = 0 then result := f
    else if top < 0 then result := 0
    else result := volumes.Count-1;
    if result <> f then volumes.Move(f, result);
    exit;
  end;

  if ds <> nil then st := ds
  else st := TFileStream.Create(fn, fmOpenRead or {fmShareDenyWrite}fmShareDenyNone);
  st.Position := 0;

  volumes.Pack();

  fac := nil; vol := nil;
  try
    for f := 0 to factories.Count-1 do
    begin
      fac := TSFSVolumeFactory(factories[f]);
      if fac = nil then continue;
      if (pfx <> '') and not fac.IsMyVolumePrefix(pfx) then continue;
      st.Position := 0;
      try
        if ds <> nil then vol := fac.Produce(pfx, '', st)
        else vol := fac.Produce(pfx, fn, st);
      except
        vol := nil;
      end;
      if vol <> nil then break;
    end;
    if vol = nil then raise ESFSError.Create('no factory for "'+dataFileName+'"');
  except
    if st <> ds then st.Free();
    raise;
  end;

  vi := TVolumeInfo.Create();
  try
    if top < 0 then
    begin
      result := 0;
      volumes.Insert(0, vi);
    end
    else result := volumes.Add(vi);
  except
    vol.Free();
    if st <> ds then st.Free();
    vi.Free();
    raise;
  end;

  vi.fFactory := fac;
  vi.fVolume := vol;
  vi.fPackName := vfn;
  vi.fStream := st;
  vi.fPermanent := (permanent > 0);
  vi.fNoDiskFile := (ds <> nil);
  vi.fOpenedFilesCount := 0;
end;

function SFSAddSubDataFile (const virtualName: AnsiString; ds: TStream; top: Boolean=false): Boolean;
var
  tv: Integer;
begin
  ASSERT(ds <> nil);
  try
    if top then tv := -1 else tv := 1;
    SFSAddDataFileEx(virtualName, ds, tv, 0);
    result := true;
  except
    result := false;
  end;
end;

function SFSAddDataFile (const dataFileName: AnsiString; top: Boolean=false): Boolean;
var
  tv: Integer;
begin
  try
    if top then tv := -1 else tv := 1;
    SFSAddDataFileEx(dataFileName, nil, tv, 1);
    result := true;
  except
    result := false;
  end;
end;

function SFSAddDataFileTemp (const dataFileName: AnsiString; top: Boolean=false): Boolean;
var
  tv: Integer;
begin
  try
    if top then tv := -1 else tv := 1;
    SFSAddDataFileEx(dataFileName, nil, tv, 0);
    result := true;
  except
    result := false;
  end;
end;



function SFSExpandDirName (const s: AnsiString): AnsiString;
var
  f, e: Integer;
  es: AnsiString;
begin
  f := 1; result := s;
  while f < Length(result) do
  begin
    while (f < Length(result)) and (result[f] <> '<') do Inc(f);
    if f >= Length(result) then exit;
    e := f; while (e < Length(result)) and (result[e] <> '>') do Inc(e);
    es := Copy(result, f, e+1-f);

    if es = '<currentdir>' then es := GetCurrentDir
    else if es = '<exedir>' then es := ExtractFilePath(ParamStr(0))
    else es := '';

    if es <> '' then
    begin
      if (es[Length(es)] <> '/') and (es[Length(es)] <> '\') then es := es+'/';
      Delete(result, f, e+1-f);
      Insert(es, result, f);
      Inc(f, Length(es));
    end
    else f := e+1;
  end;
end;

function SFSFileOpenEx (const fName: AnsiString): TStream;
var
  dataFileName, fn: AnsiString;
  f: Integer;
  vi: TVolumeInfo;
  diskChecked: Boolean;
  ps: TStream;

  function CheckDisk (): TStream;
  // ��������, ���� �� ���� fn ���-�� �� ������.
  var
    dfn, dirs, cdir: AnsiString;
    f: Integer;
  begin
    result := nil;
    if diskChecked or not sfsDiskEnabled then exit;
    diskChecked := true;
    dfn := SFSReplacePathDelims(fn, '/');
    dirs := sfsDiskDirs; if dirs = '' then dirs := '<currentdir>';
    while dirs <> '' do
    begin
      f := 1; while (f <= Length(dirs)) and (dirs[f] <> '|') do Inc(f);
      cdir := Copy(dirs, 1, f-1); Delete(dirs, 1, f);
      if cdir = '' then continue;
      cdir := SFSReplacePathDelims(SFSExpandDirName(cdir), '/');
      if cdir[Length(cdir)] <> '/' then cdir := cdir+'/';
      try
        result := TFileStream.Create(cdir+dfn, fmOpenRead or {fmShareDenyWrite}fmShareDenyNone);
        exit;
      except
      end;
    end;
  end;

begin
  SplitFName(fName, dataFileName, fn);
  if fn = '' then raise ESFSError.Create('invalid file name: "'+fName+'"');

  diskChecked := false;

  if dataFileName <> '' then
  begin
    // ������������� ����
    if sfsForceDiskForPrefixed then
    begin
      result := CheckDisk();
      if result <> nil then exit;
    end;

    f := SFSAddDataFileEx(dataFileName, nil, 0, 0);
    vi := TVolumeInfo(volumes[f]);

    try
      result := vi.fVolume.OpenFileEx(fn);
      ps := TOwnedPartialStream.Create(vi, result, 0, result.Size, true);
    except
      result.Free();
      if (gcdisabled = 0) and not vi.fPermanent and (vi.fOpenedFilesCount < 1) then volumes[f] := nil;
      result := CheckDisk(); // ����� � datafile, �������� ����
      if result = nil then raise ESFSError.Create('file not found: "'+fName+'"');
      exit;
    end;
    //Inc(vi.fOpenedFilesCount);
    result := ps;
    exit;
  end;

  // ��������������� ����
  if sfsDiskFirst then
  begin
    result := CheckDisk();
    if result <> nil then exit;
  end;
  // ���� �� ���� ������������ ���������
  f := 0;
  while f < volumes.Count do
  begin
    vi := TVolumeInfo(volumes[f]);
    if (vi <> nil) and vi.fPermanent then
    begin
      if vi.fVolume <> nil then
      begin
        result := vi.fVolume.OpenFileEx(fn);
        if result <> nil then
        begin
          try
            ps := TOwnedPartialStream.Create(vi, result, 0, result.Size, true);
            result := ps;
            //Inc(vi.fOpenedFilesCount);
          except
            FreeAndNil(result);
          end;
        end;
        if result <> nil then exit;
      end;
    end;
    Inc(f);
  end;
  result := CheckDisk();
  if result = nil then raise ESFSError.Create('file not found: "'+fName+'"');
end;

function SFSFileOpen (const fName: AnsiString): TStream;
begin
  try
    result := SFSFileOpenEx(fName);
  except
    result := nil;
  end;
end;

function SFSFileList (const dataFileName: AnsiString): TSFSFileList;
var
  f: Integer;
  vi: TVolumeInfo;
begin
  result := nil;
  if dataFileName = '' then exit;

  try
    f := SFSAddDataFileEx(dataFileName, nil, 0, 0);
  except
    exit;
  end;
  vi := TVolumeInfo(volumes[f]);

  try
    result := TSFSFileList.Create(vi.fVolume);
  except
    if (gcdisabled = 0) and not vi.fPermanent and (vi.fOpenedFilesCount < 1) then volumes[f] := nil;
  end;
end;


initialization
  factories := TObjectList.Create(true);
  volumes := TObjectList.Create(true);
//finalization
  //volumes.Free(); // it fails for some reason... Runtime 217 (^C hit). wtf?!
  //factories.Free(); // not need to be done actually...
end.
