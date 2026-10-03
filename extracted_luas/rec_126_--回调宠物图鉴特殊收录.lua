--回调宠物图鉴特殊收录

function OnRequestSpecialRecordPet(PageID, PetIndex, PetID)

    local idparser = game:GetIDParseTool()

    local RecordCost = idparser:ParsePetManualCost(PetID)
    if not RecordCost then
        return
    end

    local ConfirmSelect = game:GetUIPetManualElementScrollSpecialRecordPetSelectDlg()
    local dlg = ConfirmSelect:GetDlg()
    local ok = ConfirmSelect:GetOKButton()
    local cancel = ConfirmSelect:GetCancelButton()

    local valid1 = false
    local valid2 = false
    if RecordCost.SpecialCostItemID > 0 and RecordCost.SpecialCostItemCount > 0 then
        valid1 = true
    end
    if RecordCost.SpecialCost2ItemID > 0 and RecordCost.SpecialCost2ItemCount > 0 then
        local DataItem = game:UIDataItem()
        local myitemcount = DataItem:GetItemCount(RecordCost.SpecialCost2ItemID) + DataItem:GetItemCount(RecordCost.SpecialCost2BindedItemID)
        if myitemcount > 0 then

            local elescrollinfo = idparser:ParsePetManualElementScroll(PageID)
            if not elescrollinfo then
                return
            end

            local legalClassNames =
            {
                "火之卷第1章", "火之卷第2章", "火之卷第3章", "火之卷第4章", "火之卷第5章",
                "风之卷第1章", "风之卷第2章", "风之卷第3章", "风之卷第4章", "风之卷第5章",
                "水之卷第1章", "水之卷第2章", "水之卷第3章", "水之卷第4章", "水之卷第5章",
                "土之卷第1章", "土之卷第2章", "土之卷第3章", "土之卷第4章", "土之卷第5章",
            }

            local bFound = false
            for c, v in pairs(legalClassNames) do
                if elescrollinfo.ClassName == v then
                    bFound = true
                    break
                end
            end

            if bFound then
                valid2 = true
            end
        end
    end

    if valid1 and valid2 then

        -- 存在两种特殊收录, 设置对话框图片
        ConfirmSelect:SetCueInfoRect(10, 10, 195, 50)
        dlg:SetSize(214, 112)
        dlg:SetBKImage("UIGame\\UIPetManual\\灵蛋选择\\二次确认底图 红底.mgff", 0, 0)

        ok:SetPosition(dlg:Left() + 16, dlg:Top() + 66)
        ok:SetSize(80, 39)
        ok:SetImage(
            "UIGame\\UIPetManual\\灵蛋选择\\元灵蛋按钮 正常.mgff",
            "UIGame\\UIPetManual\\灵蛋选择\\元灵蛋按钮 高亮.mgff",
            "UIGame\\UIPetManual\\灵蛋选择\\元灵蛋按钮 点击.mgff",
            "UIGame\\UIPetManual\\灵蛋选择\\元灵蛋按钮 正常.mgff")

        cancel:SetPosition(dlg:Left() + 118, dlg:Top() + 66)
        cancel:SetSize(80, 39)
        cancel:SetImage(
            "UIGame\\UIPetManual\\灵蛋选择\\混灵蛋按钮 正常.mgff",
            "UIGame\\UIPetManual\\灵蛋选择\\混灵蛋按钮 高亮.mgff",
            "UIGame\\UIPetManual\\灵蛋选择\\混灵蛋按钮 点击.mgff",
            "")

        ConfirmSelect.TagType = -1
        ConfirmSelect.EventHandle = "OnEventHandle_PetManualElementScroll_SpecialRecordPetSelectDlg"
        ConfirmSelect:SetCueInfo("使用【元灵蛋】或【混灵蛋】都可以完成此项收录，请确认您的选择：")
        ConfirmSelect:ShowDlg(1)

    else
        ConfirmSelect.TagType = 1
        ConfirmSelect.EventHandle = "OnEventHandle_PetManualElementScroll_SpecialRecordPetConfirmDlg"
        ConfirmSelect:SetDefaultSizeAndImages()

        local iteminfo1 = game:GetItemInfo(RecordCost.SpecialCostItemID)
        local itemcount1 = RecordCost.SpecialCostItemCount

        local tipstrres = game:GetString("STR_ELEMENTSCROLL_SPECIALRECORDPET_CONFIRMTIP")
        local tipstr = string.format(tipstrres, iteminfo1.Name, itemcount1)
        ConfirmSelect:SetCueInfo(tipstr)
        ConfirmSelect:ShowDlg(1)
    end

end

function OnEventHandle_PetManualElementScroll_SpecialRecordPetSelectDlg( Event, CtrlID, Ctrl)

    local ConfirmSelect = game:GetUIPetManualElementScrollSpecialRecordPetSelectDlg()
    local dlg = ConfirmSelect:GetDlg()
    local ok = ConfirmSelect:GetOKButton()
    local cancel = ConfirmSelect:GetCancelButton()
    ConfirmSelect:ShowDlg(0)

    ConfirmSelect.EventHandle = "OnEventHandle_PetManualElementScroll_SpecialRecordPetConfirmDlg"
    ConfirmSelect:SetDefaultSizeAndImages()

    local PetID = ConfirmSelect.TagIdx
    local idparser = game:GetIDParseTool()

    local RecordCost = idparser:ParsePetManualCost(PetID)
    if not RecordCost then
        return
    end
    local iteminfo1 = game:GetItemInfo(RecordCost.SpecialCostItemID)
    local itemcount1 = RecordCost.SpecialCostItemCount
    local iteminfo2 = game:GetItemInfo(RecordCost.SpecialCost2ItemID)
    local itemcount2 = RecordCost.SpecialCost2ItemCount

    local tipstrres = game:GetString("STR_ELEMENTSCROLL_SPECIALRECORDPET_CONFIRMTIP")

    -- 左边是2, 右边是1
    -- 左2: 元灵蛋, 右1:混灵蛋按钮
    if CtrlID == 2 then
        ConfirmSelect.TagType = 1
        local tipstr = string.format(tipstrres, iteminfo1.Name, itemcount1)
        ConfirmSelect:SetCueInfo(tipstr)
        ConfirmSelect:ShowDlg(1)
    elseif CtrlID == 1 then
        ConfirmSelect.TagType = 2
        local tipstr = string.format(tipstrres, iteminfo2.Name, itemcount2)
        ConfirmSelect:SetCueInfo(tipstr)
        ConfirmSelect:ShowDlg(1)
    end



end

function OnEventHandle_PetManualElementScroll_SpecialRecordPetConfirmDlg( Event, CtrlID, Ctrl)

    local ConfirmSelect = game:GetUIPetManualElementScrollSpecialRecordPetSelectDlg()
    local dlg = ConfirmSelect:GetDlg()

    ConfirmSelect:ShowDlg(0)
    if CtrlID == 2 then
        ConfirmSelect:ShowDlg(0)
        -- 特殊收录
        -- 来源类型: 0 =元素古卷, 1=精灵宝书, 2=妖精遗物
        local SourceType = 0
        local PetID = ConfirmSelect.TagIdx
        -- 收录类型 0=一般收录, 1=特殊收录, 2=第二种特殊收录(消耗另一种物品)
        local CostType = ConfirmSelect.TagType
        SendRequestRecordPet(0, PetID, CostType)
    end
end