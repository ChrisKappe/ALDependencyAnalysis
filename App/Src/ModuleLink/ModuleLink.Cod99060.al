codeunit 99060 "ALDA Module Link"
{
    procedure ToggleIgnore(var ALDAModuleLink: Record "ALDA Module Link")
    var
        ALDAElementLink: Record "ALDA Element Link";
    begin
        ALDAModuleLink.Ignore := not ALDAModuleLink.Ignore;
        ALDAModuleLink.Modify();

        clear(ALDAElementLink);
        ALDAElementLink.SetRange("Source Module", ALDAModuleLink."Source Module");
        ALDAElementLink.SetRange("Target Module", ALDAModuleLink."Target Module");
        ALDAElementLink.SetRange(Ignore, not ALDAModuleLink.Ignore);
        ALDAElementLink.ModifyAll(Ignore, ALDAModuleLink.Ignore);

        CalculateDirectCircular(ALDAModuleLink);
    end;

    procedure CalculateDirectCircular(var ALDAModuleLink: Record "ALDA Module Link")
    var
        ALDAModuleLinkFind: Record "ALDA Module Link";
    begin
        ALDAModuleLink."Self Reference" := ALDAModuleLink."Source Module" = ALDAModuleLink."Target Module";
        ALDAModuleLink.CalcFields(Links);

        clear(ALDAModuleLinkFind);
        ALDAModuleLinkFind.SetRange("Target Module", ALDAModuleLink."Source Module");
        ALDAModuleLinkFind.SetRange("Source Module", ALDAModuleLink."Target Module");
        ALDAModuleLinkFind.SetRange(Ignore, false);
        ALDAModuleLinkFind.SetFilter(Links, '>%1', 0);

        ALDAModuleLink.Circular := ((not ALDAModuleLink."Self Reference") AND (not ALDAModuleLinkFind.IsEmpty()) AND (ALDAModuleLink.Links > 0));
        ALDAModuleLink.Modify();
    end;

    procedure CalculateMultiLevelCircular(ALDAModuleLink: Record "ALDA Module Link")
    var
        ALDAModuleLinkFind: Record "ALDA Module Link";
        Circle: List of [Text];
        Module: Text;
    begin
        if ALDAModuleLink."Self Reference" then exit;

        clear(Circle);
        Circle.Add(ALDAModuleLink."Source Module");
        if IsCircular(ALDAModuleLink, Circle) then begin
            //TODO: Loop All
            ALDAModuleLink.MultiLevelCircularCount := Circle.Count();
            ALDAModuleLink.Modify(true);
        end;
    end;


    local procedure IsCircular(ALDAModuleLink: Record "ALDA Module Link"; Circle: List of [Text]): Boolean
    var
        UsingLinks: record "ALDA Module Link";
        CircleList: TExt;
        CircleItem: Text;
    begin

        foreach CircleItem in Circle do
            CircleList += CircleItem + '-';

        UsingLinks.SetRange("Source Module", ALDAModuleLink."Target Module");
        UsingLinks.SetRange(Ignore, false);
        if UsingLinks.FindSet() then
            repeat
                if not (UsingLinks."Source Module" = UsingLinks."Target Module") then begin
                    Circle.Add(UsingLinks."Source Module");
                    CircleList += UsingLinks."Source Module";

                    if Circle.get(1) = UsingLinks."Target Module" then
                        exit(true)
                    else
                        if not circle.Contains(UsingLinks."Target Module") then
                            if IsCircular(UsingLinks, Circle) then
                                exit(true);
                end;
            until UsingLinks.Next() < 1;

        exit(false);
    end;

    procedure GetMultiLevelCircularWebGraphvizText(ALDAModuleLink: Record "ALDA Module Link"; Circle: List of [Text]; var GraphVizText: TextBuilder): Boolean
    var
        UsingLinks: record "ALDA Module Link";
        CircleList: TExt;
        CircleItem: Text;
        TextToBeAdded: Text;
    begin

        foreach CircleItem in Circle do
            CircleList += CircleItem + '-';

        UsingLinks.SetRange("Source Module", ALDAModuleLink."Target Module");
        UsingLinks.SetRange(Ignore, false);
        if UsingLinks.FindSet() then
            repeat
                if not (UsingLinks."Source Module" = UsingLinks."Target Module") then begin
                    Circle.Add(UsingLinks."Source Module");
                    TextToBeAdded := StrSubstNo('   "%1" -> "%2" [color="red"] ;', UsingLinks."Source Module", UsingLinks."Target Module");
                    if (not GraphVizText.ToText().Contains(TextToBeAdded)) then
                        GraphVizText.AppendLine(TextToBeAdded);
                    CircleList += UsingLinks."Source Module";

                    if Circle.get(1) = UsingLinks."Target Module" then
                        exit(true)
                    else
                        if not circle.Contains(UsingLinks."Target Module") then
                            if GetMultiLevelCircularWebGraphvizText(UsingLinks, Circle, GraphVizText) then
                                exit(true);
                end;
            until UsingLinks.Next() < 1;

        exit(false);
    end;
}