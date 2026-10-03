-- 不允许打包空白文件

function OnCallScriptID1(EventID, data)

    Info( "eventid = ".. EventID .. ",data=" .. TableToString(data))


end


-- 更新宠物ID
function OnCallScriptID1014(EventID, data)

    Info( "eventid = ".. EventID .. ",data=" .. TableToString(data))

    local PetSlotIndex = data.SlotIdx
    local PetID = data.OldPetID
    local NewPetID = data.NewPetID

    -- 更新内存并通知界面刷新
    game:ChangePetID(PetSlotIndex, PetID, NewPetID)

end