unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, unit2;

const cellsize=20;

const maxmaxx=60;
      maxmaxy=30;
//      maxmines=maxmaxx*maxmaxy div 2;
      maxnumbers=maxmaxx*maxmaxy-1;
      maxvariants=70;

const gamemode_none=0;
      gamemode_game=1;
      gamemode_end=2;

Type TMineralBox = class(Tpanel)
  private
  mx,my:integer;
  mchecked:boolean;
  mdone,merror:boolean;
end;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Button3: TButton;
    Image1: TImage;
    Image2: TImage;
    Label1: TLabel;
    Label2: TLabel;
    Panel1: TPanel;
    Panel2: TPanel;
    timer1: ttimer;
    procedure Button1Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure FormMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure Panel1Click(Sender: TObject);
    procedure Panel2Click(Sender: TObject);

  private
    procedure changeme(Sender:TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure onmytimer(Sender: TObject);

    procedure drawmap;
    procedure calculatestatus;
    procedure generatemap(startx,starty:integer);
    procedure clickhere(cx,cy:integer);

    function solve(startx,starty:integer):boolean;
    procedure getdata(cx,cy:integer);
    procedure solverclick(cx,cy:integer);
    procedure dosecondorderlogic;
    function guessworks:double;
    { private declarations }
  public
    { public declarations }
  end;

type maparray = array[1..maxmaxx,1..maxmaxy] of byte;
type neighbours = array[-1..1,-1..1] of byte;
type variantarray = array[0..maxvariants] of neighbours;

var
  m: array[1..maxmaxx, 1..maxmaxy] of TMineralBox;
  Form1: TForm1;
  map,mapchanged,mapmark: maparray;
  mapcreated:maparray;
  starttime:TDateTime;

  maxx,maxy:integer;
  mines:integer;

  solution: maparray;
  nnumbers: integer;
  variants,nfree,nmines,nx,ny: array[1..maxnumbers] of byte;
  freenumbers: array[1..maxnumbers] of variantarray;

  guessm_mines,guessm_free:maparray;
  guesspool,guesslimit,guesssuccess:double;
  guessx,guessy:integer;

  firstorderlogic_works,secondorderlogic,secondorderlogic_works,guesslogic_works:boolean;

  mapdone:boolean;

  gamemode:byte;

  mousedownkey:boolean;
  movex,movey:integer;


implementation

{$R *.lfm}

{$R+}{$Q+}

{ TForm1 }

// this is a simple button to reset the minefield.
procedure TForm1.Button1Click(Sender: TObject);
var ix,iy:integer;
begin
//  memo1.clear;
 if gamemode<>gamemode_game then begin
  label2.caption:='- - -';
  label1.caption:='- - -';
  mapdone:=false;

  val(form2.edit3.text,maxx,ix);
  if (ix<>0) or (maxx<7) or (maxx>maxmaxx) then maxx:=10;
  val(form2.edit4.text,maxy,ix);
  if (ix<>0) or (maxy<7) or (maxy>maxmaxy) then maxy:=10;

  form1.BeginFormUpdate;
  for ix:=1 to maxmaxx do
    for iy:=1 to maxmaxy do if mapcreated[ix,iy]=1 then m[ix,iy].visible:=false;

  for ix:=1 to maxx do
    for iy:=1 to maxy do begin
      if mapcreated[ix,iy]=0 then begin
        m[ix,iy]:=TMineralBox.create(nil);
        m[ix,iy].onmousedown:=@changeme;
        m[ix,iy].parent:=form1;
        m[ix,iy].mx:=ix;
        m[ix,iy].my:=iy;
        mapcreated[ix,iy]:=1;
      end;
      m[ix,iy].top:=(iy-1)*cellsize+button1.height+4;
      m[ix,iy].left:=(ix-1)*cellsize;
      m[ix,iy].height:=cellsize;
      m[ix,iy].width:=cellsize;
      m[ix,iy].caption:=' ';
      m[ix,iy].font.Bold:=true;
      m[ix,iy].font.Size:=cellsize-8;
      m[ix,iy].mchecked:=false;
      m[ix,iy].color:=clTeal;
      m[ix,iy].update;
      m[ix,iy].visible:=true;
      m[ix,iy].mdone:=false;
      m[ix,iy].merror:=false;
    end;
  form1.endFormUpdate;
  {$IFDEF UNIX}form1.BorderStyle:=bsnone;{$ENDIF}
  form1.width:=cellsize*maxx+2;
  form1.height:=cellsize*maxy+button1.height+4+image1.height+3;
  {$IFDEF UNIX}form1.BorderStyle:=bssingle;{$ENDIF}
 end else if gamemode=gamemode_game then begin
   // 'give up'
   form1.BeginFormUpdate;
   for ix:=1 to maxx do
     for iy:=1 to maxy do begin
       m[ix,iy].mchecked:=true;
       m[ix,iy].mdone:=true;
       m[ix,iy].merror:=false;
       mapchanged[ix,iy]:=1;
     end;
   gamemode:=gamemode_none;
   drawmap;
   button1.caption:='NEW';
   label2.caption:='- - -';
   timer1.enabled:=false;
   form1.endformupdate;
 end;
end;

//this button ends the game and shows the map

procedure TForm1.Button3Click(Sender: TObject);
begin
  if (form2visible) then begin
    form2.hide
  end else begin
    form2.label10.caption:='(max '+inttostr(maxmaxx)+'x'+inttostr(maxmaxy)+')';
    form2.show;
  end;
  form2visible:=not form2visible;
end;

//destroy dynamic elements on close
procedure TForm1.FormClose(Sender: TObject; var CloseAction: TCloseAction);
var ix,iy:integer;
begin
 //timer1.destroy;
 form1.beginformupdate;
 for ix:=1 to maxmaxx do
    for iy:=1 to maxmaxy do if mapcreated[ix,iy]=1 then m[ix,iy].destroy;
 form2.close;
 form1.endformupdate;
end;

//create minefield on start
procedure TForm1.FormCreate(Sender: TObject);
var ix,iy:integer;
begin
  mousedownkey:=false;
  gamemode:=gamemode_none;
  form2visible:=false;
  for ix:=1 to maxmaxx do
    for iy:=1 to maxmaxy do
      mapcreated[ix,iy]:=0;
  //timer1.create(form1);
  timer1.interval:=1000;
  timer1.ontimer:=@onmytimer;
//  timer1.parent:=form1;
  timer1.enabled:=false;
end;

procedure TForm1.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  mousedownkey:=true;
  movex:=x;
  movey:=y;
end;

procedure TForm1.FormMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
  if mousedownkey then begin
    left:=left+x-movex;
    top:=top+y-movey;
  end;
end;

procedure TForm1.FormMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  mousedownkey:=false;
end;

procedure TForm1.Panel1Click(Sender: TObject);
begin
  form1.close;
end;

procedure TForm1.Panel2Click(Sender: TObject);
begin
  Form1.WindowState := wsMinimized;
  form2.hide;
end;

procedure Tform1.onmytimer(Sender: TObject);
begin
  label1.caption:=inttostr(round((now-starttime)*24*60*60));
  timer1.enabled:=true;
end;

{------------------------------------------------------------------}
// this procedure determines user click at minefield to open a square.
procedure Tform1.clickhere(cx,cy:integer);
var i,ix,iy,dx,dy:integer;
  x1,y1,x2,y2:integer;
  foundzero:boolean;
begin
 if mapmark[cx,cy]>0 then begin
   m[cx,cy].mchecked:=false;
   exit;
 end;
 m[cx,cy].mchecked:=true;
 if map[cx,cy]<9 then begin
   inc(map[cx,cy],100);
   if map[cx,cy]=100 then begin
     x1:=cx;
     x2:=cx;
     y1:=cy;
     y2:=cy;
     repeat
       i:=0;
       if x1>1 then dec(x1);
       if x2<maxx then inc(x2);
       if y1>1 then dec(y1);
       if y2<maxy then inc(y2);
       for ix:=x1 to x2 do
         for iy:=y1 to y2 do if map[ix,iy]<9 then begin
           foundzero:=false;
           for dx:=-1 to 1 do
             for dy:=-1 to 1 do if (dx<>0) or (dy<>0) then
               if (dx+ix>0) and (dx+ix<=maxx) and (dy+iy>0) and (dy+iy<=maxy) then
                 if map[ix+dx,iy+dy]=100 then foundzero:=true;
           if foundzero then begin inc(map[ix,iy],100); inc(i) end;
         end;
     until i=0;
   end;
   for ix:=1 to maxx do
     for iy:=1 to maxy do if map[ix,iy]>=100 then begin
       dec(map[ix,iy],100);
       m[ix,iy].mchecked:=true;
       mapmark[ix,iy]:=0;
       mapchanged[ix,iy]:=1;
     end;
 end else begin
   m[cx,cy].mchecked:=true;
   mapchanged[cx,cy]:=1;
 end;
 drawmap;
end;

// this is actual 'click me' event which processes either to actually probe the minefield or mark a mine.
procedure TForm1.changeme(Sender:TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var me:TMineralBox;
  ix,iy:integer;
  s:string;
  j:integer;
begin
  me:=sender as TMineralBox;
  if (not mapdone) then
    if (button=mbleft) then generatemap(me.mx,me.my) ;

  if mapdone then
  if not me.mchecked then begin
    if (button=mbleft) then clickhere(me.mx,me.my) else         // probing the minefield
    if (button=mbright) then begin                              // marking a mine
      if (me.mchecked=false) and (me.color<>clred) then begin
        mapchanged[me.mx,me.my]:=1;
        if mapmark[me.mx,me.my]=0 then mapmark[me.mx,me.my]:=1 else mapmark[me.mx,me.my]:=0;
        drawmap;
      end;
    end;
  end else
    if me.mdone then                     // this is what happens if the number appears to be satisfied - click all unclicked vicinity
      for ix:=-1 to 1 do
        for iy:=-1 to 1 do if (me.mx+ix>0) and (me.mx+ix<=maxx) and (me.my+iy>0) and (me.my+iy<=maxy) then
          if not m[me.mx+ix,me.my+iy].mchecked then clickhere(me.mx+ix,me.my+iy);

// this is a test for variants for debugging a BUG :)
{  if (button=mbmiddle) then begin
    for ix:=1 to maxx do
      for iy:=1 to maxy do if m[ix,iy].mchecked then solution[ix,iy]:=map[ix,iy] else solution[ix,iy]:=255;
    nnumbers:=0;
    secondorderlogic:=true;
    getdata(me.mx,me.my);
//    memo1.lines.add(inttostr(nmines[1])+'/'+inttostr(nfree[1])+' -> '+inttostr(variants[1]));

    if variants[1]>1 then
    for j:=0 to variants[1] do begin
      for ix:=-1 to 1 do begin
        s:='';
        for iy:=-1 to 1 do s:=s+inttostr(freenumbers[1][j][ix,iy])+' ';
        memo1.lines.add(s);
      end;
      memo1.lines.add('');
    end;
  end;}

end;

{--------------------------------------------------------------}

//this procedure calculates if the numbers are satisfied or not
procedure TForm1.calculatestatus;
var ix,iy,dx,dy:integer;
    mineshere:byte;
    endgame:boolean;
    totalmines,foundmines:integer;
begin
 for ix:=1 to maxx do
   for iy:=1 to maxy do if m[ix,iy].mchecked then begin
     mineshere:=0;
     for dx:=-1 to 1 do
       for dy:=-1 to 1 do if (dx+ix>0) and (ix+dx<=maxx) and (iy+dy>0) and (iy+dy<=maxy) then
         if (mapmark[ix+dx,iy+dy]=1) or ((m[ix+dx,iy+dy].mchecked) and (map[ix+dx,iy+dy]=9)) then inc(mineshere);

     if mineshere=map[ix,iy] then begin        // if the number is satisfied.
       if m[ix,iy].mdone<>true then begin
         m[ix,iy].mdone:=true;
         mapchanged[ix,iy]:=1;
       end;
     end else begin
        if m[ix,iy].mdone<>false then begin
          m[ix,iy].mdone:=false;
          mapchanged[ix,iy]:=1;
        end;
     end;
     if mineshere>map[ix,iy] then begin          // if the number is oversatisfied mark error
       if m[ix,iy].merror<>true then begin
         m[ix,iy].merror:=true;
         mapchanged[ix,iy]:=1;
       end;
     end else begin
        if m[ix,iy].merror<>false then begin
          m[ix,iy].merror:=false;
          mapchanged[ix,iy]:=1;
        end;
     end;
   end;

 totalmines:=0;
 foundmines:=0;
 for ix:=1 to maxx do
   for iy:=1 to maxy do begin
      if map[ix,iy]=9 then inc(totalmines);
     if ((m[ix,iy].mchecked) and (map[ix,iy]=9)) or (mapmark[ix,iy]=1) then inc(foundmines);
   end;
 label2.caption:=inttostr(totalmines-foundmines)+'/'+inttostr(totalmines);

 endgame:=true;
 for ix:=1 to maxx do
   for iy:=1 to maxy do if (map[ix,iy]<9) and (not m[ix,iy].mchecked) then endgame:=false;
 if endgame then begin
   timer1.enabled:=false;
   button1.caption:='NEW';
   showmessage('Map finished!');
   gamemode:=gamemode_end;
 end;
end;

{--------------------------------------------------------------}

// map draw routine
procedure Tform1.drawmap;
var ix,iy:integer;
begin
  form1.beginformupdate;
  if gamemode=gamemode_game then calculatestatus;

  for ix:=1 to maxx do
    for iy:=1 to maxy do if mapchanged[ix,iy]=1 then begin
      mapchanged[ix,iy]:=0;
      if m[ix,iy].mchecked then begin
          if (map[ix,iy]>0) and (map[ix,iy]<9) then m[ix,iy].caption:=inttostr(map[ix,iy]) else m[ix,iy].caption:=' ';
          case map[ix,iy] of
            1:m[ix,iy].font.color:=clblue;
            2:m[ix,iy].font.color:=clgreen;
            3:m[ix,iy].font.color:=clred;
            4:m[ix,iy].font.color:=claqua;
            5:m[ix,iy].font.color:=clmaroon;
            6:m[ix,iy].font.color:=clTeal;
            7:m[ix,iy].font.color:=clblack;
            8:m[ix,iy].font.color:=clgray;
          end;
          if map[ix,iy]=9 then m[ix,iy].color:=clred else begin
            if m[ix,iy].mdone then m[ix,iy].color:=$AAAAAA else m[ix,iy].color:=clwhite;
            if m[ix,iy].merror then begin m[ix,iy].color:=clmaroon; m[ix,iy].font.color:=clwhite; end;
          end;
        end else m[ix,iy].color:=clTeal;
      if mapmark[ix,iy]=1 then m[ix,iy].color:=clpurple;
    end;
  form1.endformupdate;

end;

{--------------------------------------------------------------------}

// this is the core generation procedure
// logic is simple. We place a mine and check map solvability. If solvable - place another, if not - remove this mine and place it in other place until the map is solvable.
procedure TForm1.generatemap(startx,starty:integer);
var ix,iy,dx,dy:integer;
    minex,miney:integer;
    count:integer;
    mapsolvable:boolean;
    freespace:integer;
    generatedmines:integer;
    mines_map:maparray;
begin
  button1.caption:='GIVE UP';
  label1.caption:='0';
  gamemode:=gamemode_game;

  randomize;
  val(form2.edit5.text,mines,ix);
  if (ix<>0) or (mines<=0) or (mines>=maxx*maxy-9) then mines:=maxx*maxy div 3;

  for ix:=1 to maxx do
    for iy:=1 to maxy do begin
      map[ix,iy]:=0;
      mapchanged[ix,iy]:=1;
      mapmark[ix,iy]:=0;
      mines_map[ix,iy]:=255;
    end;

  //place n mines
  generatedmines:=0;
  repeat
    inc(generatedmines);
    for dx:=-1 to 1 do
      for dy:=-1 to 1 do if (dx+startx>0) and (dx+startx<=maxx) and (dy+starty>0) and (dy+starty<=maxy) then mines_map[dx+startx,dy+starty]:=0;
    freespace:=0;
    for ix:=1 to maxx do
      for iy:=1 to maxy do
        if (mines_map[ix,iy]=255) then inc(freespace);
    dec(freespace,generatedmines);

    repeat
      //place a mine
      repeat
        minex:=round(random*(maxx-1))+1;
        miney:=round(random*(maxy-1))+1;
      until (map[minex,miney]<9) and (mines_map[minex,miney]=255) and ((abs(minex-startx)>1) or (abs(miney-starty)>1));
      map[minex,miney]:=9;

      // make numbered map
      for ix:=1 to maxx do
        for iy:=1 to maxy do if map[ix,iy]<9 then begin
          count:=0;
          for dx:=-1 to 1 do
            for dy:=-1 to 1 do if (dx<>0) or (dy<>0) then
              if (dx+ix>0) and (dx+ix<=maxx) and (dy+iy>0) and (dy+iy<=maxy) then
                if map[ix+dx,iy+dy]=9 then inc(count);
          map[ix,iy]:=count;
        end;

        if not form2.radiobutton5.checked then mapsolvable:=solve(startx,starty) else mapsolvable:=true;//true;
        if not mapsolvable then begin
          map[minex,miney]:=0;
          mines_map[minex,miney]:=0;
          dec(freespace);
        end;

   until (mapsolvable) or (freespace<=0);
//   memo1.lines.add('[dbg] mine placed successfully');
  until (generatedmines>=mines) or (freespace<=0);
   if generatedmines<mines then begin
     showmessage('Error: only '+inttostr(generatedmines-1)+' of '+inttostr(mines)+' mines have been placed');
     mines:=generatedmines
   end;

  mapdone:=true;
  starttime:=now;
  timer1.enabled:=true;
end;

{----------------------------------------------------------------}
{------------------- super solver adventures --------------------}
{----------------------------------------------------------------}

// this is the click by AI solver
// computer can't click a mine even while guessing
procedure Tform1.solverclick(cx,cy:integer);
var i,ix,iy,dx,dy:integer;
    x1,x2,y1,y2:integer;
    foundzero:boolean;
begin
//  if map[cx,cy]=9 then begin memo1.lines.add('[dbg] FATAL: Clicked a mine!!!'); {exit;} end;
    solution[cx,cy]:=map[cx,cy];
    if solution[cx,cy]=0 then begin
      x1:=cx;
      x2:=cx;
      y1:=cy;
      y2:=cy;
      repeat
        i:=0;
        if x1>1 then dec(x1);
        if x2<maxx then inc(x2);
        if y1>1 then dec(y1);
        if y2<maxy then inc(y2);
        for ix:=x1 to x2 do
          for iy:=y1 to y2 do if solution[ix,iy]=255 then begin
            foundzero:=false;
            for dx:=-1 to 1 do
              for dy:=-1 to 1 do if (dx<>0) or (dy<>0) then
                if (dx+ix>0) and (dx+ix<=maxx) and (dy+iy>0) and (dy+iy<=maxy) then
                  if solution[ix+dx,iy+dy]=0 then foundzero:=true;
            if foundzero then begin solution[ix,iy]:=map[ix,iy]; inc(i) end;
          end;
      until i=0;
    end;
end;

{=====================================================================}

// this is the basic routine to:
// 1: Preform first order logic
// 2: Prepare data for second order logic
// First order logic menas number of mines adjacent to a number
// is zero or equal to free space around (i.e. only one solution
// dependless on other numbers
procedure Tform1.getdata(cx,cy:integer);
var dx,dy:integer;
    i,j:integer;
    variantmine:array[1..7] of byte;
    morevariants:boolean;
begin
 inc(nnumbers); // add another number to the numbers with over one variant. If the variant will be only one, we'll delete it soon.
 nfree[nnumbers]:=0; // null free space around
 nmines[nnumbers]:=0; // null mines around
 variants[nnumbers]:=1; // number of variants (just for debugging middleclick, we'll reset it later)
 for dx:=-1 to 1 do
   for dy:=-1 to 1 do if (dx<>0) or (dy<>0) then      // see 3x3 space around the cx,cy excluding center
     if (cx+dx>0) and (cy+dy>0) and (cx+dx<=maxx) and (cy+dy<=maxy) then begin        //check map limits
       if solution[cx+dx,cy+dy]=255 then begin         // if unexplored piece found
         inc(nfree[nnumbers]);                            //inc free space
         if map[cx+dx,cy+dy]=9 then inc(nmines[nnumbers]); // if there is a mine - inc mines
         freenumbers[nnumbers][0][dx,dy]:=1;               // this is a working point
       end else freenumbers[nnumbers][0][dx,dy]:=0;  // not interested in explored pieces
     end else freenumbers[nnumbers][0][dx,dy]:=0;  // if map limits fail write it.
 freenumbers[nnumbers][0][0,0]:=0;       //center is also not used

 if nfree[nnumbers]=0 then begin  // if this number is explored just kill it
   dec(nnumbers);
 end else
 if nmines[nnumbers]=0 then begin   // if this number has no unexplored mines, click every free space & kill it
   // all safe
   dec(nnumbers);
   for dx:=-1 to 1 do
     for dy:=-1 to 1 do if (dx<>0) or (dy<>0) then
       if (cx+dx>0) and (cy+dy>0) and (cx+dx<=maxx) and (cy+dy<=maxy) then //fail-safe, repeat conditions
         if solution[cx+dx,cy+dy]=255 then solverclick(cx+dx,cy+dy);       //click every unexplored space
   firstorderlogic_works:=true;                                            //first-order logic was useful
 end else
 if nmines[nnumbers]=nfree[nnumbers] then begin    // if free space = n mines then all free space is mines & kill it
   dec(nnumbers);
   for dx:=-1 to 1 do
     for dy:=-1 to 1 do if (dx<>0) or (dy<>0) then              //fail-safe, repeat conditions
       if (cx+dx>0) and (cy+dy>0) and (cx+dx<=maxx) and (cy+dy<=maxy) then
         if solution[cx+dx,cy+dy]=255 then solution[cx+dx,cy+dy]:=9;  // mark all unexplored space as mines
   firstorderlogic_works:=true;                                       // first-order logic was useful
 end else begin
   if secondorderlogic then begin        // none of the above simple solutions apply. If we think of second order logic, we must prepare possible variants>1 for each unsatisfied number
     // make variants

     nx[nnumbers]:=cx; // this number location
     ny[nnumbers]:=cy;

     variants[nnumbers]:=0; // no variants yet

     for i:=1 to nmines[nnumbers] do variantmine[i]:=i; // place the mines at first locations

     repeat
       inc(variants[nnumbers]);    // switch to next variant
       j:=0;                                                  //unexplored location index around cx-cy
       freenumbers[nnumbers][variants[nnumbers]][0,0]:=0;     //center is not needed
       for dx:=-1 to 1 do
         for dy:=-1 to 1 do
             if freenumbers[nnumbers][0][dx,dy]=1 then begin    //count only unexplored space around + map limits
               inc(j);                                          // this is jth unexplored location
               freenumbers[nnumbers][variants[nnumbers]][dx,dy]:=1;       // this is a safe space
               for i:=1 to nmines[nnumbers] do if variantmine[i]=j then freenumbers[nnumbers][variants[nnumbers]][dx,dy]:=9; // if coincides with one of the mines - then safe space is replaced for a mine
             end else freenumbers[nnumbers][variants[nnumbers]][dx,dy]:=0;   // erase uninteresting variants
        j:=nmines[nnumbers];  //this is the last mine
        morevariants:=false;
        repeat
          if variantmine[j]<nfree[nnumbers]-(nmines[nnumbers]-j) then begin //if this mine may be moved forward
            inc(variantmine[j]);                                            // move it one step
            morevariants:=true;                                             // there are still variants
          end else begin
            dec(j);                                                         // else - switch to previous mine
          end;
        until (j=0) or (morevariants);         // if we found a mine to move (morevariants) or no more variants (j=0)
        if (j>0) and (j<nmines[nnumbers]) then begin    // if we moved a mine and its not the last one
          for i:=j+1 to nmines[nnumbers] do variantmine[i]:=variantmine[j]+i-j;   // sort all the next adjacent to it
        end;
     until j=0; //no more variants
   end;   {secondorderlogic}
 end;
end;

{---------------------------------------------------------------------}

// this is the core of computer solving the puzzle
// it prepares a tmp solution map
// and then tries to solve it in 3 stages:
// 1. first order logic (it's simple)
// 2. second order logic (it's hard)
// 3. guess logic (it requires guessing)
function Tform1.solve(startx,starty:integer):boolean;
var ix,iy:integer;
    finished:boolean;
    nfreespace,nminesleft:integer;
    guessworksresult:double;
    tmpval:integer;
begin
  val(form2.edit1.text,tmpval,ix);
  guesslimit:=tmpval/100;
  if (ix<>0) or (tmpval>100) or (tmpval<0) then guesslimit:=0.5;
  val(form2.edit1.text,tmpval,ix);
  guesssuccess:=tmpval/100;
  if (ix<>0) or (tmpval>100) or (tmpval<0) then guesssuccess:=0.7;


  guesspool:=1;

  for ix:=1 to maxx do
    for iy:=1 to maxy do
      solution[ix,iy]:=255;
  nnumbers:=0;

  solverclick(startx,starty);
  repeat
    secondorderlogic_works:=false;
    firstorderlogic_works:=false;
    guesslogic_works:=false;

    secondorderlogic:=false;
    nnumbers:=0;
    for ix:=1 to maxx do
      for iy:=1 to maxy do if (solution[ix,iy]>0) and (solution[ix,iy]<9) then
        getdata(ix,iy);

    if form2.radiobutton2.checked or form2.radiobutton3.checked or form2.radiobutton4.checked then
    if (not firstorderlogic_works) then begin
      nnumbers:=0;
      secondorderlogic:=true;
      for ix:=1 to maxx do
        for iy:=1 to maxy do if (solution[ix,iy]>0) and (solution[ix,iy]<9) then
          getdata(ix,iy);

      if nnumbers>1 then begin
        //memo1.lines.add('[dbg] try... '+inttostr(nnumbers));
//         for ix:=1 to nnumbers do memo1.lines.add(inttostr(nx[ix])+'.'+inttostr(ny[ix]));
        dosecondorderlogic;
        //if secondorderlogic_works then memo1.lines.add('Second order works!');
      end// else memo1.lines.add('[dbg] ERROR: no numbers...');
    end;

    finished:=true;
    for ix:=1 to maxx do
      for iy:=1 to maxy do if solution[ix,iy]=255 then finished:=false;
    nminesleft:=0;
    nfreespace:=0;
    for ix:=1 to maxx do
      for iy:=1 to maxy do if (solution[ix,iy]=255) then begin
        if map[ix,iy]=9 then inc(nminesleft);
        inc(nfreespace);
      end;
    if (nminesleft=0) or (nminesleft=nfreespace) then begin
      finished:=true;
    end;

    if (not finished) and (form2.radiobutton4.checked) then
    if (guesslimit<guesspool) and ((not firstorderlogic_works) and (not secondorderlogic_works)) then begin
      guessworksresult:=guessworks;
      if guessworksresult>guesssuccess then begin
        solverclick(guessx,guessy);
        guesslogic_works:=true;
        guesspool:=guesspool*guessworksresult;
//        memo1.lines.add('[dbg] Guess step with '+inttostr(round(guessworksresult*100))+'% success');
//        memo1.lines.add('[dbg] total success chance '+inttostr(round(guessworksresult*100))+'%');
      end //else memo1.lines.add('[dbg] Guess failed with '+inttostr(round(guessworksresult*100))+'% success');
    end;
  until (finished) or ((not firstorderlogic_works) and (not secondorderlogic_works)and (not guesslogic_works));

  solve:=finished;
end;

{------------------------------------------------------------------}

// the hardest routine around. It calculates the second order logic.
// At the present time THERE IS A HORRIBLE BUG INSIDE :)
// It makes the computer 'think' only about adjacent numbers
// I.e. only the closest numbers are affected by the solution
// so sometimes it won't be able to find a more complex solution
//
// How it works:
// 1. GetData routine prepares all possible mine combinations for a number at unexplored space
// 2. First this routine creates a tmp map and places one single variant of those prepared.
// 3. It tries other variants for other numbers to see if they fit this one.
// If this leads to some impossible combination (one of other numbers has zero possible variants),
// this variant is deleted as impossible.
// The bug is here: In case after first stage and dropping other variants some stable conclusions
// may be made they should be plotted at the tmp map and another test round should be started
// BUT somehow it leads to contradictory results yielding tmp map different for different rounds...
// WHY???????
// Don't mind. I hope I'll figure it out some day :)
// 4. As soon as all the impossible variants are deleted the program tries to find what is common in
// the remaining variants - and places 'common' or 'stable' tiles on the solution map either as
// 100% mine or 100% free space.
// 5. In parallel it prepares data for guesswork. The data is simple - how many variants contain mines
// divide by total number of variants - this is the probability of the mine to be in this square. Simple.
procedure Tform1.dosecondorderlogic;
var ix,iy,dx,dy:integer;
    j,jv:integer;
    currentwork,currentvariant:integer;
    tmpf:array[1..maxnumbers] of array [1..maxvariants] of boolean;
    tmpv:array[1..maxnumbers] of byte;
    tmp:maparray;
    impossible,dropthisvariant:boolean;
    count:integer;
    stable:neighbours;
begin
 currentwork:=1;
 currentvariant:=1; {here we start}
// for j:=1 to nnumbers do if variants[j]<2 then memo1.lines.add('[dbg] error in variants!!!');
 repeat
   //clear tmp map
   for ix:= 1 to maxx do
     for iy:= 1 to maxy do tmp[ix,iy]:=255;

   //place currentwork/currentvariant to the tmp map;
   //we consider the first variant as always possible because we mark variant as impossible only after trying;
   for dx:=-1 to 1 do
     for dy:=-1 to 1 do if freenumbers[currentwork][0][dx,dy]=1 then
       tmp[nx[currentwork]+dx,ny[currentwork]+dy]:=freenumbers[currentwork][currentvariant][dx,dy];

   //first reset all variants to 'possible';
   for j:=1 to nnumbers do begin
     tmpv[j]:=variants[j];
     for jv:=1 to tmpv[j] do
       tmpf[j][jv]:=true;
   end;

   repeat
     impossible:=false;
     count:=0;
     //now cycle through all possible variants and chedk if currentwork/currentvariant is possible in reference to tmp map
     for j:=1 to nnumbers do if (j<>currentwork) then
      for jv:=1 to variants[j] do if tmpf[j][jv] then begin// if this variant is not marked as impossible
        //compare this variant to the existing map;
        dropthisvariant:=false;
        for dx:=-1 to 1 do
          for dy:=-1 to 1 do if freenumbers[j][0][dx,dy]=1 then
            if tmp[nx[j]+dx,ny[j]+dy]<10 then
              if tmp[nx[j]+dx,ny[j]+dy]<>freenumbers[j][jv][dx,dy] then
                dropthisvariant:=true;
        if dropthisvariant then begin
          tmpf[j][jv]:=false;
          dec(tmpv[j]);
          inc(count);
        end;
      end;

     //now place found variants to the map
     if count>0 then //no need to spoil time
      for j:=1 to nnumbers do if (j<>currentwork) and (not impossible) then begin
       if tmpv[j]=0 then impossible:=true  // if zero variants possible then solution impossible

// BEGIN BUG!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
{       else begin
       //check for persistent variants - for multi-number logic
         for dx:=-1 to 1 do
           for dy:=-1 to 1 do stable[dx,dy]:=255; //clear stable
         for jv:=1 to variants[j] do if tmpf[j][jv] then
          for dx:=-1 to 1 do
            for dy:=-1 to 1 do if freenumbers[j][0][dx,dy]=1 then begin
              if stable[dx,dy]=255 then stable[dx,dy]:=freenumbers[j][jv][dx,dy] else
              if (stable[dx,dy]<>freenumbers[j][jv][dx,dy]) then stable[dx,dy]:=100;
            end;
         //if stable variants found then place them to tmp map;
         for dx:=-1 to 1 do
           for dy:=-1 to 1 do if stable[dx,dy]<10 then begin
             if (tmp[nx[j]+dx,ny[j]+dy]<10) and (tmp[nx[j]+dx,ny[j]+dy]<>stable[dx,dy]) then begin
               tmp[nx[j]+dx,ny[j]+dy]:=100;
               memo1.lines.add('[dbg] ERROR: mismatch tmp map'); //impossible=true
             end;
             if tmp[nx[j]+dx,ny[j]+dy]=255 then tmp[nx[j]+dx,ny[j]+dy]:=stable[dx,dy];
           end;
       end;}
// END BUG!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

     end;


   until (count=0) or (impossible);
   //if impossible - drop this variant;
   if impossible then begin
     if variants[currentwork]>currentvariant then
       for jv:=currentvariant to variants[currentwork]-1 do
         freenumbers[currentwork][jv]:=freenumbers[currentwork][jv+1];
     {memo1.lines.add('[dbg] variant dropped...');}
     dec(variants[currentwork]);
//     if variants[currentwork]=0 then memo1.lines.add('[dbg] Fatal: zero variants left...');
   end else
     inc(currentvariant);   //go for next step;

   if currentvariant>variants[currentwork] then begin
     currentvariant:=1;
     inc(currentwork);
   end;
 until currentwork>nnumbers;

 //now formalize all those findings
 //put down all map tiles equal for all variants

 for ix:= 1 to maxx do
   for iy:= 1 to maxy do begin
     tmp[ix,iy]:=255;    //pre-clear map
     guessm_mines[ix,iy]:=0;     //clear guessmap;
     guessm_free[ix,iy]:=0;
   end;

 for j:=1 to nnumbers do begin
  //check for persistent variants
    for dx:=-1 to 1 do
      for dy:=-1 to 1 do
        stable[dx,dy]:=255; //clear stable

    for jv:=1 to variants[j] do
     for dx:=-1 to 1 do
       for dy:=-1 to 1 do if freenumbers[j][0][dx,dy]=1 then begin
         if stable[dx,dy]=255 then stable[dx,dy]:=freenumbers[j][jv][dx,dy];
         if (stable[dx,dy]<>freenumbers[j][jv][dx,dy]) and (stable[dx,dy]<10) then stable[dx,dy]:=100;
         //prepare for guessing just in case...
         inc(guessm_free[nx[j]+dx,ny[j]+dy]);
         if freenumbers[j][jv][dx,dy]=9 then inc(guessm_mines[nx[j]+dx,ny[j]+dy]);
       end;
    //if stable variants found then place them to tmp map;
    for dx:=-1 to 1 do
      for dy:=-1 to 1 do if stable[dx,dy]<10 then begin
        if (tmp[nx[j]+dx,ny[j]+dy]<10) and (tmp[nx[j]+dx,ny[j]+dy]<>stable[dx,dy]) then begin
          tmp[nx[j]+dx,ny[j]+dy]:=100;
//          memo1.lines.add('[dbg] ERROR: mismatch final tmp map');
        end;
        if tmp[nx[j]+dx,ny[j]+dy]=255 then tmp[nx[j]+dx,ny[j]+dy]:=stable[dx,dy];
      end;
 end;
 //and finally place everything on solution map
 count:=0;

 for ix:= 1 to maxx do
   for iy:= 1 to maxy do if solution[ix,iy]=255 then begin
      if tmp[ix,iy]=1 then begin
        solverclick(ix,iy);
        inc(count);
        secondorderlogic_works:=true;
      end else if tmp[ix,iy]=9 then begin
        solution[ix,iy]:=9;
        inc(count);
        secondorderlogic_works:=true;
      end;
   end;
// memo1.lines.add('[dbg] 2nd order result: '+inttostr(count));
end;

{----------------------------------------------}

//here we simply try to find the safest guess click around the map
//which is minimum mines in all possible variants / numver of variants
function Tform1.guessworks:double;
var ix,iy,x1,y1:integer;
    maxguess:double;
begin
 maxguess:=0;
 for ix:=1 to maxx do
   for iy:=1 to maxy do if (guessm_free[ix,iy]>0) and (map[ix,iy]<9) and (solution[ix,iy]=255) then
   if (maxguess<1-guessm_mines[ix,iy]/guessm_free[ix,iy]) then begin
     maxguess:=1-guessm_mines[ix,iy]/guessm_free[ix,iy];
     guessx:=ix;
     guessy:=iy;
   end;
 guessworks:=maxguess;
end;

end.

