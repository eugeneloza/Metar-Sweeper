unit Unit2;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls;

type

  { TForm2 }

  TForm2 = class(TForm)
    ComboBox1: TComboBox;
    Edit1: TEdit;
    Edit2: TEdit;
    Edit3: TEdit;
    Edit4: TEdit;
    Edit5: TEdit;
    Label1: TLabel;
    Label10: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    Label9: TLabel;
    RadioButton1: TRadioButton;
    RadioButton2: TRadioButton;
    RadioButton3: TRadioButton;
    RadioButton4: TRadioButton;
    RadioButton5: TRadioButton;
    procedure Edit3Change(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
  private
    { private declarations }
  public
    { public declarations }
  end;

var
  Form2: TForm2;
  form2visible:boolean;

implementation

{$R *.lfm}

{ TForm2 }

procedure TForm2.Edit3Change(Sender: TObject);
var vx,vy,io:integer;
begin
  val(edit3.text,vx,io);
  if (io<>0) or (vx<7) then vx:=10;
  val(edit4.text,vy,io);
  if (io<>0) or (vy<7) then vy:=10;
  edit5.text:=inttostr(round(0.4*vx*vy));
end;

procedure TForm2.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  form2visible:=false;
end;

end.

