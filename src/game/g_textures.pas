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
unit g_textures;

interface

uses
  SysUtils, Classes,
  {$IFDEF USE_MEMPOOL}mempool,{$ENDIF}
  g_base, MAPDEF;

type
  TLevelTexture = record
    TextureName: AnsiString; // as stored in wad
    FullName: AnsiString; // full path to texture // !!! merge it with TextureName
    framesCount, speed: Byte;
  end;

  TLevelTextureArray = array of TLevelTexture;

  TAnimationState = class{$IFDEF USE_MEMPOOL}(TPoolObject){$ENDIF}
  private
    mCounter: Byte; // ������� �������� ����� �������
    mSpeed: Byte; // ����� �������� ����� �������
    mCurrentFrame: Integer; // ������� ���� (������� � 0)
    mLoop: Boolean; // ���������� �� ������ ���� ����� ����������?
    mEnabled: Boolean; // ������ ���������?
    mPlayed: Boolean; // ��������� ��� ���� �� ���?
    mMinLength: Byte; // �������� ����� ������������
    mRevert: Boolean; // ����� ������ ��������?

    mLength: Integer;

  public
    constructor Create (aloop: Boolean; aspeed: Byte; len: Integer);
    destructor  Destroy (); override;

    procedure reset ();
    procedure update ();
    procedure enable ();
    procedure disable ();
    procedure revert (r: Boolean);

    procedure saveState (st: TStream; mAlpha: Byte; mBlending: Boolean);
    procedure loadState (st: TStream; out mAlpha: Byte; out mBlending: Boolean);

    function totalFrames (): Integer; inline;

  public
    property played: Boolean read mPlayed;
    property enabled: Boolean read mEnabled;
    property isReverse: Boolean read mRevert;
    property loop: Boolean read mLoop write mLoop;
    property speed: Byte read mSpeed write mSpeed;
    property minLength: Byte read mMinLength write mMinLength;
    property currentFrame: Integer read mCurrentFrame write mCurrentFrame;
    property currentCounter: Byte read mCounter write mCounter;
    property counter: Byte read mCounter;
    property length: Integer read mLength;
  end;

implementation

uses
  g_game, e_log, g_basic, g_console, wadreader,
  g_language, utils, xstreams;

constructor TAnimationState.Create (aloop: Boolean; aspeed: Byte; len: Integer);
begin
  assert(len >= 0);
  mLength := len;

  mMinLength := 0;
  mLoop := aloop;
  mSpeed := aspeed;
  mEnabled := true;
  mCurrentFrame := 0;
  mPlayed := false;
end;

destructor TAnimationState.Destroy;
begin
  inherited;
end;

procedure TAnimationState.update;
begin
  if (not mEnabled) then exit;

  mCounter += 1;

  if (mCounter >= mSpeed) then
  begin
    // �������� ����� ������� �����������
    // �������� ������� ������?
    if mRevert then
    begin
      // ����� �� ����� ��������. ��������, ���� ���
      if (mCurrentFrame = 0) then
      begin
        if (mLength * mSpeed + mCounter < mMinLength) then exit;
      end;

      mCurrentFrame -= 1;
      mPlayed := (mCurrentFrame < 0);

      // ��������� �� �������� �� �����?
      if mPlayed then
      begin
        if mLoop then
          mCurrentFrame := mLength - 1
        else
          mCurrentFrame += 1
      end;

      mCounter := 0;
    end
    else
    begin
      // ������ ������� ������
      // ����� �� ����� ��������. ��������, ���� ���
      if (mCurrentFrame = mLength - 1) then
      begin
        if (mLength * mSpeed + mCounter < mMinLength) then exit;
      end;

      mCurrentFrame += 1;
      mPlayed := (mCurrentFrame > mLength - 1);

      // ��������� �� �������� �� �����?
      if mPlayed then
      begin
        if mLoop then mCurrentFrame := 0 else mCurrentFrame -= 1;
      end;

      mCounter := 0;
    end;
  end;
end;

procedure TAnimationState.reset;
begin
  if mRevert then
    mCurrentFrame := mLength - 1
  else
    mCurrentFrame := 0;
  mCounter := 0;
  mPlayed := false
end;

procedure TAnimationState.disable;
begin
  mEnabled := false
end;

procedure TAnimationState.enable;
begin
  mEnabled := true
end;

procedure TAnimationState.revert (r: Boolean);
begin
  mRevert := r;
  reset
end;

function TAnimationState.totalFrames (): Integer; inline;
begin
  result := mLength
end;

procedure TAnimationState.saveState (st: TStream; mAlpha: Byte; mBlending: Boolean);
begin
  if (st = nil) then exit;

  utils.writeSign(st, 'ANIM');
  utils.writeInt(st, Byte(0)); // version
  // ������� �������� ����� �������
  utils.writeInt(st, Byte(mCounter));
  // ������� ����
  utils.writeInt(st, LongInt(mCurrentFrame));
  // ��������� �� �������� �������
  utils.writeBool(st, mPlayed);
  // Alpha-����� ���� ��������
  utils.writeInt(st, Byte(mAlpha));
  // �������� ��������
  utils.writeInt(st, Byte(mBlending));
  // ����� �������� ����� �������
  utils.writeInt(st, Byte(mSpeed));
  // ��������� �� ��������
  utils.writeBool(st, mLoop);
  // �������� ��
  utils.writeBool(st, mEnabled);
  // �������� ����� ������������
  utils.writeInt(st, Byte(mMinLength));
  // �������� �� ������� ������
  utils.writeBool(st, mRevert);
end;


procedure TAnimationState.loadState (st: TStream; out mAlpha: Byte; out mBlending: Boolean);
begin
  if (st = nil) then exit;

  if not utils.checkSign(st, 'ANIM') then raise XStreamError.Create('animation chunk expected');
  if (utils.readByte(st) <> 0) then raise XStreamError.Create('invalid animation chunk version');
  // ������� �������� ����� �������
  mCounter := utils.readByte(st);
  // ������� ����
  mCurrentFrame := utils.readLongInt(st);
  // ��������� �� �������� �������
  mPlayed := utils.readBool(st);
  // Alpha-����� ���� ��������
  mAlpha := utils.readByte(st);
  // �������� ��������
  mBlending := utils.readBool(st);
  // ����� �������� ����� �������
  mSpeed := utils.readByte(st);
  // ��������� �� ��������
  mLoop := utils.readBool(st);
  // �������� ��
  mEnabled := utils.readBool(st);
  // �������� ����� ������������
  mMinLength := utils.readByte(st);
  // �������� �� ������� ������
  mRevert := utils.readBool(st);
end;

end.
