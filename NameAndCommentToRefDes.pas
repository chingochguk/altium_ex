Procedure ChangeComponentStringsLayerAndFont;
Var
    Iterator    : IPCB_BoardIterator;
    Board       : IPCB_Board;
    Component   : IPCB_Component;
    Count       : Integer;
Begin
    // Retrieve the current board
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then Exit;

    BeginHourGlass;

    // Create the iterator that will look for Net objects only
    Iterator        := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eComponentObject));
    Iterator.AddFilter_LayerSet(AllLayers);
    Iterator.AddFilter_Method(eProcessAll);

    Count := 0;

    // Search for Net object that has the 'GND' name.
    Component := Iterator.FirstPCBObject;
    While (Component <> Nil) Do
    Begin
         if (Component.ComponentKind = eComponentKind_Standard) or
            (Component.ComponentKind = eComponentKind_Mechanical) or
            (Component.ComponentKind = eComponentKind_NetTie_BOM)
            then
         begin
           Component.CommentOn := True;
           Component.NameOn    := True;
         end
         else
         begin
           Component.CommentOn := False;
           Component.NameOn    := False;
         end;

         With (Component.Comment) do
         Begin
            Size  := MMsToCoord(0.7);
            Width := MMsToCoord(0.1);
            UseTTFonts := True;
            Italic := False;
            Bold := False;
            FontName := 'ARIAL';
            Inverted := False;
            if (Component.Layer = eTopLayer) then
                Layer := eMechanical9
            else
            if (Component.Layer = eBottomLayer) then
                Layer := eMechanical10;
         End;

         With (Component.Name) do
         Begin
            Size  := MMsToCoord(0.3);
            Width := MMsToCoord(0.05);
            UseTTFonts := False;
            FontID := 1;
            if (Component.Layer = eTopLayer) then
                Layer := eMechanical9
            else
            if (Component.Layer = eBottomLayer) then
                Layer := eMechanical10;
         End;

        Component := Iterator.NextPCBObject;
        Count := Count + 1;
        if (Count > 1024) then
        Begin
           ShowMessage('Components more than 1024!');
           Break;
        end;
    End;
    Board.BoardIterator_Destroy(Iterator);
    EndHourGlass;
    Client.SendMessage('PCB:Zoom', 'Action=Redraw' , 255, Client.CurrentView);
End;



Function ProcessPrimitivesOfAComponent(Const P : IPCB_Primitive, var CR: TCoordRect): Integer;
Var
    R : TCoordRect;
Begin
    // check for comment / name objects
    If (P.ObjectId <> eTextObject) and
       ((P.Layer = eMechanical13) or (P.Layer = eMechanical14)) Then
    Begin
        R := P.BoundingRectangle;
        If R.left   < CR.left   Then Cr.left   := R.left;
        If R.bottom < CR.bottom Then CR.bottom := R.bottom;
        If R.right  > CR.right  Then CR.right  := R.right;
        If R.top    > CR.top    Then CR.top    := R.top;
    End;
End;


Function FindComponentAssemblyRect(const C : IPCB_Component): TCoordRect;
Var
   R: TCoordRect;
   GroupIterator : IPCB_GroupIterator;
   GroupHandle   : IPCB_Primitive;
Begin
        R := Rect(2147483647, -2147483647, -2147483647, 2147483647);

        GroupIterator := C.GroupIterator_Create;
        GroupIterator.AddFilter_ObjectSet(MkSet(eArcObject, eTrackObject));
        GroupHandle   := GroupIterator.FirstPCBObject;

        if (GroupHandle <> Nil) then
        Begin
          R.left   :=  2147483647;
          R.bottom :=  2147483647;
          R.right  := -2147483647;
          R.top    := -2147483647;
        End
        else
        Begin
          R.left   :=  C.X;
          R.bottom :=  C.Y;
          R.right  :=  C.X;
          R.top    :=  C.Y;
        End;

        While GroupHandle <> Nil Do
        Begin
             ProcessPrimitivesOfAComponent(GroupHandle, R);
             GroupHandle := GroupIterator.NextPCBObject;
        End;
        C.GroupIterator_Destroy(GroupIterator);

        Result := R;
End;

Procedure ChangeComponentStringsPosition;
Var
    Iterator    : IPCB_BoardIterator;
    Board       : IPCB_Board;
    Component   : IPCB_Component;
    Count       : Integer;
    R           : TCoordRect;
    X, Y        : Real;
    Mirror      : Boolean;
const
    MMsPrecision = 100;
    CrdPrecision = 10000;
Begin
    // Retrieve the current board
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then Exit;

    BeginHourGlass;

    // Create the iterator that will look for Net objects only
    Iterator        := Board.BoardIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eComponentObject));
    Iterator.AddFilter_LayerSet(AllLayers);
    Iterator.AddFilter_Method(eProcessAll);

    Count := 0;

    // Search for Net object that has the 'GND' name.
    Component := Iterator.FirstPCBObject;
    While (Component <> Nil) Do
    Begin
        R := FindComponentAssemblyRect(Component);

        if (ABS(R.Left - R.Right) < ABS(R.Top - R.Bottom)) then
        begin
         // Portrait
         if (Component.Layer = eTopLayer) then
         begin
           Component.Comment.Rotation := 90;
           Component.Name.Rotation := 90;
         end
         else
         begin
           Component.Comment.Rotation := 270;
           Component.Name.Rotation := 270;
         end;

        end
        else
        begin
         //Landscape
         Component.Comment.Rotation := 360;
         Component.Name.Rotation := 360;
        end;

        Component.CommentAutoPosition :=  eAutoPos_TopCenter;
        Component.NameAutoPosition    :=  eAutoPos_CenterCenter;
        Component.AutoPosition_NameComment;

        Component.CommentAutoPosition :=  eAutoPos_Manual;
        Component.NameAutoPosition    :=  eAutoPos_Manual;


        X := CoordToMMs(Component.Name.XLocation - Board.XOrigin);
        X := Trunc(X * MMsPrecision) / MMsPrecision;
        Component.Name.XLocation := Trunc ( (MMsToCoord(X) + Board.XOrigin) / CrdPrecision ) * CrdPrecision;

        Y := CoordToMMs(Component.Name.YLocation - Board.YOrigin);
        Y := Trunc(Y * MMsPrecision) / MMsPrecision;
        Component.Name.YLocation := Trunc ( (MMsToCoord(Y) + Board.YOrigin) / CrdPrecision ) * CrdPrecision;


        X := CoordToMMs(Component.Comment.XLocation - Board.XOrigin);
        X := Trunc(X * MMsPrecision) / MMsPrecision;
        Component.Comment.XLocation := Trunc ( (MMsToCoord(X) + Board.XOrigin) / CrdPrecision ) * CrdPrecision;

        //Y := CoordToMMs(Component.Comment.YLocation - Board.YOrigin);
        Y := CoordToMMs(R.Top - Board.YOrigin + Component.Comment.Size/2);
        Y := Trunc(Y * MMsPrecision) / MMsPrecision;
        Component.Comment.YLocation := Trunc ( (MMsToCoord(Y) + Board.YOrigin) / CrdPrecision ) * CrdPrecision;


        Component.LockStrings := True;
        Component.LockStrings := False;

        Component.CommentAutoPosition :=  eAutoPos_Manual;
        Component.NameAutoPosition    :=  eAutoPos_Manual;


//        Component.AutoPosition_NameComment;


        Component := Iterator.NextPCBObject;
        Count := Count + 1;
        if (Count > 1024) then
        Begin
           ShowMessage('Components more than 1024!');
           Break;
        end;
    End;
    Board.BoardIterator_Destroy(Iterator);
    EndHourGlass;
    Client.SendMessage('PCB:Zoom', 'Action=Redraw' , 255, Client.CurrentView);
End;

